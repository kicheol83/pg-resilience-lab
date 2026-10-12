# 장애 시나리오

모든 시나리오는 같은 틀로 실행된다 (`runner/lib/scenario.sh`).

1. 기준 상태 복구 (`ensure_baseline`): 모든 컨테이너와 네트워크를 되살리고, 고장 난 노드를 rejoin하거나 다시 만들고, pg1을 primary로 switchover한다. 기준 상태는 primary 1대(sync quorum 확보), streaming standby 2대, API 쓰기 성공이다.
2. 부하: k6(`measure/transfers.js`)가 LedgerCore API에 초당 20건 이체를 보낸다. 이체마다 고유한 `Idempotency-Key`가 있고, 실패하면 같은 키로 0.25초 간격, 최대 40번 다시 보낸다. 실제 결제 클라이언트가 하는 방식이다.
3. 주입: 20초 워밍업 뒤 장애를 넣는다(`inject`). 필요하면 운영자 대응 단계(`respond`)를 실행한다.
4. 복구 확인: API 쓰기가 다시 성공할 때까지 기다리고 부하가 끝날 때까지 둔다.
5. 치유: 시나리오별 `heal` 후 다시 기준 상태로 돌린다.
6. 분석 (`measure/analyze.py`):
   - RTO: 주입 시각부터, 실패 뒤 처음 성공한 쓰기까지. 이후 3초 동안 90% 이상 성공해야 회복으로 본다.
   - 클라이언트 공백: 장애 전 마지막 성공부터 회복 후 첫 성공까지.
   - RPO: k6가 201을 받은 이체 중 복구된 클러스터에 없는 건수.
   - 중복: 같은 멱등 키로 두 번 반영된 이체 수.
   - 무결성: `verify_ledger_integrity()` 위반 수, 통화별 차변 합계 = 대변 합계.
   - 각 노드의 repmgr 이벤트를 모아 주입 시각 기준 타임라인으로 남긴다.

결과: `results/<시나리오>/<UTC 시각>-r<n>/summary.md`, 전체 요약은 `results/SUMMARY.md`.

| # | 시나리오 | 주입 방법 | 확인하려는 것 |
| --- | --- | --- | --- |
| 01 | Primary 정지 | `pg_ctl stop -m fast` | 정상 종료된 primary의 failover 시간 |
| 02 | Primary 강제 종료 | postmaster `kill -9` | 비정상 종료 후 failover, 옛 primary의 crash recovery + rewind |
| 03 | 서버 종료 | `docker stop` | 노드 전체가 사라졌다 다시 켜질 때 부팅 가드가 primary로 뜨지 않는지 |
| 04 | 서버 재시작 | `docker restart` | repmgr 재연결 창(4초) 안에 돌아오면 failover가 일어나는지 |
| 05 | 네트워크 완전 격리 45초 | 두 네트워크에서 모두 분리 후 같은 IP로 재연결 | 고립된 primary의 fence, 재연결 후 이중 primary가 생기지 않는지 |
| 06 | WAL 디스크 가득 참 | 192 MB tmpfs로 WAL을 옮긴 뒤 ballast로 채우고 대량 INSERT | PANIC 후 failover, 남은 standby가 새 primary를 따라가는지 |
| 07 | 데이터 디렉터리 삭제 | 실행 중에 `rm -rf $PGDATA/*` | postmaster가 잠금 파일을 확인하는 주기(약 60초)가 감지 시간을 결정 |
| 08 | 테이블 파일 손실 | `accounts`의 relfilenode 삭제 + 버퍼 축출 | repmgr가 감지하지 못하는 장애: 합성 SQL 검사로 감지 후 운영자가 primary를 내림 |
| 09 | 운영자 실수 DROP TABLE | `ledger_owner`로 `DROP TABLE ledger_entries CASCADE` | HA는 사고를 복제할 뿐이다. pg_waldump로 DROP의 xid를 찾아 그 직전까지 PITR, standby는 pgBackRest delta로 재구성 |
| 10 | Split-brain 분할 | primary를 db 네트워크에서만 분리(클라이언트는 여전히 접근 가능) | 클라이언트가 옛 primary에 계속 쓸 수 있는 상황에서 성공 응답 후 사라지는 이체가 없는지 |

## 실험

| 명령 | 내용 |
| --- | --- |
| `lab experiment sync-commit` | `synchronous_commit` = off / local / remote_write / on / remote_apply 별 이체 지연 |
| `lab experiment sync-standby-loss` | `FIRST 1 (pg2)`와 `ANY 1 (pg2, pg3)`에서 pg2를 25초 멈췄을 때 쓰기 가용성 |
| `lab experiment ack-leak` | 분할 중 SyncRep 대기를 cancel / terminate 했을 때 성공 응답 후 사라진 행 (ADR-0006) |
| `lab maintenance repack` | 같은 부하에서 VACUUM FULL과 pg_repack의 쓰기 지연 비교 |
| `lab backup verify` | 최신 백업을 임시 복원해 무결성 검사 |
| `lab upgrade pg-upgrade` | 17 → 18 pg_upgrade --link, 클러스터 전체, 다운타임 측정 |
| `lab upgrade logical` | 17 → 18 논리 복제 + HAProxy 전환, 다운타임 측정 |
| `lab security` | TLS, HBA, 역할 권한, 타임아웃, credcheck, md5 거부 |
