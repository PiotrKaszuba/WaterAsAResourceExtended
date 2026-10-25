# Native Factorio 2.0 acceptance

Small, deterministic trials of engine behavior that the mock suite cannot prove.
The mock suite (`lua tests/run.lua`) and larger performance workloads remain
independently runnable. This suite does not import or replace their mock world.

## Run

Requires Python 3.11+ and an actual Factorio **2.0.77** installation. No Python
packages or RCON client are required. The runner rejects a 2.1 binary.
Set `FACTORIO_BIN`, pass `--factorio-bin`, or use the installed Windows Steam path
when it already contains 2.0. The runner never switches Steam branches.

From the repository root, PowerShell builds and tests the candidate ZIP:

```powershell
./scripts/test-integration.ps1
```

To test an existing exact artifact, without rebuilding it:

```text
python tests/integration/run.py --mod-zip releases/WaterAsAResourceExtended_2.0.4.zip
python tests/integration/run.py --mod-zip PATH_TO_ZIP --scenario landfill
python tests/integration/run.py --mod-zip PATH_TO_ZIP --scenario resume --timeout 120
```

Use the ZIP's actual version in the path. A local manifest override is preserved;
testing an archive named 2.0.0 does not prepare or certify a final 2.0.4 artifact.
Rebuild and rerun after finalizing release metadata or changing production code.

## Five profiles

| Profile | Native behavior checked |
| --- | --- |
| `prototypes` | Exact ZIP loads; default waterfill technology, recipe, item and placer exist; all six dry identities load; recipe costs 1,200 water for three tiles; finite research defaults. Productivity prohibition is checked in the engine's data stage. |
| `prototypes-disabled` | Separate fresh startup profile without all four waterfill prototypes, retaining dry terrain and research defaults. |
| `pumping` | Three separate 64-tile lakes finish ordinary scans. Native pumps fill connected output pipes and stop consuming reserves when blocked. Burner/electric fixtures need fuel/power; a real electric outage stops extraction. All three lakes deplete, pumps deactivate, size-mask settings suppress regeneration, and real setting changes refresh existing lakes and reactivate pumps. Reserve debit agrees with native extraction samples. |
| `landfill` | Real construction robots build landfill over tracked mixed-capacity terrain and an orphan dry bed. Native hidden layers preserve terrain identity. Pavement removal reveals landfill without restoring capacity. Robots mine the landfill, return its items, restore capacity with zero added reserve, and reveal the orphan's exact dry identity. The built-in scripted waterfill placer then adds 100 capacity and 100 reserve. |
| `resume` | Three native pumps drain a 512-tile lake until physical drying is active. A 128-tile announced script brush creates a real budgeted backlog. A localhost server explicitly saves that state, exits, and a new process reloads it. Queue/index persistence, protected physical landfill throughout settlement, final capacity, no reserve creation and an empty pending index are checked. |

The 512-tile trial is a queue/persistence acceptance case, not a performance
benchmark. Larger scaling coverage remains in `tests/performance/`.
Geometry is fixed and bounded. Native robots run normally; their timing has a
generous per-phase limit, rather than an assertion about an exact delivery tick.
The script brush uses the engine's standard `script_raised_set_tiles` payload,
without fabricating an `old_tile` field or invoking Water handlers directly.

## Isolation and evidence

- Every run and profile gets unique directories under `tests/artifacts/` (ignored
  by Git), with separate config, base-only mod list, settings and disposable saves.
  The candidate ZIP is copied unchanged. Your normal mod directory, configuration
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
  They are not the published Enhanced Offshore Pumps ZIP or an AAI integration test.

## Boundaries

This suite complements the mock accounting/split/merge/family tests. It does not
repeat their topology matrix, certify all native interleavings, test rendering/UI
or native player cursor actions, or upgrade a previous published/user save. The
restart test uses an actual newly generated candidate save with pending work.
Partner-mod profiles and previous-release save fixtures can be added separately
when they address a concrete risk. Space Age and performance redesign remain out
of scope.

Tests use a real engine and supported script actions. In particular, mining
events identify the removed tile; the visible resulting tile is read from the
surface. The sample logs observe the surface after Water's registered handler
has run, not an extra "revealed tile" field invented in the event payload.

The Python isolation/process approach was adapted from the local
PoweredBeltsExtended harness. Mod-specific scenarios remain here; no shared
framework repository or dependency was introduced.
