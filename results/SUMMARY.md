# Results summary

Each row aggregates every run under `results/<scenario>/`. RTO is measured from fault injection to the first
successful write that is followed by a stable stream of successes; RPO counts transfers the client saw as
committed (HTTP 201) that are not in the database after recovery.

| scenario | runs | RTO median | RTO worst | client gap median | acked | RPO (missing acked) | duplicates | integrity violations | data safe |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01-primary-stop - Primary PostgreSQL stopped (pg_ctl stop -m fast) | 3 | 7.48 s | 7.57 s | 7.4 s | 8849 | 0 | 0 | 0 | yes |
| 02-primary-kill - Primary postmaster killed (kill -9) | 3 | 7.07 s | 8.0 s | 7.02 s | 8863 | 0 | 0 | 0 | yes |
| 03-server-shutdown - Primary server shut down (docker stop) | 3 | 24.71 s | 27.93 s | 24.67 s | 8017 | 0 | 0 | 0 | yes |
| 04-server-restart - Primary server restarted (docker restart) | 3 | 6.84 s | 7.05 s | 6.8 s | 8859 | 0 | 0 | 0 | yes |
| 05-network-isolation - Primary fully isolated from the network for 45 s | 3 | 27.91 s | 32.03 s | 27.85 s | 7878 | 0 | 0 | 0 | yes |
| 06-disk-full - Primary WAL volume runs out of space | 3 | 7.21 s | 9.03 s | 5.8 s | 8871 | 0 | 0 | 0 | yes |
| 07-datadir-removed - Primary data directory deleted while running | 3 | 35.88 s | 36.62 s | 35.05 s | 7537 | 0 | 0 | 0 | yes |
| 08-relfile-removed - Primary loses the data file of table accounts | 3 | 6.71 s | 8.64 s | 6.01 s | 8870 | 0 | 0 | 0 | yes |
| 09-accidental-drop-pitr - Operator drops ledger_entries; recovered with PITR to the transaction before the DROP | 3 | 32.03 s | 73.67 s | 31.72 s | 16075 | 0 | 0 | 0 | yes |
| 10-split-brain - Primary cut off from replicas and witness, still reachable by clients | 3 | 28.2 s | 31.2 s | 28.17 s | 7881 | 0 | 0 | 0 | yes |
| upgrade-logical - Major upgrade 17 -> 18 with logical replication and a HAProxy cutover | 1 | 2.87 s | 2.87 s | 2.43 s | 2997 | 0 | 0 | 0 | yes |
| upgrade-pg-upgrade - Major upgrade 17 -> 18 with pg_upgrade --link (whole repmgr cluster) | 1 | 22.48 s | 22.48 s | 22.6 s | 2730 | 0 | 0 | 0 | yes |

## Other measurements

- [Acknowledged-but-lost commits under a partition](ack-leak/20261012T104459Z/result.md)
- [VACUUM FULL vs pg_repack under write load](maintenance-repack/20261012T105332Z/result.md)
- [Restore verification 2026-10-12T10:58Z](restore-verify/20261012T105823Z/result.md)
- [Security checks 2026-10-12T12:38Z](security/20261012T123755Z/result.md)
- [synchronous_commit vs transfer latency](sync-commit/20261012T102314Z/result.md)
- [Losing the only named synchronous standby](sync-standby-loss/20261012T102914Z/result.md)
