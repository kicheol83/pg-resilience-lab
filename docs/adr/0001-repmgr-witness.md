# ADR-0001 자동 failover 도구로 repmgr + witness를 쓴다

- 상태: 채택
- 날짜: 2026-10

## 배경

LedgerCore는 원장 데이터를 다루므로 primary 장애 시 사람이 개입하지 않아도 수 초 안에 쓰기가 복구되어야 한다.
후보는 repmgr, Patroni(+etcd), pg_auto_failover였다.

## 결정

repmgr 5.5 + repmgrd를 쓰고, 데이터 노드와 별도로 witness 노드를 둔다.

- 노드 3개 + witness 1개: primary가 사라졌을 때 남은 standby와 witness가 다수결로 "primary가 정말 안 보인다"를 확인한다(`primary_visibility_consensus=yes`).
- `standby_disconnect_on_failover=yes`: 선거 전에 모든 standby가 WAL 수신을 끊어, 가장 앞선 LSN을 가진 노드를 공정하게 고른다.
- 우선순위: pg1 100, pg2 90, pg3 80. 같은 LSN이면 pg2가 승격된다.
- switchover와 rejoin은 `repmgr standby switchover --siblings-follow`, `repmgr node rejoin --force-rewind`(pg_rewind)를 그대로 쓴다. 이를 위해 노드 간 postgres 사용자 SSH 키를 둔다.

## 고려한 대안

- Patroni: DCS(etcd/Consul)가 리더 락을 가지므로 split-brain 방어가 더 강하다. 다만 DCS 클러스터를 따로 운영해야 하고, 과정에서 배운 repmgr 절차(clone, register, rejoin, switchover)를 그대로 검증하는 것이 이 lab의 목적이다.
- pg_auto_failover: 모니터 노드가 단일 장애점이 된다.

## 결과

- repmgr에는 DCS 리더 락이 없으므로, split-brain 방어는 동기 복제 quorum(ADR-0002), quorum을 보는 HAProxy 헬스체크(ADR-0003), 자기 격리(ADR-0004)로 보강한다.
- repmgrd가 로컬 노드에 접속할 때도 `conninfo`의 호스트명(`pgN-db`)을 쓴다. 네트워크가 끊기면 DNS가 실패해 repmgrd가 자기 노드를 못 보는 문제가 시나리오 10에서 드러나, 각 노드의 `/etc/hosts`에 `pgN-db → 127.0.0.1`을 넣었다(`extra_hosts`).
