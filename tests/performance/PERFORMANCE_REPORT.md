# Pending-terrain guard: retained performance decision

Measured 24 October 2026; guard accepted 25 October. Consolidated 27 October.
The original full tables/raw samples are recoverable in Git at `b445cd3`.
Final release comparisons remain in [COUNTER-FIX-2026-10-25.md](COUNTER-FIX-2026-10-25.md).

## Scope and cost

The engine changes tiles before budgeted accounting consumes their events.
Per-surface/position pending counts protect physical drying/reflooding and grid
transfers; candidate attempts still consume visual quota. Regeneration amounts,
extraction and ordered split/merge accounting are not guarded. Scanner ownership
preservation for pending landfill was added by the later released bugfix.

Enqueue/consume/index lookup are expected constant-time hash operations, not a
queue sweep. Counts support repeated edits at one position; the derived map is
rebuilt on configuration changes/old state. No new covered-tile history or periodic
surface scan. A heavily pending lake may temporarily pause its visuals.

Paired mock measurements used discarded warmups, reversed order, normal GC and
Windows Lua 5.2 millisecond-resolution CPU time. They include mocks/instrumentation
and cannot predict UPS or tiny per-event tail costs.

| Measurement | Observed result |
| --- | --- |
| 131072 unique edits, combined registration/consumption | +66 ms, approximately 0.504 microseconds/edit |
| Same count repeated over 16 positions | +60 ms, approximately 0.458 microseconds/edit |
| 8192 distinct outstanding positions | Approximately +320 KiB retained Lua heap; repeated 16-position case under +1 KiB |
| Rebuild 8192 pending positions | Approximately 2.6 ms per rebuild |
| Identical correct terrain/grid, 4096-tile consumption | Bypass 4.982 s; enabled 5.204 s; same 590532 terrain reads and one scan start |

## Why some guarded drains were much slower

Preserving landfill changes the work compared with a broken baseline that
replaces it with water. In the dense 4096-tile profile, 5.142 of 5.242 seconds
were repeated searches through ground still listed as belonging to the old lake:
590532 terrain reads versus 69971 on corrupted terrain. Scan starts actually fell
393 → 1; no visual rebinning occurred. The equivalent-terrain control above keeps
the expensive work even with index bookkeeping bypassed.

At 16384 tiles / 95% pending overlap, whole-branch paired drain medians were
58.997 s enabled versus 1.032 s bypassed with different physical terrain. This is
not pure hash overhead. An observed eight-event batch reached 110 ms in mocks.
In the mixed default-budget workload, preserving terrain reduced settlement
1901 → 1260 ticks. No single average percentage describes these different cases.

Fresh-process scan controls gave medians 1.764 s unguarded, 1.826 s bypass,
1.871 s guard with overlapping ranges. No new per-scanned-tile visual guard was
introduced. Shared queue processing has a small real empty-index check; system
variation/GC prevent attributing the full difference to that check.

## Deferred remedy and repeatable tools

The test-only `interior-skip` variant avoids a deep search where no immediately
adjacent surviving wet/dry owned tile exists. One instrumented case fell
5.278 → 0.291 s, but parent invalidation timing changed. It is unapproved: prove
multi-cut topology, family finalization, reserves, brush orders and reload first.
Eager per-tile accounting or optimizing the hash lookup targets a different problem.

Keep the general [22 workloads](README.md), paired runners and attribution tools.
Run independently of fast correctness tests:

```text
lua tests/performance/run.lua 3
lua tests/performance/profile_drain.lua pending_dense_4096 on same-terrain
lua tests/performance/profile_drain.lua pending_dense_4096 off same-terrain
```

Historical comparison scripts also accept a separate unguarded checkout (for
example `c6204ba`). They produce new output directories; archived raw results
are not runtime/test dependencies. No timing-percentage correctness gate is used.
