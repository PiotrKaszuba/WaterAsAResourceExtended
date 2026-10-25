# Factorio 2.1 acceptance — Water 2.1.0

Historical evidence retained from the original 2.1 lineage (archived at `eb88e9c`).
Its dated results and commit/ZIP hashes are unchanged by the 2026-10-26 rebuild.
Fresh validation is recorded separately.

Completed **25 October 2026**, using Steam Factorio **2.1.23, build 87750**.
The tested release candidate ZIP has **29 files / 279,503 bytes** and SHA-256:

```text
0e37cede3902ce6c21111f1be4b1f3e42da931e74363f0d8df33dfdd91edf5be
```

The packaged runtime/metadata is committed in `ab4f614`. Subsequent `4b32576`
strengthens tests only. No production collection, scanning, splitting, merging,
regeneration or visual scheduling algorithm was changed for this port. The
production API changes are recipe categories and the three inverse script-disable
writes. The extra snapshot fields exist only with the acceptance companion loaded.

This is a validated local release candidate, **not a publication record**. No
2.1 tag, push, Mod Portal upload or community announcement was performed here.
The 2.0 tag remains at `4ef5a4d`.

## Native coverage

All **eight base-only profiles pass: 175 checks**. Counts below use the latest
strengthened `upgrade` and `persist` runs; they supersede the earlier 18-check
upgrade and 43-check persistence versions in the full-suite report.

| Profile | Checks | Main result |
| --- | ---: | --- |
| `prototypes` | 13 | Exact archive loads, all terrain identities exist, defaults and waterfill amounts retained. |
| `prototypes-disabled` | 11 | Waterfill's four prototypes are absent with the switch off. |
| `pumping` | 25 | Native/fixture pumps, blocked output, fuel/power, outage, depletion, mask changes and recovery. |
| `landfill` | 28 | Actual robot covering/mining of wet/dry beds, hidden identity, paving and paid waterfill. |
| `resume` | 11 | 128 queued edits persist across native save/restart while visual work is active. |
| `pump-transitions` | 19 | Wired circuit, deconstruction, bounded script stop, blocked output and independent fluid balance. |
| `upgrade` | 19 | Actual 2.0.4 save conversion, original pending work, exact settled reserve parity and a second 2.1 reload. |
| `persist` | 49 | Nondefault settings, native research completion, mixed/fully depleted lakes, stopped pump and hidden dry terrain survive reload; robot mining afterward adds no water. |

Actual partner profiles also pass: **six profiles / 115 checks**.

| Supplied mods | Profiles / checks | Verified behavior |
| --- | --- | --- |
| AAI Industry 0.7.5 | `partners`: 12 | Actual electric offshore pump, energy requirement, finite depletion/recovery and Water recipe/research access. |
| Enhanced Offshore Pumps (`offshore-burner`) 1.0.3 | `partners`: 16 | Actual burner/electric prototypes, initial fuel/power requirements, extraction, finite depletion and reactivation. |
| Alien Biomes 0.8.0 + graphics 0.8.0 | `partners`: 11; `landfill`: 28 | Actual final terrain definitions load; finite-water cycle, robot wet/dry covering/mining and waterfill work. |
| All four above | `partners`: 20; `landfill`: 28 | Combined prototype load, actual three pump variants, native recipe crafting and terrain lifecycle. |

Every partner profile crafts **three waterfill items from 1,200 water and one
explosive** in a real assembling machine after the technology unlock. Supplied
ZIPs are staged unchanged and their versions/hashes are recorded. This is
evidence for these versions, not a claim that every future release is compatible.

Independent mocks: **33 files / 944 passed assertion lines / zero failed**.
Both separate pending-landfill/mining visual-race diagnostics pass. These suites
remain independently runnable; native scenarios do not replace their topology
and accounting matrix.

## Pump sampling findings

The transition trial records **582 ticks**. Its independent balance is:

- Physical extraction, computed from removed fluid and receiver buffer changes:
  **6,160**.
