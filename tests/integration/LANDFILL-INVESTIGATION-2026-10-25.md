# Landfill / depletion report following the 2.1.0 acceptance

Status: landfill scan/queue race fixed and tested on development. No release metadata, published ZIP, tag or remote update. The separate scan/merge counter defect below remains open.

## Confirmed warning and counter defect

- Inspected isolated copies of `THE_TEST_SAVE` (an exported scenario retaining `script.dat`) and the recent autosave. Both reproduce the warning in Factorio 2.1.23 with the user's enabled mods/settings copied into separate directories.
- Initial Mistassini state: area 1,687; dry-grid membership 1,687; `DriedTiles` 1,640; no wet-grid members; no pending terrain events. The dry counter is short by 47. Repeated requests to dry additional tiles cannot succeed when the wet grid is empty.
- The discrepancy survives regeneration. A warning-free interval does not mean the counter repaired itself; regeneration can lower the target until the impossible extra work disappears. Another depletion exposes it again.
- Fresh mock reproduction uses a 48 × 32 lake, three pumps, 98% depletion and a gradual two-tile-wide cut. Production tick handlers perform visual work, queued landfill accounting, potential splits and successor scans/merges. At tick 3,211 one successor has 15 dry members but a counter of 12.
- The affected scan/merge source is identical between `v2.0.4` and `v2.1.0`; this finding is not a change introduced by the 2.1 pump API adaptation. The reproduction itself was run against the current branch, not in a 2.0 engine.
- The identical wet-only control passes this invariant. Its dry increments are zero, so it does not expose this specific loss. Earlier dry-landfill/conservation tests did not assert this invariant throughout the scan/merge interleaving.
- Cause: `ScanWaterArea` batches dry-count/area updates in local variables while `processWaterTile` can merge bodies. A merge reads stored counters before all current local increments have been committed. The caller also refreshes its locals only when the surviving ID changes; a merge retaining the current ID can change the stored counters too.
- A private proof variant flushes batch counters before merge-capable processing and refreshes after every merge, including those retaining the ID. The original longer reproduction then passes. This is evidence for the diagnosis, not an approved production implementation or performance result.

Retained failing regression (outside normal suite discovery):

```text
lua tests/repros/landfill_dry_counter.lua
lua tests/repros/landfill_dry_counter.lua --wet
```

The first must currently fail; the second passes. Do not suppress the warning as the fix. A production change must also address already incorrect saved counters and check the related scan-area accumulator.

## Landfill replacement: reproduced and fixed

Earlier trials finished placing their brushes before restoration started and
did not reproduce the loss. Targeting brushes during natural regeneration did.
The only terrain action was ordinary inventory landfill placement; no waterfill
or mining was used. Regeneration was set to 1,000 to reach the overlap sooner.

Native trace for (-5, -83):

| Tick | Release behavior |
| --- | --- |
| 34,722 | Lake 9 restores the dry bed to deep water. |
| 34,724 | A native 2 × 2 inventory brush places landfill; its accounting event is queued. |
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

Suggested eventual user changelog line: “Fixed landfill being replaced during
depletion or regeneration.”

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

The first three large-scan pairs appeared slower (1.641 → 2.074 s), so only
that workload was repeated. The repeat ranges overlap: baseline 1.834–2.155 s,
fixed 1.809–1.971 s. It does not reproduce the initial material slowdown or
establish an improvement. Both versions settle the scan in 121 ticks and the
mixed workload in 1,260 ticks. Dense queue timing is close to clock granularity.
No new unbounded search is introduced; the hash lookup is only reached for
physical landfill encountered by scanning. Raw samples and method are in
`tests/performance/results/2026-10-25-landfill-fix/`.

## Mining and announcements

- Four owned deep dry tiles near (-25, -80): real inventory placement changes area 1,687 → 1,683 and capacity 176,550 → 175,950; native player mining returns area/capacity to their original values. Reserve does not increase on mining. Both cover and uncover emit the normal lake-updated message with tile messages enabled.
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
