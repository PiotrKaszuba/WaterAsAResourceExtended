# Measured tables

All durations below are mock CPU milliseconds, median across repetitions.
Phase total sums timed phases, excluding fixture setup and reporting.

| Shared workload | Master | Guard on | Branch bypass | On vs master |
|---|---:|---:|---:|---:|
| mixed_backlog_scan | 1259.0 | 739.5 | 964.0 | -41.3% |
| pending_dense_1024 | 129.5 | 9.5 | 96.0 | -92.7% |
| pending_dense_16384 | 1106.0 | 53954.5 | 754.5 | +4778.3% |
| pending_dense_4096 | 421.0 | 5429.5 | 330.5 | +1189.7% |
| pending_drying_4096 | 1327.0 | 11614.5 | 926.0 | +775.2% |
| pending_reload_8192 | 182.0 | 344.5 | 160.5 | +89.3% |
| pending_sparse | 27.0 | 7.0 | 20.5 | -74.1% |
| pumps_1024_many_lakes | 276.5 | 198.5 | 156.0 | -28.2% |
| pumps_256 | 53.0 | 37.5 | 39.0 | -29.2% |
| queue_repeated_8192 | 219.5 | 200.5 | 159.5 | -8.7% |
| queue_unique_8192 | 252.5 | 221.5 | 167.0 | -12.3% |
| scan_16384 | 398.0 | 331.0 | 333.0 | -16.8% |
| scan_262144 | 8634.5 | 7289.5 | 5811.5 | -15.6% |
| scan_4096 | 86.0 | 83.5 | 83.5 | -2.9% |
| scan_65536 | 1647.0 | 1708.5 | 1394.5 | +3.7% |
| shoreline_brush | 68.0 | 41.5 | 44.0 | -39.0% |
| split_reopen | 94.5 | 65.0 | 69.0 | -31.2% |
| visual_16384 | 703.5 | 373.5 | 364.5 | -46.9% |
| visual_cycles | 224.0 | 105.5 | 112.0 | -52.9% |

Percentages are descriptive, not statistical significance or an engine forecast.
Four general observations per variant are too few to establish small differences.

The whole-suite runs also show substantial session drift/heap carryover: even unchanged
pump code differs strongly. Do not treat the apparent scan/bypass speedups as causal.

## Fresh-process controls

Three rotated rounds; two measured repetitions and one warmup per fresh process/case.
Six observations per variant. This removes cross-case heap carryover, but cannot
eliminate machine/frequency/GC variation or establish tiny overheads.

| Case | Master ms | Guard ms | Bypass ms |
|---|---:|---:|---:|
| pumps_1024_many_lakes | 198.5 | 214.0 | 184.5 |
| visual_16384 | 499.5 | 500.0 | 511.5 |
| scan_65536 | 1764.0 | 1870.5 | 1825.5 |
| queue_unique_8192 | 206.0 | 296.0 | 228.5 |

## Paired branch-only comparison

Same source/process with index/guard semantics enabled or bypassed; branch lookup
instructions and candidate bounds remain in the bypass. Five measured pairs per case.

| Workload | Bypass | Enabled | Enabled vs bypass |
|---|---:|---:|---:|
| mixed_backlog_scan | 1176.0 | 676.0 | -42.5% |
| pending_dense_16384 | 1032.0 | 58997.0 | +5616.8% |
| pending_drying_4096 | 1170.0 | 13120.0 | +1021.4% |
| pending_reload_8192 | 193.0 | 336.0 | +74.1% |
| pumps_1024_many_lakes | 180.0 | 187.0 | +3.9% |
| queue_repeated_8192 | 203.0 | 263.0 | +29.6% |
| queue_unique_8192 | 211.0 | 277.0 | +31.3% |
| visual_16384 | 452.0 | 468.0 | +3.5% |

## Cumulative registration plus consumption

Paired branch-only medians. Each queue case handles 131,072 events across 16 bursts.
Deltas below compare median phase sums, rather than summing separate phase medians.

| Positions | Bypass enqueue ms | On enqueue ms | Bypass consume ms | On consume ms | Combined added ms | Added microseconds/edit |
|---|---:|---:|---:|---:|---:|---:|
| queue_unique_8192 | 131.0 | 167.0 | 75.0 | 113.0 | 66.0 | 0.504 |
| queue_repeated_8192 | 115.0 | 145.0 | 85.0 | 113.0 | 60.0 | 0.458 |

## Identical preserved terrain control

Both modes have identical correct physical landfill and dry-grid state; no conflicting visual work.
Three measured pairs, plus a discarded warmup; 3,891 actual landfill events.

| Mode | Enqueue ms | Consume ms | Overwritten |
|---|---:|---:|---:|
| preserved-off | 22.0 | 4982.0 | 0 |
| preserved-on | 27.0 | 5204.0 | 0 |

## Per-phase and cycle detail

Each cell gives the median aggregate phase or median per-run cycle/slice statistic.
Individual sub-millisecond measurements are clock-limited.

