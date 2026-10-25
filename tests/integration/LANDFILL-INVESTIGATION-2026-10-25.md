# Landfill / depletion report following the 2.1.0 acceptance

Historical evidence retained from the original 2.1 lineage (archived at `eb88e9c`).
Its dated results and commit/ZIP hashes are unchanged by the 2026-10-26 rebuild.
Fresh validation is recorded separately.

Status: both production defects and the related geometry-removal bug are fixed in prepared 2.0.5 / 2.1.1 packages. Affected-save counter repair and native/performance verification passed. No portal upload, new tag or remote push has been performed. See [final verification](BUGFIX-2.0.5-2.1.1.md).

The investigation below is chronological. References to an open defect/current failure describe the intermediate ownership-only state before the final counter fix, not the prepared releases.

## Confirmed warning and counter defect

- Inspected isolated copies of `THE_TEST_SAVE` (an exported scenario retaining `script.dat`) and the recent autosave. Both reproduce the warning in Factorio 2.1.23 with the user's enabled mods/settings copied into separate directories.
- Initial Mistassini state: area 1,687; dry-grid membership 1,687; `DriedTiles` 1,640; no wet-grid members; no pending terrain events. The dry counter is short by 47. Repeated requests to dry additional tiles cannot succeed when the wet grid is empty.
- The discrepancy survives regeneration. A warning-free interval does not mean the counter repaired itself; regeneration can lower the target until the impossible extra work disappears. Another depletion exposes it again.
- Fresh mock reproduction uses a 48 Ă— 32 lake, three pumps, 98% depletion and a gradual two-tile-wide cut. Production tick handlers perform visual work, queued landfill accounting, potential splits and successor scans/merges. At tick 3,211 one successor has 15 dry members but a counter of 12.
- The affected scan/merge source is identical between `v2.0.4` and `v2.1.0`; this finding is not a change introduced by the 2.1 pump API adaptation. The reproduction itself was run against the current branch, not in a 2.0 engine.
- The identical wet-only control passes this invariant. Its dry increments are zero, so it does not expose this specific loss. Earlier dry-landfill/conservation tests did not assert this invariant throughout the scan/merge interleaving.
- Cause: `ScanWaterArea` batches dry-count/area updates in local variables while `processWaterTile` can merge bodies. A merge reads stored counters before all current local increments have been committed. The caller also refreshes its locals only when the surviving ID changes; a merge retaining the current ID can change the stored counters too.
- A private proof variant flushes batch counters before merge-capable processing and refreshes after every merge, including those retaining the ID. The original longer reproduction then passes. This is evidence for the diagnosis, not an approved production implementation or performance result.

Retained failing regression (outside normal suite discovery):

```text
lua tests/repros/landfill_dry_counter.lua
lua tests/repros/landfill_dry_counter.lua --wet
```

At the diagnostic stage the first failed and the second passed. Both pass after the production fix; the stronger default `test_scan_merge_counters.lua` now checks counts, area and geometry throughout wet/dry reconstruction. The warning was not suppressed.

## Landfill replacement: reproduced and fixed

Earlier trials finished placing their brushes before restoration started and
did not reproduce the loss. Targeting brushes during natural regeneration did.
The only terrain action was ordinary inventory landfill placement; no waterfill
or mining was used. Regeneration was set to 1,000 to reach the overlap sooner.

Native trace for (-5, -83):

| Tick | Release behavior |
| --- | --- |
| 34,722 | Lake 9 restores the dry bed to deep water. |
| 34,724 | A native 2 Ă— 2 inventory brush places landfill; its accounting event is queued. |
| 34,731 | Another scan encounters that landfill and clears its owner to -1, but Lake 9 still retains its visual-grid entry. |
| 34,740 | Queued landfill accounting sees no owner, skips removal, then clears the pending marker. |
| 34,742 | Visual drying uses the stale grid entry and overwrites landfill with a dry lake tile. |

