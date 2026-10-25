# Native Factorio 2.1 acceptance

Small, deterministic trials of engine behavior that the mock suite cannot prove.
The mock suite (`lua tests/run.lua`) and larger performance workloads remain
independently runnable. This suite does not import or replace their mock world.
The [2.0 acceptance record](RESULTS.md) is historical evidence for `v2.0.4`;
2.1 results are recorded separately in [RESULTS-2.1.md](RESULTS-2.1.md).

## Run

Requires Python 3.11+ and an actual Factorio **2.1.23** installation. No Python
packages or RCON client are required. The runner rejects a non-2.1 binary.
Set `FACTORIO_BIN`, pass `--factorio-bin`, or use the installed Windows Steam path
when it already contains 2.1. The runner never switches Steam branches.

From the repository root, PowerShell builds and tests the candidate ZIP:

```powershell
./scripts/test-integration.ps1
```

To test an existing exact artifact, without rebuilding it:

```text
python tests/integration/run.py --mod-zip releases/WaterAsAResourceExtended_2.1.1.zip
python tests/integration/run.py --mod-zip PATH_TO_ZIP --scenario landfill
python tests/integration/run.py --mod-zip PATH_TO_ZIP --scenario resume --timeout 120
python tests/integration/run.py --mod-zip PATH_TO_ZIP --scenario upgrade
python tests/integration/run.py --mod-zip PATH_TO_ZIP --partner-mod ../aai-industry_0.7.5.zip
```

Use the ZIP's actual version in the path. A local manifest override is preserved;
testing a differently versioned archive does not certify the intended final artifact.
Rebuild and rerun after finalizing release metadata or changing production code.

## Nine base-game profiles and actual partners

| Profile | Native behavior checked |
| --- | --- |
| `prototypes` | Exact ZIP loads; default waterfill technology, recipe, item and placer exist; all six dry identities load; recipe costs 1,200 water for three tiles; finite research defaults. Productivity prohibition is checked in the engine's data stage. |
| `prototypes-disabled` | Separate fresh startup profile without all four waterfill prototypes, retaining dry terrain and research defaults. |
| `pumping` | Three separate 64-tile lakes finish ordinary scans. Native pumps fill connected output pipes and stop consuming reserves when blocked. Burner/electric fixtures need fuel/power; a real electric outage stops extraction. All three lakes deplete, pumps deactivate, size-mask settings suppress regeneration, and real setting changes refresh existing lakes and reactivate pumps. Reserve debit agrees with native extraction samples. |
| `landfill` | Real construction robots build landfill over tracked mixed-capacity terrain and an orphan dry bed. Native hidden layers preserve terrain identity. Pavement removal reveals landfill without restoring capacity. Robots mine the landfill, return its items, restore capacity with zero added reserve, and reveal the orphan's exact dry identity. The built-in scripted waterfill placer then adds 100 capacity and 100 reserve. |
| `resume` | Three native pumps drain a 512-tile lake until physical drying is active. A 128-tile announced script brush creates a real budgeted backlog. A localhost server explicitly saves that state, exits, and a new process reloads it. Queue/index persistence, protected physical landfill throughout settlement, final capacity, no reserve creation and an empty pending index are checked. |
| `pump-transitions` | A real wired circuit, deconstruction/cancellation, a bounded noncompeting script stop, output blocking and restart. A per-tick trace compares lake debit with actual fluid removed plus receiver-buffer changes, independently of Water's sampling predicate. |
| `upgrade` | Opens the retained genuine 2.0.77 / Water 2.0.4 checkpoint, verifies the actual configuration-change versions and pre-tick queue/capacity state, settles the original brush, saves the converted world and reloads it in another 2.1 process. |
| `persist` | Extends the wet/dry landfill/robot trial with nondefault regeneration settings and threshold, native research completion, a depleted lake with its stopped pump, a covered typed dry bed, actual save/restart and robot mining after reload. This state is created in 2.1, not represented as a second 2.0 upgrade fixture. |
| `scan_merge` | Seven native pumps fully deplete a 48×32 lake. A 32-tile announced dry enclosure triggers successor scans/merges; dry membership/count, discovered area, geometry count/sums and landfill retention are checked throughout, including normal tiny-pond cleanup. |