| Case / metric | Master ms | Guard ms | Bypass ms |
|---|---:|---:|---:|
| scan_262144 / scan_s | 8634.5 | 7289.5 | 5811.5 |
| scan_262144 / scan_s_scan_slice_p95_s | 712.0 | 711.0 | 477.5 |
| scan_262144 / scan_s_scan_slice_max_s | 712.0 | 711.0 | 477.5 |
| scan_262144 / scan_s_tick_max_s | 712.0 | 711.0 | 477.5 |
| visual_16384 / dry_cycle_mean_s | 123.6 | 65.4 | 62.4 |
| visual_16384 / dry_cycle_max_s | 141.5 | 79.5 | 73.5 |
| visual_16384 / restore_cycle_mean_s | 56.1 | 28.0 | 28.9 |
| visual_16384 / restore_cycle_max_s | 71.0 | 36.5 | 37.5 |
| queue_unique_8192 / enqueue_s | 145.5 | 125.5 | 104.0 |
| queue_unique_8192 / drain_s | 107.0 | 94.5 | 63.0 |
| queue_unique_8192 / drain_batch_p99_s | 1.0 | 1.0 | 0.0 |
| pending_dense_16384 / enqueue_s | 132.5 | 102.0 | 103.0 |
| pending_dense_16384 / visual_s | 237.0 | 55.0 | 134.5 |
| pending_dense_16384 / drain_s | 713.5 | 53801.0 | 517.0 |
| pending_dense_16384 / drain_batch_p95_s | 3.0 | 55.0 | 2.0 |
| pending_dense_16384 / drain_batch_max_s | 16.0 | 83.0 | 20.5 |
| pending_reload_8192 / rebuild_s | 0.0 | 75.5 | 0.0 |
| mixed_backlog_scan / lifecycle_s | 1259.0 | 739.5 | 964.0 |
| mixed_backlog_scan / lifecycle_s_scan_slice_p95_s | 8.0 | 7.5 | 8.5 |
| mixed_backlog_scan / lifecycle_s_tick_p99_s | 14.0 | 7.0 | 12.0 |
| mixed_backlog_scan / lifecycle_s_tick_max_s | 34.0 | 87.5 | 24.0 |

## Correctness and progress

| Case | Master overwritten | Guard overwritten | Guard changed | Guard attempts |
|---|---:|---:|---:|---:|
| mixed_backlog_scan | 2048 | 0 | — | — |
| pending_dense_1024 | 972 | 0 | 52 | 2048 |
| pending_dense_16384 | 15564 | 0 | 820 | 32768 |
| pending_dense_4096 | 3891 | 0 | 205 | 8192 |
| pending_drying_4096 | 3891 | 0 | 205 | 8192 |
| pending_sparse | 20 | 0 | 1004 | 2048 |

| Progress / retained memory metric | Master | Guard on | Bypass |
|---|---:|---:|---:|
| mixed_backlog_scan / ticks | 1901.0 | 1260.0 | 1901.0 |
| split_reopen / cover_ticks | 390.0 | 390.0 | 390.0 |
| split_reopen / reopen_ticks | 121.0 | 121.0 | 121.0 |
| queue_unique_8192 / retained_queue_kib | 3712.2 | 4032.3 | 3712.2 |
| queue_repeated_8192 / retained_queue_kib | 3712.2 | 3712.9 | 3712.2 |

Raw observations, mean/min/max and all recorded metrics are in the adjacent CSVs
and summary.json. The manifest records exact benchmark source hashes and revisions.

## Diagnostic attribution (4,096-tile lake)

Instrumented single profiles; times include wrapper overhead. Counts are deterministic.
Behavior-off overwrites the terrain; preserved-off/on both retain identical terrain/grids.
Experimental interior-skip is NOT in production and has no general topology certification.

| Metric | Behavior off | Behavior on | Preserved off | Preserved on | Experimental skip |
|---|---:|---:|---:|---:|---:|
| queue_dispatch / ms | 366.0 | 5242.0 | 5253.0 | 5278.0 | 291.0 |
| adjacent_owned_land_search / ms | 24.0 | 5142.0 | 5178.0 | 5196.0 | 104.0 |
| split_check / count | 256 | 1185 | 1185 | 1185 | 3821 |
| tile_reads / count | 69971 | 590532 | 590532 | 590532 | 66200 |
| begin_scan / count | 393 | 1 | 1 | 1 | 1 |
| create_successor / count | 393 | 1 | 1 | 1 | 1 |
| bounded_component_search / count | 533 | 1 | 1 | 1 | 1 |
| rebin_visual_candidates / count | 0 | 0 | 0 | 0 | 0 |
| pending_index_add / count | 3891 | 3891 | 3891 | 3891 | 3891 |
| pending_index_finish / count | 3891 | 3891 | 3891 | 3891 | 3891 |
| overwritten / count | 3891 | 0 | 0 | 0 | 0 |
