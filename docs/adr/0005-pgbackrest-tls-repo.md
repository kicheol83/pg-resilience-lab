# ADR-0005 pgBackRest 전용 저장소 호스트 + TLS 서버 모드

- 상태: 채택
- 날짜: 2026-10

## 결정

- 백업 저장소는 데이터 노드와 분리된 `backup` 호스트에 둔다. 데이터 노드가 디스크째 사라져도 백업이 남는다.
- 노드 간 통신은 SSH 대신 pgBackRest TLS 서버(`pgbackrest server`, 포트 8432)를 쓴다. 인증은 lab CA가 서명한 인증서의 CN(`tls-server-auth=pg1=ledger` 등)으로 한다.
- `backup-standby=prefer`: 백업 부하를 standby가 진다.
- `archive-async=y` + spool: archive_command가 커밋 경로를 막지 않는다.
- `repo1-bundle=y`, `repo1-block=y`(블록 증분), `compress-type=zst`.
- 보관: full 2개, diff 4개. 일정: 일요일 full, 월~토 diff, 4시간마다 incr(`BACKUP_CRON_*`로 변경).
- `repo2`: `S3_BUCKET`을 주면 AWS S3로 aes-256-cbc 암호화된 사본을 보낸다(오프사이트, 데이터센터 화재 대비).
- 매일 04:30 `restore-verify`가 최신 백업을 임시 디렉터리에 복원하고 `verify_ledger_integrity()`, 통화별 차변=대변, 체크섬 실패 수를 확인해 `verify-history.jsonl`에 남긴다.
