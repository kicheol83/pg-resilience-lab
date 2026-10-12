# ADR-0006 동기 대기 중인 세션은 cancel이 아니라 terminate로 끊는다

- 상태: 채택
- 날짜: 2026-10

## 배경

동기 복제에서 커밋은 primary의 WAL에 먼저 기록되고, standby 응답을 기다리는 동안(`wait_event = 'SyncRep'`) 클라이언트에 결과를 돌려주지 않는다. 이 대기를 cancel하면 PostgreSQL은 다음 경고와 함께 커밋을 성공으로 끝낸다.

```
WARNING:  canceling wait for synchronous replication due to user request
DETAIL:  The transaction has already committed locally, but might not have been replicated to the standby.
```

그 primary가 뒤에 failover로 밀려나 pg_rewind되면, 클라이언트가 성공을 받은 행이 사라진다.

처음에는 API의 `statement_timeout`(5초)이 이 cancel을 일으킬 것이라고 가정했다. `experiments/ack-leak.sh`로 측정해 보니 틀린 가정이었다. 단순 쿼리 프로토콜에서 PostgreSQL은 `finish_xact_command()`에서 statement timeout을 먼저 해제한 뒤 커밋하므로, `statement_timeout`은 동기 대기를 끊지 못한다.

| 분할 중 SyncRep 대기를 끊는 방법 (1초마다) | 성공 응답 후 사라진 행 |
| --- | --- |
| 없음, `statement_timeout = 2s`만 | 0 |
| `pg_cancel_backend`, pg1에 직접 연결 | 72 |
| `pg_cancel_backend`, HAProxy 경유 | 16 |
| `pg_terminate_backend`, HAProxy 경유 | 0 |

(4개 writer, 20초 분할, 2 vCPU 샌드박스에서 1회 측정. 수치는 `results/ack-leak/`.)

## 결정

- 자기 격리(`fence-self`)는 세션을 `pg_terminate_backend`로 끊는다. 종료되는 세션은 커밋 결과를 받지 못하므로 클라이언트는 실패로 보고 멱등 키로 재시도한다.
- 런북: 장애 중 오래 걸리는 쿼리를 정리할 때 `wait_event = 'SyncRep'`인 세션에는 `pg_cancel_backend`를 쓰지 않는다.
- 드라이버의 클라이언트 측 타임아웃이 CancelRequest를 보내는 방식(JDBC `setQueryTimeout` 등)이면 같은 위험이 있다. LedgerCore(node-postgres)는 서버 측 `statement_timeout`만 쓰므로 해당하지 않는다.
- API의 `statement_timeout`은 LedgerCore 기본값 5초를 유지한다(`API_STATEMENT_TIMEOUT_MS`).
