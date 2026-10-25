# Performance review: Water 2.0.5 / 2.1.1

2026-10-25. No substantial recurring regression was observed in the selected
large-lake, visual, split/merge, backlog and pump workloads. Small positive
deltas remain below; this is measured evidence, not a guarantee for every save.
The fixed shared scan/accounting code is identical in both release branches.

## Avoiding recurring work

- Commit/reload scan-local counts and geometry **only at actual merge boundaries**.
  Ordinary tiles remain batched; no added per-tile counter writes or feature check.
- Pending-landfill ownership lookup runs only when a scanner meets physical
  landfill. It uses the existing position hash, not a queue search.
- Pump extraction and normal regeneration receive no new checks.
- Affected-version upgrades rebuild derived counts/geometry once. No periodic
  recount, extra saved history, or terrain reconstruction was added.

## Complete patch versus released 2.0.4

Three measured samples per version, each after one discarded warmup. Seconds
below are aggregate **mock CPU**, not per-tick engine latency. Paired execution
order alternates. Ranges are observed minima/maxima, not guaranteed bounds.

| Workload / phase | Released median (range) | Fixed median (range) | Median change |
| --- | --- | --- | --- |
| scan_65536 / scan_s | 1.720 (1.666–1.818) | 1.736 (1.708–1.753) | +0.9% |
| dry_merge_16384 / lifecycle_s | 0.591 (0.583–0.592) | 0.582 (0.553–0.659) | -1.5% |
| split_reopen / cover_s | 0.068 (0.064–0.069) | 0.066 (0.062–0.074) | -2.9% |
| split_reopen / reopen_s | 0.010 (0.010–0.012) | 0.012 (0.011–0.012) | +20.0% |
| mixed_backlog_scan / lifecycle_s | 0.602 (0.594–0.655) | 0.587 (0.585–0.612) | -2.5% |
| pumps_1024_many_lakes / collect_s | 0.165 (0.164–0.169) | 0.172 (0.164–0.177) | +4.2% |

The reopening increase is 2 ms over the whole eight-lake phase; both observed
maxima are 12 ms. The pump aggregate increases 7 ms with overlapping ranges;
its production hot path is unchanged. The 65,536-tile scan still takes 121
simulation ticks, and mixed settlement 1,260. Dry split/merge still performs
seven merges in the fixed 4,896-tick window; its final counter gap falls from
6,058 to zero. Lower elapsed time in broken code would not establish equivalent
work. No speedup is claimed from these noisy negative deltas.

## Isolated merge-boundary comparison

Baseline already contains ownership/geometry fixes. This earlier paired session
used 3–5 samples per version; compare its own pairs, not absolute times against
the separate full-release session above.

| Workload / phase | Before median | After median | Median change |
| --- | --- | --- | --- |
| scan_65536 / scan_s | 3.107 s | 3.125 s | +0.6% |
| scan_262144 / scan_s | 13.081 s | 12.795 s | -2.2% |
| dry_merge_16384 / lifecycle_s | 0.808 s | 0.746 s | -7.7% |
| visual_16384 / visual_s | 0.576 s | 0.570 s | -1.0% |
| split_reopen / cover_s | 0.091 s | 0.097 s | +6.6% |
| split_reopen / reopen_s | 0.014 s | 0.015 s | +7.1% |
| mixed_backlog_scan / lifecycle_s | 0.871 s | 0.846 s | -2.9% |
| pumps_1024_many_lakes / collect_s | 0.257 s | 0.260 s | +1.2% |

Largest scan (262,144 tiles) finishes in 152 ticks on both variants. Observed
visual dry-cycle maxima are 127 → 118 ms and reflood maxima 52 → 54 ms.
Mixed-lifecycle observed maximum rises 888 → 947 ms, despite a lower median.
Those maxima include mock work/GC and do not establish a stable worst-case
regression. Complete distributions, including tick/scan slices and queue-drain
batches where instrumented, are retained alongside the primary phase times.

## One-time affected-save repair

Three measured samples after one warmup, setup excluded:

| Tracked membership | Median CPU | Observed range | Live Lua heap increase |
| --- | --- | --- | --- |
| repair_wet_262144 | 1.354 s | 1.145–1.396 s | 14.0 MiB |
| repair_dry_65536 | 0.330 s | 0.322–0.380 s | 6.0 MiB |

This can cause a brief upgrade-time pause, scaling with total tracked membership.
It is O(wet + dry membership), with temporary per-body deduplication tables, and
runs before simulation resumes only for affected version upgrades. It preserves
reserve/debt and pending FIFO accounting. Heap growth is not peak process memory.
A 2.0.5 → 2.1.1 update skips the already-applied repair.

## Retained coverage and reproduction

The normal optional performance suite now retains `dry_merge_16384` (128×128,
seven pumps, 98% depletion, a gradual two-wide cut) and
`repair_wet_262144` / `repair_dry_65536`. Run independently of fast correctness:

```text
lua tests/performance/run.lua 3 dry_merge_16384
lua tests/performance/run.lua 3 repair_
```

Raw CSV, all metric summaries, baseline revisions, sample counts and method:
[`results/2026-10-25-counter-fix/`](results/2026-10-25-counter-fix/).
No fragile timing-percent assertion is used as a correctness gate. Native
acceptance separately checks engine behavior; these CPU measurements cannot
predict Factorio UPS or certify every late-game interleaving.
