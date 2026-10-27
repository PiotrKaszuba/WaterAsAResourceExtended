# Native dry-bed enclosure regression

This is a retained native regression with a released-runtime negative control,
separate from the distributable mock and acceptance suites. Current 2.1.1 passes. It replays the actual GUI inventory brush positions,
old tile identities and ticks from the 2026-10-25 `TEST_SAVE_2` trial. The clean
checkpoint and matching support mods remain local under ignored artifacts; the
personal scenario and partner mods are not committed or downloaded by the runner.

From the repository root:

```text
python tests/integration/run_dry_bed_repro.py
python tests/integration/run_dry_bed_repro.py --variants released current
python tests/integration/run_dry_bed_repro.py --variants current --require-clean
```

The defaults locate the locally retained checkpoint, support mods and released
ZIP. These paths can be supplied explicitly; `--help` lists the options. The
checkpoint SHA-256 and engine 2.1.23 are checked before running. Each invocation
creates unique staged mods, configs, logs, an initial-save copy and `report.json`
under `tests/artifacts/exact-dry-bed-*`. Nothing is installed in the Steam or
personal mod directories. The GUI trial can remain open while these engine
benchmark processes run independently.

`closed` replays nine native 2x2 inventory brushes, covering 36 distinct tiles.
`open` omits the final closing brush, covering 32. Pumps drain normally; no test
reserve setters, terrain painting, fake built events, forced scans or mining are
used. The first brush is on dry terrain during active depletion, and later
brushes form a small dry enclosure. Several brushes share one paused GUI tick
and are replayed as a group. Water's tile accounting remains deferred normally.

Every emitted native brush payload must match the recording. Queue size, periodic
tick, area, dry membership/count and wet membership before all actions must match
the GUI snapshots. A mismatch is a harness error, not a successful reproduction.
After each tick, the companion checks dry-grid membership against `DriedTiles`
and watches all covered positions for lost landfill. It also requires scans and
tile accounting to finish before the final invariant result.

Diagnostic mode exits zero when all trials execute validly; inspect each
`invariant_passed` field. `--require-clean` additionally exits nonzero on a failed
invariant, making released 2.1.0 a failing regression and current source a passing gate.
The distributable synthetic `scan_merge` acceptance profile complements this
private-world replay in both engine families.

The observer records merge participants/survivors and snapshots after scans.
Temporary differences *inside* a scan can be legitimate local batching. A
difference surviving the scan return and persisting after all scans finish is
the defect. No extra computer-use trial is needed to rerun these invariants.

For actual damaged-save recovery, without any terrain action:

```text
python tests/integration/run_dry_bed_repro.py --recovery --variants current --require-clean
```

This uses a separate checksum-verified damaged GUI checkpoint and a companion
version change to force a real configuration event. The result records the
actual Water version transition, pre-tick count/reserve and post-update state.
The released baseline retains its 129-tile gap; 2.1.1 repairs it before ticking,
without adding reserve. Historical counter-proof mutation results remain in
Git at `b445cd3`; the maintained runner no longer rewrites that code.

Release evidence: [release verification](../../../VERIFICATION.md).
