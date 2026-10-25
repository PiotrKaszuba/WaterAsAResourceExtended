# Automated tests

Run from the mod directory:

```text
lua tests/run.lua
```

Discovery supports Windows and Unix shells. A missing test set, failed assertion
or Lua runtime error makes the runner exit unsuccessfully.

## Landfill regressions

`test_landfill_scan_ownership.lua` covers queued landfill reached by a second
scan or its edge discovery, before removal accounting runs. Wet/dry covers
must lose exactly one tile of capacity and remain landfilled through subsequent
drying and restoration. The reduced case requires neither mining nor a merge.

`test_landfill_conservation.lua` is independent of tile mining and the typed dry
palette. It catches stale capacity being used for the next brush reduction or
for a split parent's inherited depletion percentage. Single, sequential and
potential-split brushes check exact reserve amounts.

`test_tile_layer_contract.lua` checks the mock's foundation/hidden-tile behavior
independently of mod callbacks: water beneath landfill, pavement above landfill,
double-hidden terrain, script-adjusted underlays, and successful versus failed
tile-mining events.

`test_landfill_reclamation.lua` exercises the actual registered player/robot
event routes and production accounting. It covers:

- All six supported wet tile identities, capacity categories and colors, with
  zero water added by mining and persistence across a storage/code reload.
- Active depleted terrain and both legacy orphan metadata formats.
- Deletion of a fully reclaimed mixed lake, followed by later paid waterfill and
  pump registration; historical depletion must not be erased by a fresh scan.
- Three sibling lakes created by two cuts, then reopened and merged without
  reserve growth.
- Queued partial brush removal, low work budgets and reload. Visual work is tested
  after these edits drain; interleaving before that point has separate diagnostics below.
- A newer paid waterfill winning over an older queued restoration.
- Repeated cover/uncover cycles, independent pavement removal, failed mining,
  repeated robot tile-proxy entity events, and ignored surfaces.

## Pending-terrain diagnostics

Queued terrain protection is enabled on development. The default suite does not
claim that every interleaving of visual work and pending terrain edits is safe.
Additional diagnostics retain their historical `tests/deferred/` paths and are
not discovered by the default runner. Both should pass with the merged guard:

```text
lua tests/deferred/test_pending_landfill_visual_race.lua
lua tests/deferred/test_mining_visual_interleaving.lua
```

The first checks pending landfill being overwritten by visual drying. The
second follows landfill removal through a later scan, exposing 50 recreated
water units on the pre-guard baseline. The default suite has a backlog test checking
that affected terrain remains covered while unaffected visual work continues;
its lookup measurement catches an unbounded sweep in a guard implementation.

Natural regeneration and extraction are disabled in conservation comparisons.
The primary invariant is total remaining water, rather than a tile's appearance:
an empty tile joining a partly full lake can legitimately become wet through the
existing whole-waterbody visual model.

## Limits

The separate [native acceptance suite](integration/README.md) exercises exact-ZIP
loading, startup variants, real pumping and setting changes, robot wet/dry-bed
landfill/mining and native save/restart with queued visual work. Run
`./scripts/test-integration.ps1` from the repository root. It does not replace or
require changes to this mock runner; each layer remains independently runnable.

For larger repeatable workloads, CPU phase/cycle timings and tick/scan-slice
distributions, see [performance/README.md](performance/README.md). Run this suite
separately from the fast regressions; it includes mid/late-game stress scales.

The mock reproduces the documented Factorio 2.0 tile-layer rules and event
payloads used by these tests. It does not reproduce engine collision correction,
entity destruction, real robot scheduling or native save serialization.
`helpers/save_reload.lua` reconstructs the storage graph, preserving aliases and
mock LuaObject identities, rejects stored functions, and reloads runtime modules.
It is a queued-state persistence check, not certification of a real save file.
Real Factorio acceptance remains necessary for those engine behaviors.
