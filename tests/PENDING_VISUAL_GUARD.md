# Pending-terrain visual guard

Accepted and merged into main development on 25 October 2026, with an explicit
merge commit grouping feature commits `12fecad`, `68c63f3` and `03a9d6e` for future
removal if required. The safeguard is enabled; no startup switch is added.

The engine changes terrain before the mod's budgeted accounting queue runs. Visual
drying/restoration therefore skips positions with pending terrain edits. Actual
water regeneration, extraction and normal accounting are not blocked by this guard.

PendingTileChanges[surface][position] is a count, not a queue search. It increments
on successful enqueue, decrements after dispatch, and disappears after the edits
finish. No covered-tile history or periodic map scan is added. Existing queues and
scope-filtered queues rebuild this derived map once.

Candidate attempts, including skipped positions, consume the existing visual quota
and budget. This avoids scanning an entire pending lake to satisfy one successful
change. An affected lake's visual progress can pause until its edits drain; other
work still follows the existing scheduler. This is not a fairness guarantee or an
actual Factorio CPU benchmark.

Run `lua tests/run.lua`, then both diagnostics in tests/deferred/. They should pass
on current development. tests/test_pending_tile_backlog.lua additionally checks a 90-edit
backlog, bounded candidate lookup, unaffected progress and exact queue consumption.
The diagnostics fail on the pre-guard baseline `c6204ba` and remain separately runnable.

Actual Factorio 2.0 event ordering, native tile costs and average/tail performance
still require engine acceptance. No release or community claim is implied.

The [measured performance report](performance/PERFORMANCE_REPORT.md) includes
shared main/branch workloads, paired test-only bypasses, fresh-process controls,
registration plus consumption costs, identical-terrain controls and function
profiles. The experimental split-search shortcut in the profiler is not part
of the production implementation.