The pending visual guard works while the event is pending. The failure occurs
after the event drains without removing the grid entry. The native trace has
internal split-scan merges, even though the player only places landfill. A
reduced three-tile mock reproduces both water and dry-bed overwrites without
any merge, waterfill or mining: another scanner is sufficient.

Two scan paths could clear ownership: processing a queued position and edge
discovery from a neighbouring tile. Both now retain ownership when the physical
tile is landfill and the existing pending-position index contains that key.
FIFO accounting can then remove its capacity, wet/dry membership and owner.
Settled terrain follows the existing path. There is no new queue, history,
whole-queue search, or extraction/regeneration guard. The pending lookup is
restricted to non-water scan positions that are physically landfill.

### Verification

- Default regression `tests/test_landfill_scan_ownership.lua`: 48 assertions,
  covering both scan routes, wet/dry placement, exact capacity removal, empty
  pending bookkeeping, and both later visual directions. Baseline: 24 failures;
  fix: all pass. It replaces the earlier standalone failing ownership repro.
- Frozen native brush schedule: the same 71 brush attempts produce 249 covered
  positions. Baseline loses one; fix loses none. Both perform six merges and two
  splits, and the fixed trace confirms the grid entry is removed at tick 34,740.
  This replay uses diagnostic wrappers around otherwise unchanged production
  operations; it is separate from the exact-ZIP acceptance below.
- Full mocks: 34 files, 992 passing assertions. Both existing deferred-path
  visual/mining race diagnostics also pass.
- Exact candidate ZIP: all eight base profiles pass (175 checks). The actual
  AAI Industry 0.7.5, offshore-burner 1.0.3 and Alien Biomes/graphics 0.8.0
  combination passes `partners` and `landfill` (48 more checks).
- Candidate SHA-256: `e8a6ba8a67a70d48b05b40e35b6252d9c2e4115ef92bdab03cff95a9dec749d3`.
  It is an isolated test candidate, not a replacement for the published ZIP.

The fix prevents this ownership loss during future pending edits. It does not
rebuild already corrupted saved bookkeeping or restore already disappeared
landfill. The counter defect remains separate work before calling the whole
reported depletion/landfill problem resolved.

Suggested eventual user changelog line: â€śFixed landfill being replaced during
depletion or regeneration.â€ť

The affected code also exists on the final 2.0 branch. This isolated fix can be
backported, but no 2.0 branch or release is changed or engine-tested here.

### Focused performance check

CPU timings are from mocks, not Factorio UPS. Baseline is an export of the
unmodified `v2.1.0` branch head; fixed uses the same workload code. Each process
warms up once, and baseline/fix order alternates between samples.

| Workload / phase | Baseline median | Fixed median | Samples per version |
| --- | --- | --- | --- |
| Scan 65,536 tiles, repeated comparison | 1.886 s | 1.868 s | 7 |
| Dense pending brush, 1,024 tiles, queue drain | 0.005 s | 0.006 s | 3 |
| Concurrent scan/backlog lifecycle | 0.681 s | 0.619 s | 3 |

The first three large-scan pairs appeared slower (1.641 â†’ 2.074 s), so only
that workload was repeated. The repeat ranges overlap: baseline 1.834â€“2.155 s,
fixed 1.809â€“1.971 s. It does not reproduce the initial material slowdown or
establish an improvement. Both versions settle the scan in 121 ticks and the
mixed workload in 1,260 ticks. Dense queue timing is close to clock granularity.
No new unbounded search is introduced; the hash lookup is only reached for
physical landfill encountered by scanning. Raw samples and method are in
`tests/performance/results/2026-10-25-landfill-fix/`.

## Mining and announcements

