# Optional pending-terrain visual guard

This branch adds the deferred safeguard to the landfill feature. Main development
keeps it disabled. Merging this branch enables it; no startup switch is added.

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
on this branch. tests/test_pending_tile_backlog.lua additionally checks a 90-edit
backlog, bounded candidate lookup, unaffected progress and exact queue consumption.
The default development branch intentionally retains the two failing diagnostics.

Actual Factorio 2.0 event ordering, native tile costs and average/tail performance
still require engine acceptance. No release or community claim is implied.
