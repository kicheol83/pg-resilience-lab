# 운영 런북

모든 명령은 저장소 루트에서 실행한다. Windows는 `.\lab.ps1 <명령>`, Linux/macOS는 `./lab <명령>`.
노드 내부 명령은 `docker exec pglab-<노드> lab-node <명령>` 형태다.

## 0. 상태 확인

```powershell
.\lab.ps1 status
```

확인할 것:

- 노드별 `role`: primary 1개, standby 2개. primary의 `sync_quorum`이 `ok`여야 쓰기를 받는다.
- HAProxy `rw`: 정확히 한 서버가 `UP`.
- 복제: 두 standby 모두 `streaming`, `sync_state = quorum`, replay lag 수 MB 이내.
- 백업: 최근 full/diff/incr 시각, `wal archive min/max`가 계속 증가하는지.

HAProxy 통계 화면: http://localhost:8404

## 1. 자동 failover가 일어난 뒤

repmgrd가 새 primary를 승격하고 나머지 standby를 따라가게 한다. 사람이 할 일은 옛 primary를 되돌리는 것뿐이다.

```powershell
.\lab.ps1 status
docker exec pglab-pg1 lab-node rejoin
```

`rejoin`은 다음을 순서대로 한다.

1. repmgrd를 멈추고 PostgreSQL을 fast shutdown (60초 안에 안 끝나면 immediate).
2. 깨끗하게 종료되지 않았으면 single-user 모드로 crash recovery.
3. `postgresql.auto.conf`에서 fence 설정 제거.
4. `repmgr node rejoin --force-rewind`로 pg_rewind 후 새 primary를 따라감.
5. 실패하면 데이터 디렉터리를 비우고 `repmgr standby clone`으로 다시 만듦.

컨테이너가 재시작된 경우에는 엔트리포인트의 부팅 가드가 같은 일을 자동으로 한다.

## 2. 계획된 switchover (예: pg1을 다시 primary로)

```powershell
docker exec pglab-pg1 lab-node repmgr standby switchover --siblings-follow
```

또는 `.\lab.ps1 baseline`이 모든 노드를 고치고 pg1을 primary로 되돌린다.

## 3. 노드를 처음부터 다시 만들기

데이터 디렉터리가 손상됐거나 사라졌을 때:

```powershell
docker exec pglab-pg3 lab-node rebuild
```

현재 primary를 찾아 `repmgr standby clone --fast-checkpoint`로 복제하고 standby로 등록한다.

## 4. 고립된 primary (fence)

primary가 모든 standby와 witness를 8초 넘게 잃으면 스스로 read-only가 되고 클라이언트 세션을 끊는다.

```powershell
docker exec pglab-pg1 lab-node role       # fenced
docker exec pglab-pg1 lab-node rejoin     # 다른 노드가 이미 승격됐다면
docker exec pglab-pg1 lab-node unfence    # 승격이 없었고 이 노드가 유일한 primary일 때만
```

`unfence` 전에 반드시 `.\lab.ps1 status`로 다른 primary가 없는지 확인한다.

## 5. repmgrd가 멈춰 있을 때

switchover가 중간에 실패하면 클러스터 전체가 pause 상태로 남을 수 있다.

```powershell
docker exec pglab-pg2 lab-node repmgr service status
docker exec pglab-pg2 lab-node repmgr service unpause
```

## 6. 백업

```powershell
.\lab.ps1 backup info
.\lab.ps1 backup full        # diff, incr도 가능
.\lab.ps1 backup check       # archive_command와 저장소 연결 확인
.\lab.ps1 backup verify      # 최신 백업을 임시 디렉터리에 복원해 무결성 검사
.\lab.ps1 backup history     # 매일 자동 복원 검증 결과
```

## 7. 사람이 데이터를 지웠을 때 (PITR)

HA는 도움이 되지 않는다. `DROP`은 몇 밀리초 만에 모든 standby에 복제된다. 시나리오 09가 아래 절차를 자동으로 수행한다.