- Four owned deep dry tiles near (-25, -80): real inventory placement changes area 1,687 â†’ 1,683 and capacity 176,550 â†’ 175,950; native player mining returns area/capacity to their original values. Reserve does not increase on mining. Both cover and uncover emit the normal lake-updated message with tile messages enabled.
- Four dry tiles near (-10, -80) are already unassigned (`owner = -1`) in the supplied state, and their immediate neighborhood does not attach them to a tracked body through this edit. Cover/uncover there leaves tracked capacity unchanged and produces no lake-updated announcement. The revealed terrain remains the correct empty deep dry bed.
- This is a possible explanation for the user's missing announcement, not identification of the exact reported coordinates. The supplied map contains more physical dry terrain than the tracked lake's area.

### Editor instant deconstruction

Native comparison on four tracked deep dry tiles, with regeneration disabled:

| Removal route | Physical result | Mining event | Lake area afterwards |
| --- | --- | --- | --- |
| Editor planner, instant deconstruction on | Dry bed revealed | None; only tile-proxy deconstruction requests observed | 1,683 (not reattached) |
| Editor planner, instant deconstruction off, no robots | Landfill stays marked | None yet | 1,683 |
| Normal player `mine_tile` route | Dry bed revealed | Four `on_player_mined_tile` events | 1,687 (reattached) |

This confirms the user's editor symptom differs from normal mining. Editor
instant removal is left unsupported: a request event is not a completed
removal notification. No editor-specific bookkeeping is introduced by this fix.

## Next work

1. Fix scan/merge accumulator consistency separately, covering both surviving-ID directions, multiple merges, dry/wet mixtures, and saved incorrect counters.
2. Recheck repeated depletion/restoration after that change. Do not remove the counter warning merely because landfill survives.
3. Decide release metadata/package/tag only after the remaining intended fixes; this work does not modify the existing release.

## Local evidence

Ignored diagnostic directory: `tests/artifacts/landfill-user-repro-20261025/`.
It retains copies of the original scenario/autosave, staged mods, instrumentation, engine logs, tile events, snapshots, wet control, and private proof patch. These copies include user-world data and are not committed or packaged.

Key files: `benchmark.log`, `scenario-engine.log`, `actions.log`, `visual.log`, `managed-mining.log`; corresponding `*-user/script-output/` JSON/JSONL; `counter-trace.lua`; `counter-proof.log`; `wet-control.log`; `source.json`.

Further evidence: `tests/artifacts/landfill-overwrite-20261025/`, including
`natural-trace`, frozen `replay-plan.json`, `replay-baseline`, `replay-fixed`,
and the three `editor-*` trials. `TEST_SAVE_2` and a native pre-drain checkpoint
are retained there too. Its exported checkpoint has no player until client
initialization; failed inventory replay pilots are harness failures, not game
regression results. The successful before/after replay uses the earlier
autosave, which retains its player.

`tests/artifacts/landfill-fix-20261025/` retains the exact candidate, mock logs,
baseline source export and performance samples. Exact-ZIP native artifacts are
`20261025-162109-a5d88e` (base) and `20261025-162304-b5e540` (combined partners).

The broader mock timing sweep completed 54 cases without overwritten landfill;
18 other cases stopped in family iteration. The mock's deterministic `pairs`
captures keys then can yield a removed key with a nil value, so this stress
failure needs iterator-fidelity investigation before treating it as a native
family bug. No production family change is included here.

## Follow-up: visible editor trial using inventory brushes and tick buttons

Reproduced the warning in the actual Factorio 2.1.23 GUI from the clean
`TEST_SAVE_2` player checkpoint. Time was advanced through the editor clock
panel's bounded tick controls; terrain changes were real mouse placement of
inventory landfill, not terrain painting, waterfill or mining. Runtime source
was released 2.1.0 with private observation wrappers, without the ownership fix.

- Tick 8453: a 2x2 brush covered four dry deepwater tiles during active drain.
  The next 60-tick step processed it correctly, without scans, splits or merges.
- At full depletion, a six-tile-wide open bend was gradually built from 2x2
  brushes, with 60-tick processing steps between groups. Counts still matched;
  no scans, splits or merges had run.