With explicit `--partner-mod` ZIPs, the default selection is `partners` plus
`landfill`. Repeat the option for all required dependencies. The runner stages
those archives unchanged, enables only the supplied mods and records their
versions/hashes. `partners` uses actual AAI/Enhanced Offshore Pumps entities when
installed, exercises energy/fuel, depletion/regeneration, the Water technology
prerequisites and unlock, and crafts the migrated recipe in a native assembler.
Alien Biomes profiles also exercise the existing robot landfill/mining trial.
The ordinary full base suite does not require external mods.

The 512-tile trial is a queue/persistence acceptance case, not a performance
benchmark. Larger scaling coverage remains in `tests/performance/`.
Geometry is fixed and bounded. Native robots run normally; their timing has a
generous per-phase limit, rather than an assertion about an exact delivery tick.
The script brush uses the engine's standard `script_raised_set_tiles` payload,
without fabricating an `old_tile` field or invoking Water handlers directly.

## Isolation and evidence

- Every run and profile gets unique directories under `tests/artifacts/` (ignored
  by Git), with separate config, base-only mod list, settings and disposable saves.
  The candidate ZIP is frozen once per run and copied unchanged to each profile.
  Your normal mod directory, configuration
  and saves are not used. Startup variants change defaults in a companion mod.
- `report.json` records engine/mod versions, candidate SHA-256, source commit and
  source dirty status, and all completed checks. Individual phase JSON, full
  engine logs, staged companion sources and the native checkpoint ZIP are retained.
  Phase results include actual snapshots and observed robot mining payloads.
- The resume server binds only localhost with public/LAN visibility disabled.
  Lua scripts drive the scenario and call the actual save API. Python polls the
  result and waits for a valid checkpoint ZIP before stopping its own process.
  It then starts a new process from that save. No RCON or player-order service is used.
- `modules/acceptance.lua` is registered only when `WaterAcceptanceHarness` is
  installed. It returns detached numeric/string snapshots and can set Water's own
  real runtime settings through the engine API. It exposes no reserve setter,
  mutable production table, forced scan or update-loop invocation. Ordinary games
  get no interface or additional per-tick test hooks.
- Controlled burner/electric prototype fixtures test generic energy-source handling.
  They are distinct from the explicit actual-partner profiles described above.

## Boundaries

The user-reported dry-bed enclosure defect now also has a separate [native
inventory replay](repros/dry-bed-loop/README.md). Released 2.1.0 is a negative control; current source passes with
`--require-clean`. This local personal-world fixture remains separate from
the distributable acceptance profiles. Its
exact user checkpoint stays in local artifacts; the schedule, observer and
runner are tracked. It supplements the earlier mock reproduction and checks
the dry-count invariant throughout native scan/merge work.

This suite complements the mock accounting/split/merge/family tests. It does not
repeat their topology matrix, certify all native interleavings, test rendering/UI
or native player cursor actions. `upgrade` converts the retained synthetic old
save; it does not certify an arbitrary personal save or every old settings
combination. The old save is checksum-verified and bundled under
`fixtures/2.0.4/`, with provenance and historical results. Only disposable copies
are loaded. The local default binary need only be 2.1; a second 2.0 install is not
required. Space Age and performance redesign remain out of scope.

Tests use a real engine and supported script actions. In particular, mining
events identify the removed tile; the visible resulting tile is read from the
surface. The sample logs observe the surface after Water's registered handler
has run, not an extra "revealed tile" field invented in the event payload.

The Python isolation/process approach was adapted from the local
PoweredBeltsExtended harness. Mod-specific scenarios remain here; no shared
framework repository or dependency was introduced.

## Bugfix release verification

See [2.0.5 / 2.1.1 verification](BUGFIX-2.0.5-2.1.1.md) for exact artifact
hashes, completed native profiles, saved-state recovery and performance results.
The Linux headless runner uses benchmark execution for non-server trials and
explicitly disables bundled expansion mods. `resume` still uses actual server
save/restart. The Windows runner retains its normal launch route.
