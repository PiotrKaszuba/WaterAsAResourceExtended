# Native acceptance result: 25 October 2026

**Passed: five profiles, 88 checks, Factorio 2.0.77, base only.**

| Profile | Checks | Completion tick |
| --- | ---: | ---: |
| Waterfill enabled / prototypes | 13 | 0 |
| Waterfill disabled / prototypes | 11 | 0 |
| Native pumps, blockage, outage, depletion, settings and recovery | 25 | 8431 |
| Robot wet/dry landfill, pavement, mining and built-in waterfill | 28 | 1952 |
| Native queued-brush save/restart | 11 | 1693 |

Run using `./scripts/test-integration.ps1`, which built and tested the unchanged
candidate ZIP. Tested implementation: `0a2382e`, including the separate fixes
`9556a6a` and `4d766c3`. The repository's pre-existing local manifest override
was retained: tested mod version **2.0.0**, committed manifest **2.0.3**, planned
release **2.0.4**. The report correctly marks the source tree dirty. No publication,
tag, Steam branch change, user-save conversion or partner-mod update occurred.

Candidate SHA-256:

```text
ad23aa8e34c8d02d3927457adb63bd1bf534a3c7034d3fd64e6a3485688f8964
```

Retained raw evidence (ignored, regeneratable):
`tests/artifacts/20261025-024208-f785c3/report.json`, per-profile phase JSON/logs,
staged test sources and the actual saved-game checkpoint. The
[coverage/run instructions](README.md) explain each profile and its limits.

## Concrete observations

- The robot trial's original mixed lake capacity was 14,600. After covering and
  mining, remaining reserve was **10,194.520547945205 both before and after mining**.
  Capacity returned, with exactly zero new reserve. An orphan dry bed was eligible
  for native robot landfill placement and returned as `lake-dry-water-green`.
- Native mining samples identify `concrete` or `landfill` as the removed tile.
  Surface reads after Water's handler observed landfill beneath pavement, typed
  normal/deep dry beds beneath landfill, and the exact green orphan identity.
  There is no invented "uncovered tile" event field.
- The resume checkpoint contained **128 queued edits and 128 pending counts**,
  with 94 already dried lake tiles and more visual work pending. A new process
  loaded that actual native save. All 128 landfill positions survived subsequent
  visual work, queue/index counts reached zero, and capacity became **76,800**
  for the expected 384 surviving lake tiles. Reserve did not increase.
- Actual engine pumping, native output blockage, burner fuel availability,
  electric supply loss, depletion/reactivation and real runtime-setting cache
  refresh all passed. Burner/electric entities are controlled prototype fixtures;
  the external Enhanced Offshore Pumps and AAI ZIPs were not tested here.

## Defects exposed and fixed separately

- `9556a6a`: PowerShell packages lacked the top-level mod directory required by
  Factorio. The native ZIP bootstrap failed before this correction. The runner
  copies the exact archive and does not silently repair its layout.
- `4d766c3`: standard announced script tile changes omit the old tile. Water
  queued script landfill but skipped capacity reduction without its capacity
  class. A small existing-metadata fallback fixes that route; a five-check mock
  regression covers correct reduction and repeated notifications. Ordinary
  player/robot events supply old terrain and did not need that fallback. This
  was not caused by save/reload and does not provide silent-edit CanalBuilder support.

The complete mock suite also passed: **33 files, 938 passed assertions, zero
failures**. Both separate pending-visual diagnostics passed. Larger performance
workloads were retained unchanged and were not rerun for this harness-only work.

## Remaining release work

Finalize manifest/changelog metadata, rebuild the intended release ZIP and rerun
the same command against that final artifact. Native player cursor/UI behavior,
external pump-mod combinations and previous-published-save upgrades are outside
this deliberately focused suite; the restart trial uses a candidate-generated
save. Assess those remaining checks according to release risk rather than treating
the 88 checks as universal engine certification. The 2.1 API migration remains a
separate release after 2.0.