- Tick 8693: the last two brushes closed a six-by-six perimeter around four dry
  tiles. Before processing, body 1 had 1814 actual and recorded dry tiles, one
  wet tile, and eight queued changes. The earlier covers were fully accounted.
- Tick 8700: deferred placement processing detected a potential split. It
  created temporary scanning bodies, including seeds around pumps. At this
  point the dry counters still matched their grids.
- Tick 8701: following an internal merge, a completed `ScanWaterArea` call
  returned with 28 actual dry members versus 25 recorded. Later merges expanded
  the discrepancy to 129. No terrain reconnection was performed by the player.
- After a further bounded 400-tick step, the GUI announced scan completion and
  repeatedly printed `ToDryTiles is 129 (expected 0)`. The large successor had
  1803 actual dry members versus 1674 recorded near scan completion. The other
  successor is the four-tile enclosed bed. Total final area is consistent with
  36 covered tiles: 1843 - 36 = 1803 + 4.
- No covered landfill disappeared in this manual trial. The small uncovered
  island can naturally show regenerated water; it was never landfilled. This
  trial reproduces the counter defect, not the separate overwrite race.

This establishes that ordinary dry-bed brushing can enter split/merge scanning
without mining or waterfill. A dry enclosure may be visually unobvious. It does
not demonstrate fresh corruption in a path with genuinely no scan/merge work.

An additional 12 native engine replays from the same clean player checkpoint
tested spaced pokes, spirals, targeted dry tiles and cuts, starting at 50%, 6%
and 0.1% reserve. The three spaced-poke cases had no scan/merge activity and no
counter mismatch; the other nine developed mismatches. None lost landfill.
These are diagnostic trials, not passing acceptance tests or proof of a fix.

Evidence and replayable damaged checkpoint are retained under
`tests/artifacts/active-drain-20261025/manual-editor-trial/` (`summary.json`, both
JSONL logs and `water-manual-dry-bed-repro.zip`). The 12 replay results are in
the parent directory's `results.json`. No production fix or save repair was
applied as part of this follow-up.

## Exact scripted replay and cause confirmation

The retained engine reproduction is now in
[`repros/dry-bed-loop/`](repros/dry-bed-loop/README.md), driven by
`python tests/integration/run_dry_bed_repro.py`. It calls native
`player.build_from_cursor` for all nine GUI brushes, including groups placed
at the same paused tick. It validates each native event's positions/old types
and the recorded queue/periodic/area/wet/dry state before every brush. All six
final matrix runs matched those states with zero differences. This removes the
need for another computer-use trial to exercise this particular invariant.

The source audit confirms the GUI used released ZIP SHA-256
`0e37cede3902ce6c21111f1be4b1f3e42da931e74363f0d8df33dfdd91edf5be`.
All 21 packaged Lua files other than `control.lua` matched byte for byte;
`control.lua` only appended the observation probe. The engine launch log names
the isolated `--mod-directory` and `--config`. The Steam installation and
personal mod directory were not patched. Released 2.1.0 already includes its
earlier pre-release features/visual guard, but not post-report ownership fix
`e442a0e`.

| Staged runtime | Closed enclosure | Open enclosure control |
| --- | --- | --- |
| Released 2.1.0 | Fails: 1803 actual dry members, 1674 recorded; gap 129 | Passes; gap 0 |
| Intermediate source e442a0e, ownership fix only | Same failure and counts | Passes; gap 0 |
| Current source plus isolated counter experiment | Passes; 1801 actual/recorded dry members, two wet members, gap 0 | Passes; gap 0 |

All runs settled their scans/events, emitted the exact scheduled brush payloads
and retained every covered landfill tile. The final reserve/appearance need not
match between the counter experiment and broken code: correcting intermediate
area accounting changes merge choices and subsequent depletion/regeneration.
The invariant is matching physical-grid membership and recorded dry counts,
not identical body IDs or a frozen appearance. This is a counter diagnosis,
not validation of every related area/geometry/family invariant.

Detailed trace establishes the mechanism at engine tick 8701:

