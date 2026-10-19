# PG Resilience Lab

PostgreSQL 17 HA 클러스터를 원장 트래픽 아래에서 10가지 방법으로 망가뜨리고, 매번 RTO, RPO, 원장 무결성을 측정하는 실험 환경입니다.

워크로드는 제가 만든 복식부기 원장 [LedgerCore](https://github.com/kicheol83/ledger_core)입니다. k6가 초당 20건 이체를 보내고, 실패하면 같은 멱등 키로 다시 보냅니다.

## 결과

| 시나리오 | 실행 | RTO 중앙값 (최소~최대) | 성공 응답 이체 | 사라진 이체 | 중복 | 무결성 위반 |
| --- | --- | --- | --- | --- | --- | --- |
| 01 Primary 정지 (`pg_ctl stop -m fast`) | 3 | 7.5 s (6.6~7.6) | 8,849 | 0 | 0 | 0 |
| 02 Primary 강제 종료 (`kill -9`) | 3 | 7.1 s (5.5~8.0) | 8,863 | 0 | 0 | 0 |
| 03 서버 종료 (`docker stop`) | 3 | 24.7 s (24.3~27.9) | 8,017 | 0 | 0 | 0 |
| 04 서버 재시작 (`docker restart`) | 3 | 6.8 s (6.6~7.0) | 8,859 | 0 | 0 | 0 |
| 05 네트워크 완전 격리 45초 | 3 | 27.9 s (26.2~32.0) | 7,878 | 0 | 0 | 0 |
| 06 WAL 디스크 가득 참 | 3 | 7.2 s (6.7~9.0) | 8,871 | 0 | 0 | 0 |
| 07 실행 중 데이터 디렉터리 삭제 | 3 | 35.9 s (35.3~36.6) | 7,537 | 0 | 0 | 0 |
| 08 테이블 파일 손실 | 3 | 6.7 s (6.2~8.6) | 8,870 | 0 | 0 | 0 |
| 09 실수로 DROP TABLE → PITR | 3 | 32.0 s (31.0~73.7) | 16,075 | 0 | 0 | 0 |
| 10 Split-brain (복제망만 단절) | 3 | 28.2 s (27.2~31.2) | 7,881 | 0 | 0 | 0 |

30회 실행, 성공 응답 이체 91,700건 중 사라진 이체 0, 중복 0, 원장 불일치 0. 상세: `results/SUMMARY.md`

- RTO: 장애 주입부터 API 쓰기가 다시 안정적으로 성공할 때까지
- RPO: 클라이언트가 201을 받았는데 복구 후 DB에 없는 이체 수
- 무결성: `verify_ledger_integrity()`(거래별 차변 = 대변), 통화별 차변 합계 = 대변 합계

## 구성

- PostgreSQL 17, repmgr 5.5 (노드 3 + witness), `synchronous_standby_names = 'ANY 1 (pg1, pg2, pg3)'`
- HAProxy: sync quorum이 있는 primary에만 쓰기를 보냄
- pgBackRest 전용 저장소 호스트 (TLS), full/diff/incr, 매일 복원 검증
- 모든 연결 TLS (`verify-full`), scram-sha-256, credcheck
- pg_cron, pg_repack, pgstattuple
- 네트워크 두 개(`db`, `app`): 복제망만 끊어서 split-brain 재현

## 측정하면서 찾고 고친 문제

1. 격리됐다 돌아온 옛 primary가 fence되기 전 약 18초 동안 HAProxy에 primary로 보였다. 헬스체크가 sync quorum이 있을 때만 200을 주도록 변경 (ADR-0003)
2. 동기 대기 중인 커밋을 `pg_cancel_backend`로 끊으면 클라이언트는 성공을 받고, failover 후 그 행이 사라진다(72건). fence는 `pg_terminate_backend`만 사용 (ADR-0006)
3. LedgerCore 버그: 트랜잭션 중 DB 연결이 끊기면 API 프로세스가 죽었다. 깨진 커넥션을 풀에서 버리도록 수정
4. repmgrd가 자기 노드에도 호스트명으로 접속해, 네트워크가 끊기면 자기 자신을 못 보고 fence도 못 했다. `/etc/hosts`에 자기 이름 → 127.0.0.1
5. 응답 없는 standby 때문에 fast shutdown이 120초 넘게 멈췄다. `tcp_user_timeout = 10s`, keepalive
6. `repmgr node rejoin`이 fence 설정을 보존해 switchover 후 새 primary가 read-only였다. rejoin 전에 fence 설정 제거
7. PITR 후 남은 `recovery_target_xid`가 클론에 복사되어 다음 failover에서 승격이 실패했다. PITR 직후 `ALTER SYSTEM RESET`
8. 디스크가 찬 primary가 죽으면 한 standby가 새 primary를 따라가지 못했다. 20초 넘게 스트리밍이 없으면 `standby follow`, 실패하면 pg_rewind
9. credcheck가 `pg_upgrade`의 해시된 비밀번호 복원을 거부했다. 업그레이드 중에만 허용
10. `FIRST 1 (pg2)`는 pg2가 멈추면 쓰기가 멈춘다. `ANY 1` 쿼럼으로 변경 (ADR-0002)
11. 07 다음 09를 실행하면 아카이브에 WAL 구멍이 생겨 PITR이 실패했다. 승격 시 새 primary가 남은 이전 timeline WAL을 다시 올림(`wal-backfill`)
12. 노드 주소를 고정 IP로 바꾸자(실제 서버처럼 죽은 노드 주소가 남음) 시나리오 03 RTO가 50초까지 늘었다. 다른 standby가 죽은 primary에 계속 재접속해 `sibling_nodes_disconnect_timeout`(30초)을 다 기다렸다. 5초로 줄임 (ADR-0001)

## 실험

| 실험 | 결과 |
| --- | --- |
| `synchronous_commit` 비교 (초당 30건) | p50 off 8.8 ms, local 9.4, on 10.2, remote_apply 10.0 |
| pg2 25초 정지 | `FIRST 1 (pg2)`: 실패 12,119회, 포기 213건 / `ANY 1`: 실패 0 |
| 분할 중 SyncRep 대기 처리 | cancel: 72건 유실, terminate: 0건 |
| 부하 중 테이블 재구성 | VACUUM FULL 최대 지연 3.1 s, 실패 23회 / pg_repack 최대 1.8 s, 실패 0 |
| 복원 검증 | 복원 1.8 s + 복구 1.4 s, 무결성 위반 0 |
| 17 → 18 `pg_upgrade --link` | 쓰기 공백 22.6 s, 사라진 이체 0 |
| 17 → 18 논리 복제 + HAProxy 전환 | 쓰기 공백 2.4 s, 사라진 이체 0 |
| 보안 점검 | 18 passed |

## 실행 (PowerShell)

Docker Desktop(메모리 6 GB 이상)이 필요합니다.

```powershell
git clone https://github.com/kicheol83/pg-resilience-lab.git
cd pg-resilience-lab
.\lab.ps1 init
.\lab.ps1 up
.\lab.ps1 status
.\lab.ps1 scenario 01
.\lab.ps1 scenario all 3
.\lab.ps1 report
```

그 밖의 명령: `experiment`, `backup`, `security`, `maintenance`, `upgrade`, `baseline`, `reset`

접속: HAProxy 쓰기 `localhost:5000`, 읽기 `localhost:5001`, 통계 http://localhost:8404, API http://localhost:3000/v1

## 구조

```
compose.yaml        서비스와 네트워크(db, app)
lab, lab.ps1        실행 명령 (bash, PowerShell)
docker/             이미지(Dockerfile), HAProxy 설정
node/               노드 스크립트(bin), postgresql.conf/pg_hba.conf(conf), 부트스트랩 SQL(sql)
runner/             lab CLI, 클러스터 복구, 시나리오 실행기
scenarios/          장애 시나리오 01~10
experiments/        동기 복제, ack 유실 실험
measure/            k6 워크로드, 분석, 요약
backup/ security/ maintenance/ upgrade/
results/            측정 결과
docs/               시나리오 설명, 설정 근거, 런북, ADR
```

## 문서

- `docs/scenarios.md`: 시나리오와 측정 방법
- `docs/tuning.md`: 설정 근거
- `docs/runbook.ko.md`: 운영 절차
- `docs/adr/`: 설계 결정

## 한계

- 모든 컨테이너가 한 호스트에 있습니다. HA 동작(감지, 선거, fence, 라우팅, 복구)을 검증하는 lab이고, 동기 복제 비용은 실제보다 작게 나옵니다.
- 측정은 2 vCPU / 7 GB Linux에서 했습니다. 이 환경에서 Docker Hub를 쓸 수 없어 같은 버전의 PostgreSQL, pgBackRest를 Ubuntu 기반 이미지로 대신했습니다.
- repmgr에는 DCS 리더 락이 없습니다. 더 강한 split-brain 방어가 필요하면 Patroni + etcd가 맞습니다.
- PgBouncer는 없고, S3 저장소 설정은 측정에 포함하지 않았습니다.
