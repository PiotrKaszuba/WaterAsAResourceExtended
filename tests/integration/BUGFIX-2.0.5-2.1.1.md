# Water landfill/depletion bugfix release verification

2026-10-25. Prepared for Factorio 2.0 (Water **2.0.5**) and Factorio 2.1
(Water **2.1.1**). Local commits/packages complete; no new remote push, tag or
portal upload was performed for these versions.

## What changed

1. **Preserve pending landfill ownership during scanning.** Deferred terrain
   accounting can remove its grid membership/capacity exactly once, rather than
   leaving stale visual entries that later overwrite landfill. Both scan routes.
2. **Flush scan batches at actual merge boundaries.** Local dry counts, discovered
   area and geometry are committed before merging and refreshed afterwards,
   whether the current ID survives or changes. This fixes the internal count
   corruption behind repeated `ToDryTiles` warnings; the warning is not hidden.
3. **Apply negative geometry deltas on removal.** Lake tile count, coordinate sums
   and centroid now reflect landfill.
4. **Repair affected saved derived state once on upgrade.** Recount membership,
   dry tiles, scan area and geometry; recalculate visual demand normally. Reserve,
   extraction debt, pump states, queued events and physical terrain are preserved.
   A 2.0.5 → 2.1.1 upgrade skips the already-applied repair.
5. **Write portable ZIP paths on Windows.** Explicit forward-slash entries fix
   the .NET Framework packaging issue discovered by Linux engine loading.

Historical preparation used independent 2.0 and 2.1 branches with cherry-picked
fixes. The 2026-10-26 history cleanup makes the corrected 2.0.5 branch the shared
ancestor of rebuilt 2.1 support; those fixes and this combined evidence now
originate once in active ancestry. The original tested commits remain archived,
and the dated results below still describe their original candidate ZIPs.
Shared scan, waterbody and pending-index source files remain byte-identical.
See [history cleanup](../HISTORY-REBUILD-2026-10-26.md) for the new lineage and
fresh rebuilt-artifact verification; do not substitute its hash for these results.

## Acceptance evidence

| Candidate | Native engine | Profiles | Checks across all phases | Mock suite |
| --- | --- | --- | --- | --- |
| 2.0.5 | 2.0.77 | 6 passed | 107 passed | 37 files / 1016 passing assertions |
| 2.1.1 | 2.1.23 | 9 passed | 239 passed | 37 files / 1022 passing assertions |

Counts include assertions before save checkpoints as well as after restart;
counting only final-phase assertions would give 102 / 189. The same exact
candidate ZIP was used for every profile within each native run.

- Both: startup enabled/disabled, real pump energy/extraction and regeneration,
  real robot landfill placement/mining, wet/dry hidden terrain, zero-water
  reopening, actual save/restart with pending terrain, and new `scan_merge`.
- 2.1 additionally: pump transitions, actual 2.0.4 checkpoint upgrade, extended
  settings/research/landfill persistence. This release run is base-game only;
  partner-mod runs from the preceding ownership investigation remain separate
  historical evidence, not claimed as fresh full-release partner certification.
- `scan_merge`: seven native pumps drain a 48×32 lake; a dry enclosure triggers
  reconstruction. Every-tick dry count, discovered area and geometry invariants
  remain consistent; landfill survives; ordinary tiny-pond cleanup is included.
- Default mock regressions cover both merge-survivor cases, wet/dry removals and
  affected versions, including an upgrade with pending FIFO accounting.
- The retained historical dry-cut reproduction and wet control both now pass.

## Exact user-trial replay and damaged-save recovery

The native replay reproduces the GUI brush positions, old tile payloads and
ticks using native inventory actions on an isolated checkpoint. Nine closed-loop
brushes (36 tiles) and the eight-brush open control both pass on fixed code:
no lost landfill, no dry-counter gap, scans/events settled, and zero differences
from recorded pre-brush states. Released 2.1.0 is the negative control: closing
the enclosure leaves a 129-tile gap. This confirms the previously identified
scan/merge batching bug; it is not a third independent defect.

A separate trial loads the **actually damaged** checkpoint through a real
2.1.0 → 2.1.1 configuration change, with no terrain actions. Before ticking,
actual/recorded dry membership becomes 1,803/1,803 instead of 1,803/1,674.
Remaining reserve is identical at -74.48531926469877; after 600 ticks it is
15.669450087094447 in both versions. Fixed visual counts stay consistent and
all 36 landfill tiles survive. Personal worlds/support mods stay local and
ignored; the runner, schedule and observer are retained under `repros/` on 2.1.

## Performance

See [performance report](../performance/COUNTER-FIX-2026-10-25.md), raw CSV and
metric summaries. Both isolated-counter and complete-release comparisons were
run with matched workloads and alternating order. No substantial recurring
regression was observed. Full-patch median scan cost is +0.9% at 65,536 tiles;
small reopening/pump aggregates rise 2/7 ms. Sample variability and observed
maxima are reported rather than concealed. These are mock CPU measurements,
not a Factorio UPS guarantee.

The one-time repair costs a median 1.354 s for 262,144 wet tiles and 0.330 s for
65,536 dry tiles in the Lua benchmark, with about 14/6 MiB live heap growth.
It can briefly pause an affected-save upgrade; no recurring recount was added.

## Exact artifacts

ZIP CRCs, forward-slash paths, one correct root folder, manifest versions and
all packaged file bytes were verified. Each ZIP still matches its corresponding
native run SHA-256 and current packaged source files; later report/test-only
changes are excluded by the packager. Source-dirty flags in native reports
record the in-progress test/documentation work, not an untested replacement ZIP.

- `WaterAsAResourceExtended_2.0.5.zip`: 280,478 bytes, 29 files; SHA-256 `14f80c7eab962fdb9617e9bb22b2126a38fe054d1ede5aedd36163e615583b1a`.
- `WaterAsAResourceExtended_2.1.1.zip`: 280,726 bytes, 29 files; SHA-256 `c65d861d2a74424ae80cf522a7843faf0e5bd3052baf92379c4bc01f33791890`.

Machine-readable evidence and run IDs:
[`results/2026-10-25-bugfix-releases.json`](results/2026-10-25-bugfix-releases.json).
Full logs/disposable worlds remain in ignored `tests/artifacts/`.

## Publication and remaining boundaries

Upload **2.0.5 first, then 2.1.1** under the existing mod. Each manifest retains
its own `factorio_version` family (2.0 / 2.1); the game selects compatible
updates. The last upload determines the portal-served changelog, so leave the
newer family last. Existing old release tags were not moved.

The repair fixes derived counters, not terrain history: landfill already
physically overwritten by an older release cannot be reconstructed. Editor
instant deconstruction that omits supported tile events remains unsupported.
No additional gameplay features, Space Age changes or performance redesign
are included. Normal inventory/robot placement and mining are supported.