- Lake debit: **6,160**. Difference: **0**.
- A script-stopped pump retains a **20-unit** last sample while actual extraction
  and further debit stop. This confirms why blindly sampling inactive pumps is
  unsafe.
- For this native offshore pump, circuit-disabled extraction reads zero while
  `active` stays true and `disabled_by_control_behavior` false. Field names alone
  must not be used as an independent flow oracle.
- Circuit/deconstruction stops remain effective when Water releases its own
  script stop. Deconstruction cancellation and output reopening resume flow.

The existing collection predicate passes these trials. **No speculative sampling
rewrite or ownership ledger was added.** The short external script stop is placed
between Water's regular activation updates. Competing scripts repeatedly claiming
the same flag are intentionally outside the ownership policy; an exploratory
trial of that conflict briefly reactivated flow and is not a supported stop mode.
Prolonged stops caused by Water's own depletion are separately exercised.

## Genuine save conversion and persistence

The bundled [old-engine fixture](fixtures/2.0.4/README.md) was generated by actual
Factorio **2.0.77 / Water 2.0.4**. Its checksum is verified before an isolated
copy is opened. No second engine installation or Steam branch switch was needed.

The actual configuration-change event reports Water 2.0.4 → 2.1.0. Before normal
ticks resume, capacity **102,400**, area **512**, and **128 queued / 128 pending**
edits are retained. Work settles to area **384**, capacity **76,800**, no pending
entries and reserve **11,213.493975902995** — matching the original 2.0 continuation
within 0.01 units. Physical landfill survives every observed visual update.
The converted save is then saved and loaded by another 2.1 process, retaining
that state. No lake reset, global lake rescan or explicit state migration was needed.

The separate 2.1-created persistence trial saves regeneration factor **317**,
mask **0000000**, reactivation threshold **975** and completed native yield
research with multiplier **0.85**. It retains both a mixed lake and a fully
depleted lake whose pump is script-stopped, plus an orphan green dry bed beneath
landfill. After reload the settings/accounting/stop/hidden identity remain and
native robots uncover the exact dry bed without adding reserve.

These additional states were created in 2.1; they are not presented as extra
2.0 conversion fixtures. An arbitrary personal save and a second old-engine
fixture containing every nondefault setting/fully depleted pump were not tested.

## Evidence and repeatability

[Machine-readable summary](results/2026-10-25-2.1.0.json) retains versions,
partner archive hashes, counts, pump phase endpoints and upgrade preflight state.
Full engine logs, traces, staged companion sources and disposable saves are in
these ignored `tests/artifacts/` runs:

- Base suite: `20261025-062128-56d297`.
- Strengthened upgrade: `20261025-062549-9a7e15`.
- Strengthened persistence: `20261025-062746-d1974f`.
- AAI: `20261025-062313-7c4ebe`.
- Modern pumps: `20261025-062329-539da4`.
- Alien Biomes: `20261025-062344-daad16`.
- Combined: `20261025-062433-fb8c77`.

All reports name the same candidate SHA-256 above. The runner freezes a candidate
copy per run, so rebuilding the release path cannot change later profiles. Source
dirty flags include preserved unrelated untracked files, and later trial runs
also occurred while their test-only strengthening was being prepared. Raw staged
test sources are retained; exact packaged bytes were independently matched to
the working source. CRC, mod-root directory, forward-slash paths and exclusion
of tests/README/Windows thumbnail caches were checked.

See [run instructions and profile boundaries](README.md) and the
[focused port performance comparison](../performance/PORT_2_1_REPORT.md).
The original [2.0 acceptance record](RESULTS.md) remains unchanged.

## Remaining boundary

The selected base-game port is ready for release review. Space Age gameplay,
unmapped custom water tiles, moving pumps, CanalBuilder, the split-search
optimization and multi-mod ownership of the script-disable flag remain outside
scope. There is no multiplayer/desync or native UPS certification here. The
complete personal pack still needs its own acceptance, including Powered Belts'
separate migration. Publish Water before changing the pack's required Water floor.