1. Body 5 has visited 10 dry tiles, but its active scan has only committed seven
   to `DriedTiles`; three increments are still local to the scan function.
2. It merges into body 6, which has seven actual and recorded dry tiles.
3. The merged grids contain 17 tiles; the merged stored count is only 14.
4. The caller switches bodies and reloads the stored count, losing those three
   uncommitted increments. On scan return the body has 28 actual dry members
   but only 25 recorded. Subsequent scan/merge batching grows the gap to 129.

The isolated experiment commits local area/dry counters before merge-capable
processing and reloads them afterwards, including when the current ID survives.
It removes the discrepancy in the same native replay. This confirms the
already identified open scan/merge accumulator defect; the enclosure is a new
small native trigger/evidence, not evidence of a third independent defect.
At that diagnostic stage no production counter fix, damaged-save repair or
performance change had been made. The final release verification below supersedes
that status.

The split/merge sequence itself is expected: dry beds remain lake members;
closing a landfill perimeter isolates a four-tile dry component. Reconstruction
starts scans from nearby components and from pump inputs. Several seeds still
belong to the same outer component and merge as their scans meet. These merges
do not require a player to mine landfill, place waterfill or reconnect terrain.

### What earlier tests did and did not prove

- The release-era mock reclamation tests checked tile membership removal,
  capacity/reserve conservation, wet/dry identities, reopening necks, queued
  visual work and reload. They did not assert dry-grid count equality through
  this multi-seed scan/merge interleaving. The main neck test uses 40% depletion,
  where the relevant dry increments are absent.
- The native `landfill`/`persist` profiles exercise robot cover/removal and tile
  underlays; `resume` exercises a large queued brush, real drain and restart.
  They do not construct this small dry enclosure or inspect actual dry-grid
  membership against `DriedTiles` throughout successor reconstruction.
- The post-report mock reproduction retained in `ea594bd`
  (`tests/repros/landfill_dry_counter.lua`) already exposes the same count-loss
  mechanism with a gradual dry cut. It intentionally remains outside the
  passing suite. The GUI/native loop adds engine confirmation and a different
  triggering geometry, rather than discovering a new root cause.
- Ownership regression `tests/test_landfill_scan_ownership.lua` covers the
  separate pending-landfill owner/grid-removal race. Passing it cannot prove
  correct scan-local counters. The matrix now explicitly demonstrates this.

Machine-readable final results and source audit:
[`results/2026-10-25-dry-bed-loop.json`](results/2026-10-25-dry-bed-loop.json).
Full final logs/staged variants: `tests/artifacts/exact-dry-bed-4d731073/`.
Earlier `89c3acce` and `e86983d2` replay pilots respectively missed grouped
same-tick actions and had a one-tick placement offset; they are harness/timing
pilots, not the exact replay evidence used in the table above.

The final `--variants current --cases closed --require-clean` invocation was
also run: exit code 1, valid matched replay, settled scans, no lost landfill,
and the expected 129-tile shortfall. Its report is retained separately under
`tests/artifacts/exact-dry-bed-af559224/`. This confirms the reproduction can
serve as an actual failing engine regression, rather than merely a log viewer.

## Final resolution

Both release branches now flush/reload scan batches only at real merges, apply
negative geometry-removal deltas, and rebuild affected saved derived counts once.
The exact native replay now passes both closed/open cases with no lost landfill
or persistent counter gap. Loading the actually damaged GUI checkpoint through
2.1.0 → 2.1.1 repairs the 129-tile gap before the first simulation tick and retains
exactly the same water reserve. The distributable `scan_merge` trial passes in
both actual engine families. See [final verification](BUGFIX-2.0.5-2.1.1.md)
and [performance review](../performance/COUNTER-FIX-2026-10-25.md).

The historical negative controls above remain useful evidence. Already physically
overwritten landfill is not reconstructed by the derived-counter repair. Editor
instant deconstruction remains outside supported event routes.
