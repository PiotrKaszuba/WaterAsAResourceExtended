# Baseline verification

Consolidated 27 October 2026. Results below retain their original tested versions;
this cleanup adds no gameplay changes and does not rerun native acceptance.

## Tested artifacts

| Factorio | Mod / tag | Source baseline | ZIP SHA-256 |
| --- | --- | --- | --- |
| 2.0 | 2.0.5 / `v2.0.5` | `0922002` | `14f80c7eab962fdb9617e9bb22b2126a38fe054d1ede5aedd36163e615583b1a` |
| 2.1 | 2.1.1 / `v2.1.1` | `b445cd3` | `f545f571d93e3f3d2814092a8c3d35797acdf8f01ab50f5f16a640f2410eef06` |

Shared fixes originate once on 2.0.5; 2.1 inherits them and adapts pump
`disabled_by_script` writes and recipe `categories`. Original `v2.1.0` and its
unpublished diagnostic history remain recoverable through the historical tag and
`archive/factorio-2.1-before-2.0.5-rebuild-2026-10-26` (`eb88e9c`).

The rebuilt tree matched all 23 frozen production Lua/prototype/locale blobs,
manifest and 14 measured workload/helper files. The corrected changelog and one
LF/CRLF checkout conversion explain the changed 2.1 ZIP; no algorithm changed.
The full historical reports/raw runs are available in Git at `b445cd3`.

## Accepted evidence

| Baseline | Native engine / date | Profiles / checks across all phases | Mocks |
| --- | --- | --- | --- |
| 2.0.5 exact ZIP | 2.0.77 Linux headless, 25 Oct | 6 / 107 | 37 files / 1030 assertions after explicit upgrade-route additions |
| Rebuilt 2.1.1 exact ZIP | 2.1.23 Windows, 26 Oct; build source `8fa4038` | 9 / 239 | 37 files / 1036 assertions |

2.0's native run preceded the documentation/upgrade-assertion additions; its
packaged artifact stayed unchanged. Native profiles cover startup variants, real
pumping, robot wet/dry landfill/mining, queued save/restart and dry scan/merge.
2.1 adds pump transitions, a genuine old-save upgrade and extended persistence.
See [profile definitions and commands](integration/README.md).

Actual AAI Industry 0.7.5, offshore-burner 1.0.3 and Alien Biomes + graphics 0.8.0
passed six partner profiles / 115 checks on the original 2.1.0 port, 25 October.
This is historical partner evidence, not a fresh full-pack or 2.1.1 partner run.
The pump transition trace balanced 6160 extracted and 6160 debited over 582 ticks.
An inactive pump can retain a stale last sample; keep the validated collection
predicate rather than sampling every inactive pump unconditionally.

## Fixed invariants and upgrade paths

- A scanner must retain pending-landfill ownership until FIFO removal accounting
  removes membership/capacity exactly once; stale visual entries caused overwrites.
- Scan-local dry/area/geometry increments must be flushed before actual merges,
  then reloaded regardless of which body ID survives. Lost increments caused the
  persistent dry-counter warnings. Ordinary per-tile batching remains unchanged.
- Geometry removal must apply negative deltas as well as positive additions.
- Affected-version repair rebuilds derived membership counts/geometry once,
  preserving reserves/debt, terrain, pumps and pending FIFO. It adds no water.

| Upgrade | Coverage |
| --- | --- |
| 2.0.4 → 2.0.5 | Mock: exactly one repair, conserved reserves/FIFO; native 2.0 release acceptance separately |
| 2.0.4 → 2.1.1 | Same mock plus actual retained 2.0 checkpoint conversion and native restart |
| 2.1.0 → 2.1.1 | Same mock plus actual damaged-checkpoint recovery, 25 Oct |
| 2.0.5 → 2.1.1 | Mock explicitly verifies zero repair calls |

The private native GUI replay's closed 36-tile enclosure leaves a 129-tile count
gap on released 2.1.0; fixed code and the open 32-tile control settle cleanly.
Damaged-save recovery corrects 1803/1674 to 1803/1803 before ticking, retaining
reserve -74.48531926469877 and all 36 landfill tiles. Local replay inputs are
retained separately from disposable outputs; the portable `scan_merge` profile
does not need personal saves or support mods.

## Limits and performance

Already-overwritten terrain cannot be reconstructed by counter repair. Event-less
terrain edits/editor instant deconstruction remain unsupported. Native acceptance
is bounded evidence, not proof of every interleaving or full-pack compatibility.
Keep mocks, native acceptance and stress workloads separately runnable.

The [final bugfix performance comparison](performance/COUNTER-FIX-2026-10-25.md)
retains matched samples, workload scales and one-time repair cost. The narrow
[visual guard decision](performance/PERFORMANCE_REPORT.md) explains direct index
cost versus existing expensive topology searches. These are mock CPU timings,
not native UPS estimates. History cleanup reused evidence because production and
measured workload code were identical.
