# ADR-0003 HAProxy는 "커밋할 수 있는 primary"에만 쓰기를 보낸다

- 상태: 채택
- 날짜: 2026-10

## 배경

repmgr는 클라이언트 라우팅을 하지 않는다. 처음에는 각 노드의 헬스 에이전트가 `pg_is_in_recovery() = false`면 200을 돌려주게 했다. 시나리오 05(네트워크 격리)에서, 격리됐다 돌아온 옛 primary가 스스로 격리(fence)되기 전 약 18초 동안 HAProxy에 primary로 보였다. 그동안 두 노드가 동시에 primary로 라우팅될 수 있었다.

## 결정

에이전트(`node/bin/pg-health-agent`, socat 기반 HTTP)는 `/primary`에서 다음을 모두 만족할 때만 200을 반환한다.

1. recovery 중이 아니다.
2. `default_transaction_read_only`가 꺼져 있다(fence되지 않았다).
3. `pg_stat_replication`에 `sync_state in ('sync','quorum')`인 standby가 있고, 그 standby의 `reply_time`이 3초 이내다. `synchronous_standby_names`가 비어 있는 단독 노드(업그레이드 대상 pg18)는 이 조건을 면제한다.

HAProxy는 `inter 1s fastinter 500ms fall 2`로 확인하고, `on-marked-down shutdown-sessions`로 내려간 노드의 기존 세션을 끊는다. 컨테이너 IP가 바뀌어도 따라가도록 Docker DNS resolver를 쓴다.

## 결과

- 동기 복제 상대를 잃은 primary는 수 초 안에 라우팅에서 빠진다. 이는 커밋이 어차피 완료될 수 없는 상태와 정확히 일치한다.
- 승격 직후 follower가 붙기 전까지 새 primary도 라우팅되지 않는다(시나리오 10에서 약 2초).
- 읽기 전용 포트(5001)는 `/replica`(recovery 중이고 WAL receiver가 streaming)를 쓴다.