1. 사고 직전 위치를 찾는다. 시각을 모르면 WAL에서 DROP의 커밋 레코드를 찾는다.

   ```bash
   docker exec pglab-pg1 bash -c '. /usr/local/bin/lab-common.sh; as_pg $(pg_bin)/pg_waldump -p $PGDATA/pg_wal -s <사고 전 LSN> | grep -m1 "COMMIT .*rels:"'
   ```

   출력의 `tx: <xid>`가 DROP 트랜잭션이다.

2. 모든 노드의 repmgrd를 멈추고 PostgreSQL을 내린다 (standby 먼저, primary 마지막).
3. primary를 그 트랜잭션 직전까지 복원한다.

   ```bash
   docker exec pglab-pg1 gosu postgres pgbackrest --stanza=ledger --delta \
     --type=xid --target=<xid> --target-exclusive --target-action=promote restore
   docker exec pglab-pg1 lab-node start
   docker exec pglab-pg1 lab-node repmgr primary register -F
   ```

   `--target-exclusive`이므로 DROP 바로 앞 트랜잭션까지 복구된다. DROP 이후의 쓰기는 테이블이 없어 모두 실패했으므로 성공 응답을 받은 이체는 잃지 않는다.

4. standby는 pgBackRest delta 복원으로 다시 채운다 (변경된 파일만 받는다).

   ```bash
   docker exec pglab-pg2 gosu postgres pgbackrest --stanza=ledger --delta --type=standby --target-timeline=latest restore
   docker exec pglab-pg2 bash -c '. /usr/local/bin/lab-ops.sh; render_repmgr_conf; repmgr_cmd -d "$(conninfo_for pg1)" standby clone --recovery-conf-only -F'
   docker exec pglab-pg2 lab-node start
   docker exec pglab-pg2 lab-node repmgr standby register -F
   ```

5. repmgrd 재개, witness 재등록, `.\lab.ps1 backup full`.

시각으로 복원할 때는 `--type=time --target="2026-10-12 18:05:00+09"`를 쓴다.

## 8. 메이저 업그레이드

```powershell
.\lab.ps1 upgrade check        # pg_upgrade --check, 확장 호환성 확인
.\lab.ps1 upgrade pg-upgrade   # 17 -> 18, pg_upgrade --link, 다운타임 측정
```

무중단 방식 (논리 복제 후 HAProxy 전환):

```powershell
.\lab.ps1 upgrade-node         # PostgreSQL 18 단독 노드 pg18 시작
.\lab.ps1 upgrade logical
```

두 방식 모두 결과는 `results/upgrade-*`에 남는다. 논리 복제 방식은 lab 안에서 되돌릴 수 없으므로 끝난 뒤 `.\lab.ps1 reset`.

`pg_upgrade --link`의 롤백: 새 클러스터를 시작하기 전이면 옛 디렉터리를 그대로 17로 시작하면 된다. 시작한 뒤에는 하드링크를 공유하므로 업그레이드 직전 full 백업에서 복원해야 한다. 스크립트는 업그레이드 직전에 full 백업을 먼저 받는다.

## 9. 보안 점검

```powershell
.\lab.ps1 security
```

TLS 강제, HBA 거부, 역할 권한, statement_timeout, credcheck, md5 해시 거부를 확인한다.

## 10. 유지보수

```powershell
.\lab.ps1 maintenance cron           # pg_cron 실행 이력
.\lab.ps1 maintenance bloat          # pgstattuple_approx 기반 bloat
.\lab.ps1 maintenance wraparound     # XID 나이
.\lab.ps1 maintenance vacuum-report  # autovacuum 현황과 테이블별 설정
.\lab.ps1 maintenance repack         # VACUUM FULL과 pg_repack을 부하 중에 비교
```

## 11. S3 오프사이트 백업 켜기

`.env`에 다음을 넣고 `.\lab.ps1 up`:

```
S3_BUCKET=<버킷>
S3_REGION=ap-northeast-2
S3_KEY=<액세스 키>
S3_KEY_SECRET=<시크릿>
S3_CIPHER_PASS=<저장소 암호화 비밀번호>
```

그다음 `docker exec pglab-backup gosu postgres pgbackrest --stanza=ledger stanza-create`(새 저장소만 만든다) 후 `docker exec pglab-backup gosu postgres pgbackrest --stanza=ledger --repo=2 --type=full backup`.
