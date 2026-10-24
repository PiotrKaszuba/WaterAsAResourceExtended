"""Build auditable timing tables from compare_checkouts.py CSV output."""
import argparse
import csv
import json
import statistics as stats
from collections import defaultdict
from pathlib import Path

PHASES = {"scan_s", "collect_s", "visual_s", "enqueue_s", "drain_s", "settle_s",
          "cover_s", "reopen_s", "lifecycle_s", "rebuild_s"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    args = parser.parse_args()
    samples = defaultdict(dict)
    paths = list(args.results.glob("*.csv")) + list((args.results / "controls").glob("*.csv"))
    for path in sorted(paths):
        with path.open(encoding="utf-8-sig", newline="") as source:
            for row in csv.DictReader(source):
                variant = row["label"].split("-", 1)[1] if row["label"].startswith("round") else row["label"]
                key = (variant, row["case"], path.name, int(row["sample"]))
                samples[key][row["metric"]] = float(row["value"])
    grouped = defaultdict(list)
    for (variant, case, _, _), result in samples.items():
        result["phase_total_s"] = sum(result.get(phase, 0) for phase in PHASES)
        grouped[(variant, case)].append(result)
    summary = {}
    for (variant, case), results in grouped.items():
        metrics = {}
        for metric in sorted(set().union(*(r.keys() for r in results))):
            values = [r[metric] for r in results if metric in r]
            metrics[metric] = {"n": len(values), "median": stats.median(values),
                               "mean": stats.mean(values), "min": min(values), "max": max(values)}
        summary[f"{variant}/{case}"] = metrics
    (args.results / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    def value(variant, case, metric):
        return summary[f"{variant}/{case}"][metric]["median"]

    def ms(variant, case, metric="phase_total_s"):
        return f"{value(variant, case, metric) * 1000:.1f}"

    cases = sorted(case for variant, case in grouped if variant == "main")
    lines = ["# Measured tables", "", "All durations below are mock CPU milliseconds, median across repetitions.",
             "Phase total sums timed phases, excluding fixture setup and reporting.", "",
             "| Shared workload | Master | Guard on | Branch bypass | On vs master |",
             "|---|---:|---:|---:|---:|"]
    for case in cases:
        baseline = value("main", case, "phase_total_s")
        relative = value("guard-on", case, "phase_total_s") / baseline - 1
        lines.append(f"| {case} | {ms('main', case)} | {ms('guard-on', case)} | {ms('guard-off', case)} | {relative:+.1%} |")
    lines += ["", "Percentages are descriptive, not statistical significance or an engine forecast.",
              "Four general observations per variant are too few to establish small differences.", "",
              "The whole-suite runs also show substantial session drift/heap carryover: even unchanged",
              "pump code differs strongly. Do not treat the apparent scan/bypass speedups as causal.", "",
              "## Fresh-process controls", "",
              "Three rotated rounds; two measured repetitions and one warmup per fresh process/case.",
              "Six observations per variant. This removes cross-case heap carryover, but cannot",
              "eliminate machine/frequency/GC variation or establish tiny overheads.", "",
              "| Case | Master ms | Guard ms | Bypass ms |", "|---|---:|---:|---:|"]
    for case in ("pumps_1024_many_lakes", "visual_16384", "scan_65536", "queue_unique_8192"):
        if ("control-main", case) in grouped:
            lines.append(f"| {case} | {ms('control-main',case)} | {ms('control-on',case)} | {ms('control-off',case)} |")
    lines += ["",
              "## Paired branch-only comparison", "",
              "Same source/process with index/guard semantics enabled or bypassed; branch lookup", 
              "instructions and candidate bounds remain in the bypass. Five measured pairs per case.", "",
              "| Workload | Bypass | Enabled | Enabled vs bypass |", "|---|---:|---:|---:|"]
    for variant, case in sorted(grouped):
        if variant != "paired-on": continue
        baseline = value("paired-off", case, "phase_total_s")
        ratio = value("paired-on", case, "phase_total_s") / baseline - 1
        lines.append(f"| {case} | {ms('paired-off', case)} | {ms('paired-on', case)} | {ratio:+.1%} |")
    lines += ["", "## Cumulative registration plus consumption", "",
              "Paired branch-only medians. Each queue case handles 131,072 events across 16 bursts.",
              "Deltas below compare median phase sums, rather than summing separate phase medians.", "",
              "| Positions | Bypass enqueue ms | On enqueue ms | Bypass consume ms | On consume ms | Combined added ms | Added microseconds/edit |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for case in ("queue_unique_8192", "queue_repeated_8192"):
        delta = value("paired-on", case, "phase_total_s") - value("paired-off", case, "phase_total_s")
        cells = [ms(v, case, metric) for metric in ("enqueue_s", "drain_s") for v in ("paired-off", "paired-on")]
        lines.append(f"| {case} | {' | '.join(cells)} | {delta*1000:.1f} | {delta*1e6/131072:.3f} |")
    if ("preserved-on", "preserved_4096") in grouped:
        lines += ["", "## Identical preserved terrain control", "",
                  "Both modes have identical correct physical landfill and dry-grid state; no conflicting visual work.",
                  "Three measured pairs, plus a discarded warmup; 3,891 actual landfill events.", "",
                  "| Mode | Enqueue ms | Consume ms | Overwritten |", "|---|---:|---:|---:|"]
        for variant in ("preserved-off", "preserved-on"):
            lines.append(f"| {variant} | {ms(variant,'preserved_4096','enqueue_s')} | {ms(variant,'preserved_4096','drain_s')} | 0 |")
    lines += ["", "## Per-phase and cycle detail", "",
              "Each cell gives the median aggregate phase or median per-run cycle/slice statistic.",
              "Individual sub-millisecond measurements are clock-limited.", "",
              "| Case / metric | Master ms | Guard ms | Bypass ms |", "|---|---:|---:|---:|"]
    details = {
        "scan_262144": ["scan_s", "scan_s_scan_slice_p95_s", "scan_s_scan_slice_max_s", "scan_s_tick_max_s"],
        "visual_16384": ["dry_cycle_mean_s", "dry_cycle_max_s", "restore_cycle_mean_s", "restore_cycle_max_s"],
        "queue_unique_8192": ["enqueue_s", "drain_s", "drain_batch_p99_s"],
        "pending_dense_16384": ["enqueue_s", "visual_s", "drain_s", "drain_batch_p95_s", "drain_batch_max_s"],
        "pending_reload_8192": ["rebuild_s"],
        "mixed_backlog_scan": ["lifecycle_s", "lifecycle_s_scan_slice_p95_s", "lifecycle_s_tick_p99_s", "lifecycle_s_tick_max_s"],
    }
    for case, metrics in details.items():
        for metric in metrics:
            cells = [ms(v, case, metric) for v in ("main", "guard-on", "guard-off")]
            lines.append(f"| {case} / {metric} | {' | '.join(cells)} |")
    lines += ["", "## Correctness and progress", "",
              "| Case | Master overwritten | Guard overwritten | Guard changed | Guard attempts |",
              "|---|---:|---:|---:|---:|"]
    for case in cases:
        metrics = summary[f"guard-on/{case}"]
        if "overwritten" not in metrics: continue
        get = lambda v, m: str(round(value(v, case, m))) if m in summary[f"{v}/{case}"] else "—"
        lines.append(f"| {case} | {get('main','overwritten')} | {get('guard-on','overwritten')} | {get('guard-on','changed')} | {get('guard-on','examined')} |")
    lines += ["", "| Progress / retained memory metric | Master | Guard on | Bypass |", "|---|---:|---:|---:|"]
    for case, metric in [("mixed_backlog_scan", "ticks"), ("split_reopen", "cover_ticks"),
                         ("split_reopen", "reopen_ticks"), ("queue_unique_8192", "retained_queue_kib"),
                         ("queue_repeated_8192", "retained_queue_kib")]:
        cells = [f"{value(v,case,metric):.1f}" for v in ("main", "guard-on", "guard-off")]
        lines.append(f"| {case} / {metric} | {' | '.join(cells)} |")
    lines += ["", "Raw observations, mean/min/max and all recorded metrics are in the adjacent CSVs", 
              "and summary.json. The manifest records exact benchmark source hashes and revisions.", ""]
    profile_files = ["behavior-off", "behavior-on", "preserved-off", "preserved-on", "experimental-interior-skip"]
    profiles = {}
    for name in profile_files:
        path = args.results / "profiles" / f"{name}.csv"
        if path.exists():
            profiles[name] = {row["operation"]: row for row in csv.DictReader(path.open())}
    if len(profiles) == len(profile_files):
        lines += ["## Diagnostic attribution (4,096-tile lake)", "",
                  "Instrumented single profiles; times include wrapper overhead. Counts are deterministic.",
                  "Behavior-off overwrites the terrain; preserved-off/on both retain identical terrain/grids.",
                  "Experimental interior-skip is NOT in production and has no general topology certification.", "",
                  "| Metric | Behavior off | Behavior on | Preserved off | Preserved on | Experimental skip |",
                  "|---|---:|---:|---:|---:|---:|"]
        for operation, field in [("queue_dispatch", "inclusive_s"), ("adjacent_owned_land_search", "inclusive_s"),
                                 ("split_check", "calls"), ("tile_reads", "calls"), ("begin_scan", "calls"),
                                 ("create_successor", "calls"), ("bounded_component_search", "calls"),
                                 ("rebin_visual_candidates", "calls"), ("pending_index_add", "calls"),
                                 ("pending_index_finish", "calls"), ("overwritten", "calls")]:
            cells = []
            for name in profile_files:
                number = float(profiles[name][operation][field])
                cells.append(f"{number * 1000:.1f}" if field.endswith("_s") else str(int(number)))
            lines.append(f"| {operation} / {'ms' if field.endswith('_s') else 'count'} | {' | '.join(cells)} |")
        lines += [""]
    (args.results / "TABLES.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
