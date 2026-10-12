# ADR-0002 `synchronous_standby_names = 'ANY 1 (pg1, pg2, pg3)'`

- 상태: 채택
- 날짜: 2026-10

## 배경

비동기 복제에서 failover하면 primary에서 커밋됐지만 아직 standby에 도착하지 않은 트랜잭션이 사라진다. 원장에서는 클라이언트가 201을 받은 이체가 사라지면 안 된다(RPO 0).

## 결정

- 쿼럼 동기 복제 `ANY 1 (pg1, pg2, pg3)`를 모든 노드에 같은 값으로 둔다. 자기 자신은 목록에서 무시되므로 누가 primary가 되어도 설정을 바꿀 필요가 없다.
- `synchronous_commit = on`: 커밋은 standby 1대의 WAL flush 확인을 기다린다.

## 고려한 대안

- `FIRST 1 (pg2)`: 이름이 지정된 standby 하나가 멈추면 모든 커밋이 멈춘다. `experiments/sync-standby-loss.sh`로 차이를 측정한다.
- `remote_apply`: 읽기 일관성은 좋아지지만 지연이 늘어난다. `experiments/sync-commit.sh`로 측정한다.

## 결과

- 쓰기 가용성 조건이 "primary + standby 1대"가 된다. standby 2대가 모두 죽으면 커밋이 멈추는 것이 의도된 동작이다(데이터 안전 > 가용성).
- 동기 대기 중인 커밋을 cancel하면 PostgreSQL은 경고와 함께 성공을 반환한다. 장애 대응에서 이를 피하는 방법이 ADR-0006이다.
