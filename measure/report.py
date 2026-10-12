import glob
import json
import os
import statistics
import sys


def median(values):
    values = [v for v in values if v is not None]
    if not values:
        return None
    return round(statistics.median(values), 2)


def worst(values):
    values = [v for v in values if v is not None]
    if not values:
        return None
    return round(max(values), 2)


def fmt(v, unit=""):
    return "-" if v is None else f"{v}{unit}"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "results"
    rows = {}
    for path in sorted(glob.glob(os.path.join(root, "*", "*", "summary.json"))):
        s = json.load(open(path, encoding="utf-8"))
        rows.setdefault(s["scenario"], []).append((path, s))
    lines = [
        "# Results summary",
        "",
        "Each row aggregates every run under `results/<scenario>/`. RTO is measured from fault injection to the first",
        "successful write that is followed by a stable stream of successes; RPO counts transfers the client saw as",
        "committed (HTTP 201) that are not in the database after recovery.",
        "",
        "| scenario | runs | RTO median | RTO worst | client gap median | acked | RPO (missing acked) | duplicates | integrity violations | data safe |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for scenario in sorted(rows):
        runs = [s for _, s in rows[scenario]]
        rto = [(s.get("outage") or {}).get("rto_from_inject_s") for s in runs]
        gap = [(s.get("outage") or {}).get("client_gap_s") for s in runs]
        acked = sum(s.get("acked", 0) for s in runs)
        missing = sum((s.get("rpo_missing_acked") or 0) for s in runs)
        dups = sum((s.get("duplicate_transfers") or 0) for s in runs)
        viol = sum((s.get("integrity_violations") or 0) for s in runs)
        safe = all(s.get("data_safe") for s in runs)
        title = runs[-1].get("title", "")
        lines.append(
            f"| {scenario} - {title} | {len(runs)} | {fmt(median(rto), ' s')} | {fmt(worst(rto), ' s')} | "
            f"{fmt(median(gap), ' s')} | {acked} | {missing} | {dups} | {viol} | {'yes' if safe else 'NO'} |"
        )
    extra = sorted(glob.glob(os.path.join(root, "*", "*", "result.md")))
    if extra:
        lines += ["", "## Other measurements", ""]
        for path in extra:
            rel = os.path.relpath(path, root)
            first = open(path, encoding="utf-8").readline().strip().lstrip("# ")
            lines.append(f"- [{first}]({rel})")
    out = os.path.join(root, "SUMMARY.md")
    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(out)


if __name__ == "__main__":
    main()
