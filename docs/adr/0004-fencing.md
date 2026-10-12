# ADR-0004 고립된 primary의 자기 격리(fencing)와 부팅 시 가드

- 상태: 채택
- 날짜: 2026-10

## 결정

1. repmgrd의 `child_nodes_disconnect_command`: primary가 모든 자식(standby, witness)을 8초 넘게 잃으면 `fence-self`가 실행된다. `ALTER SYSTEM SET default_transaction_read_only = on` 후 reload하고, 클라이언트 세션을 `pg_terminate_backend`로 끊는다. 종료된 세션은 동기 대기 중이던 커밋의 성공 응답을 받지 못한다.
2. 해제: `child_node_reconnect` 이벤트가 standby에서 온 경우에만 `unfence-self`를 실행한다. failover가 이미 일어났다면 standby는 새 primary를 따르므로 옛 primary로 돌아오지 않는다.
3. 부팅 가드(`lab-entrypoint`): `standby.signal`이 없는 노드가 시작할 때 다른 노드에 fence되지 않은 primary가 있으면 primary로 뜨지 않고 `repmgr node rejoin --force-rewind`로 standby가 된다.
4. rejoin 전에 `postgresql.auto.conf`에서 fence 설정을 지운다. 처음에는 `--config-files=postgresql.auto.conf`로 파일을 보존했다가, fence된 설정이 살아남아 switchover 후 새 primary가 read-only가 되는 버그를 시나리오 05에서 찾았다.

## 한계

`default_transaction_read_only`는 세션에서 다시 끌 수 있는 소프트 fence다. LedgerCore는 끄지 않으므로 충분하고, 라우팅은 ADR-0003의 quorum 검사가 먼저 막는다. 더 강한 방법은 `pg_ctl stop`이지만, 일시적 단절에서도 노드가 내려가 가용성이 떨어진다.
