# PostgreSQL 설정 근거

설정 파일: `node/conf/postgresql.lab.conf` (모든 데이터 노드 공통, `postgresql.conf`의 `include`로 읽는다).
노드 메모리 상한을 약 1 GB로 가정한 lab 값이다. 운영 서버에서는 RAM 비율로 다시 계산한다.

| 영역 | 설정 | 값 | 이유 |
| --- | --- | --- | --- |
| 메모리 | `shared_buffers` | 256MB | RAM의 약 25%. LedgerCore 작업 집합(잔액 인덱스, 최근 원장 행)이 들어간다 |
| 메모리 | `effective_cache_size` | 768MB | 플래너에게 OS 캐시 포함 가용 캐시를 알려 index scan을 선호하게 한다 |
| 메모리 | `work_mem` / `maintenance_work_mem` | 8MB / 128MB | 최대 150 커넥션 × 정렬 노드를 고려한 상한, VACUUM·인덱스 생성은 넉넉히 |
| 커넥션 | `max_connections` | 150 | API 풀 20 + 운영 도구 + 복제 슬롯 여유. 풀 크기는 앱에서 제한한다 |
| WAL | `wal_level` | logical | 물리 복제 + 논리 복제 기반 무중단 업그레이드(`upgrade/logical.sh`) |
| WAL | `wal_log_hints` | on | pg_rewind 필수(데이터 체크섬도 initdb에서 켰다) |
| WAL | `wal_compression` | lz4 | full page image 크기를 줄여 복제·아카이브 대역폭 절약 |
| WAL | `max_wal_size` / `min_wal_size` | 1GB / 256MB | 체크포인트 간격을 `checkpoint_timeout` 쪽이 주도하게 |
| 복제 | `max_slot_wal_keep_size` | 4GB | 죽은 standby의 슬롯이 primary 디스크를 무한히 채우지 못하게 |
| 복제 | `wal_keep_size` | 512MB | 슬롯 없이 잠깐 끊긴 standby도 재동기화 가능 |
| 복제 | `hot_standby_feedback` | on | standby 읽기 쿼리가 vacuum으로 인한 충돌로 취소되지 않게 |
| 복제 | `wal_sender_timeout` / `wal_receiver_timeout` | 10s | 끊긴 복제 연결을 기본값(60s)보다 빨리 정리 |
| 복제 | `synchronous_standby_names` | `ANY 1 (pg1, pg2, pg3)` | ADR-0002 |
| 네트워크 | `tcp_keepalives_*`, `tcp_user_timeout` | 5s/2s/3회, 10s | 시나리오 10에서 응답 없는 상대에게 막힌 walsender 때문에 fast shutdown이 120초 넘게 멈췄다. 죽은 TCP를 10초 안에 끊는다 |
| 아카이브 | `archive_mode` / `archive_command` | on / pgBackRest | PITR의 전제. primary가 아직 올리지 못한 WAL과 함께 사라지면 아카이브에 구멍이 생기고 그 구간을 지나는 PITR이 실패했다(시나리오 07 → 09). `always`는 저장소의 아카이브 잠금을 세 노드가 다투게 만들어 첫 전체 백업이 시간 초과로 실패했다. 그래서 `on`을 유지하고, 승격 이벤트에서 새 primary가 pg_wal에 남은 이전 timeline 세그먼트를 다시 올린다(`wal-backfill`, 이미 있는 세그먼트는 체크섬이 같으면 건너뜀). `archive_timeout = 60s`로 한가한 시간에도 최대 1분 단위 RPO |
| 보안 | `password_encryption` | scram-sha-256 | md5 해시 역할은 로그인할 수 없다(`lab security`에서 확인) |
| 보안 | `ssl_min_protocol_version` | TLSv1.2 | 클라이언트·복제·pgBackRest 모두 lab CA 인증서로 TLS |
| 보안 | `credcheck.*` | 16자, 대·소문자·숫자·특수문자 각 1 | 약한 비밀번호 생성 차단 |
| 관측 | `log_min_duration_statement` | 250ms | 느린 쿼리 로그 |
| 관측 | `log_lock_waits`, `deadlock_timeout` | on, 1s | 1초 넘는 락 대기를 기록 |
| 관측 | `track_io_timing`, `track_wal_io_timing` | on | `pg_stat_io`, EXPLAIN (BUFFERS)에서 I/O 시간 확인 |
| 관측 | `log_autovacuum_min_duration` | 1s | 오래 걸린 autovacuum 기록 |
| VACUUM | `autovacuum_naptime`, `autovacuum_vacuum_cost_limit` | 10s, 1000 | 삽입이 많은 원장 테이블을 자주, 빠르게 처리 |
| 확장 | `shared_preload_libraries` | repmgr, pg_stat_statements, pg_cron, credcheck | |
| 확장 | `cron.use_background_workers` | on | pg_cron이 비밀번호 없이 백그라운드 워커로 실행 |

테이블별 autovacuum 설정은 `maintenance/install.sql`에 있다.

| 테이블 | 설정 | 이유 |
| --- | --- | --- |
| `ledger_entries` | `autovacuum_vacuum_insert_scale_factor = 0.05`, `..._insert_threshold = 10000`, `autovacuum_analyze_scale_factor = 0.02` | 삽입 전용 테이블. visibility map을 자주 갱신해 index-only scan과 anti-wraparound 비용을 줄인다 |
| `transactions` | insert 0.05, analyze 0.02 | 상태별 부분 인덱스의 통계 신선도 |
| `idempotency_keys` | `autovacuum_vacuum_scale_factor = 0.02`, threshold 1000 | 10분마다 만료 키를 지우므로 dead tuple이 빠르게 쌓인다 |

역할별 설정(`node/sql/bootstrap.sql`):

| 역할 | 권한 | 세션 설정 |
| --- | --- | --- |
| `ledger_owner` | 스키마 소유, 마이그레이션 | `lock_timeout = 5s` (마이그레이션이 운영 트래픽 뒤에서 무한 대기하지 않게) |
| `ledger_app` | 테이블 DML (원장 UPDATE/DELETE/TRUNCATE는 마이그레이션이 회수) | `statement_timeout = 5s`, `lock_timeout = 2s`, `idle_in_transaction_session_timeout = 10s` (API는 커넥션 옵션으로 `statement_timeout`을 덮어쓴다, ADR-0006) |
| `ledger_ro` | SELECT | `default_transaction_read_only = on`, `statement_timeout = 30s` |
| `pgmonitor` | `pg_monitor` | `statement_timeout = 10s` (PG Insight용) |
| `repmgr` | superuser, replication | 네트워크는 db 서브넷 + 자기 자신(127.0.0.1)만 |
| `postgres` | superuser | 로컬 소켓(peer)만, 네트워크 접속은 HBA에서 거부 |
