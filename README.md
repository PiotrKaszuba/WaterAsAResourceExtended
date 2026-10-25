# Water As A Resource Extended

**Turns water into a finite resource in Factorio 2.0+**

| Game version | Mod version to use |
| --- | --- |
| Factorio 2.0 | 2.0.5 |
| Factorio 2.1 | 2.1.1 |

Version 2.1.1 supersedes 2.1.0.

Offshore pumps now deplete the waterbodies they draw from. Waterbodies visually shrink as they're consumed, and water slowly regenerates over time. Research technologies to reduce water consumption, use waterfill to extend water sources, and manage your water supply strategically.

---

> ⚠️ **Beta Release Notice**
> 
> This mod is currently in beta. You may encounter debug messages, unexpected behavior, or errors during gameplay.
> 
> **Contributions welcome!** Help improve this mod by:
> - Reporting bugs or error messages on the [Mod Portal](https://mods.factorio.com/mod/WaterAsAResourceExtended) discussion page
> - Opening issues on [GitHub](https://github.com/PiotrKaszuba/WaterAsAResourceExtended)
> - Submitting pull requests with bug fixes, code improvements, or new features
> - Suggesting design changes, functionality additions/removals, or graphics/content enhancements

---

## Core Mechanics

### Finite Water System
- **Waterbody Tracking**: Connected water tiles form "waterbodies" with unique IDs, scanned asynchronously when pumps are placed
- **Per-Pump Usage**: Each pump depletes its lake according to the water it actually extracts.
- **Water Tile Capacity**: Startup settings default to 200 for normal water and
  2,000 for deep water. Extra-shallow and muddy water hold 50% and 25% of normal water capacity, respectively.

  | Tile | Default capacity | Assumed depth |
  |------|-----------------:|--------------:|
  | Normal water, including green water | 200 | 20 cm |
  | Extra-shallow water, including built-in waterfill | 100 | 10 cm |
  | Muddy water | 50 | 5 cm |
  | Deep water, including green deep water | 2,000 | 2 m |

  The assumed depths treat each tile as 1 m² and each fluid unit as one litre,
  for this mod's capacity calculations.

### Visual Depletion
- Water tiles "dry out" as the waterbody depletes (starting at 80% depletion, configurable)
- Depletion spreads from the edges toward the waterbody's center (centroid)
- Custom tile types are used for depleted areas to avoid conflicts with other mods.

### Landfill and Depleted Beds
- Ordinary landfill can cover wet water tiles and depleted beds. Covered positions
  are removed from the lake's capacity and connectivity; a strip of landfill can split a lake.
- Landfill remains removable. Mining it exposes an **empty bed**, adding capacity
  but no water. Water lost when landfill was placed is not refunded by removing it.
- Mining landfill can merge lakes. Existing water is shared across the
  combined area, so some empty beds may become wet again without creating water.
- Keep landfill beneath buildings you want protected from reflooding. Unfilled
  beds, including beds exposed by mining landfill, can regenerate and flood again.
- Built-in waterfill cannot be placed directly on a depleted bed.

### Regeneration
- Waterbodies slowly regenerate water over time
- Non-linear scaling for strategic resource management:
  - Best regeneration at 75% depleted (150% of base rate)
  - Reduced regeneration at 0% depleted (75% rate) and 100% depleted (50% rate)
- Configurable base regeneration rate
- The **Regeneration enabled by size** setting accepts seven 0/1 digits in this order:
  Puddle, Well, Pond, Lake, Great Lake, Sea, Ocean. Default `1111111` enables all;
  `0000001` enables oceans only and `0000011` enables seas and oceans.
  Invalid strings fall back to `1111111` with a warning. While scanning, the
  currently calculated size applies; it may change as more tiles are discovered.

### Pump Behavior

- **Manage only Nauvis** is a startup setting enabled by default. Disable it to manage supported
  water sources on other surfaces. Non-water fluids remain unmanaged.
- Enabling this restriction stops management of previously tracked off-Nauvis waterbodies and
  releases their pumps. Previously dried terrain remains unchanged.
- Pumps remain non-movable with Picker/Even Pickier Dollies. The blacklist uses
  prototype names, so it can also restrict that pump type on ignored surfaces.

- Burner and electric offshore pumps drawing from supported water tiles are supported,
  including those from Enhanced Offshore Pumps (`offshore-burner`).
- Non-water sources and custom water tiles without a drying/restoration mapping are left unmanaged.
- Ordinary pipeline pumps are not treated as waterbody extractors.
- Pumps automatically deactivate when their waterbody reaches 100% depletion
- Pumps reactivate when water returns above threshold (default: 99% depletion)
- Yield research reduces how much lake water each pump consumes.

## Technology Tree

### Yield Boost Research
Reduce water consumption through research. Each completed level reduces water
removed from lakes by 15% (multiplicative), while pumps output the same fluid.
**Yield research - Maximum level** is a startup setting, default 6, range 1–100.
Levels above the configured limit are unavailable. **Enable infinite yield research**
defaults off; enabling it allows genuine repeated improvements beyond level 6 and
ignores the finite maximum. The existing science requirements and costs are retained.

| Tier | Effect | Science Packs | Cost |
|------|--------|---------------|------|
| 1 | 85% usage | Automation | 100 |
| 2 | 72.25% usage | + Logistic | 200 |
| 3 | 61.4% usage | + Logistic | 300 |
| 4 | 52.2% usage | + Chemical | 400 |
| 5 | 44.4% usage | + Utility | 500 |
| 6 | 37.7% usage; default final level | + Space | 2k |
| 7+ (if enabled) | -15% usage per additional level | + Space | 4k, 8k, ... |

Changing either research setting updates your bonuses when the save loads with
the new settings. Lowering the cap
limits the applied bonus too; it does not refund science. Removed tiers may lose
their saved progress. Research already completed beyond level 6
starts applying its actual bonus if infinite research is enabled.

### Waterfill Technology
- **Prerequisites**: Landfill, Explosives
- **Recipe at default settings**: 1 Explosives + 1,200 Water = 3 Waterfill
- Places extra-shallow water adjacent to existing water tiles (100 water per tile at default capacities)
- Cannot be placed on dried (depleted) tiles

**Waterfill - Relocation efficiency (%)** is a startup setting, default 25%,
with a range of 1–100%. The recipe's water cost is rounded up from the total
capacity its three resulting tiles add, divided by the efficiency. At default
capacities, three waterfill add 300 lake water, including when extending a partly
depleted lake: `ceil(300 / 0.25) = 1,200` water consumed. Recipe productivity is
disabled. Custom capacity settings automatically change the recipe cost.

**Balance warning:** default settings—25% waterfill efficiency and a level-6 research cap—prevent infinite water generation through pumping and waterfill. At level 6, efficiency of 38% or higher can generate water. At level 9 or higher, even the default 25% can generate water.

**Enable Waterfill** is a startup setting in this mod's settings, enabled by default.
Disabling it removes the built-in waterfill technology, recipe, item and placer.
Existing waterfill items can be removed without conversion or refund.

**CanalBuilderMAV is incompatible.** Its terrain changes bypass finite-water
accounting. Disabling built-in waterfill does not make the combination compatible.

## Waterbody Dynamics

### Merging
When waterfill connects two separate waterbodies, they automatically merge into a single tracked body. Water amounts and statistics are combined.

### Splitting
When landfill divides a waterbody, the mod detects this and creates separate tracked bodies for each disconnected region. Water is distributed proportionally.

## Map & Notifications

### Map Markers
- Display waterbody name, remaining water, and percentage remaining
- Shown per force at pump locations
- Can be disabled in settings

### Depletion Alarms
Configurable notifications at various depletion levels:
- **Low level alarms**: 50%, 75%, 90%
- **High level alarms**: 95%, 97%, 98%, 99%

## Performance Features

- **Update Budget System**: Configurable operations per second (default: 2000) helps limit lag spikes.
- **Async Scanning**: Initial waterbody scans spread over time (configurable tiles/second).
- **Lazy Data Migration**: Large data operations spread across multiple game ticks.

The update budget and scanning speed settings control how much work the mod does
over time. Lower values reduce the work per update but make lake scans and terrain
changes take longer to finish.

## Multi-Surface & Multi-Force Support

- Waterbodies are tracked separately per surface
- Each force maintains separate technology progress and water usage multipliers
- Map markers are shown per force


---

## Credits & Copyright

This mod was inspired by "Water As A Resource" by TreefrogGreaken under MIT License, found on the Factorio Mod Portal: https://mods.factorio.com/mod/WaterAsAResource

Water As A Resource noted that:
"This mod was inspired by finitewater by Luke Perkin, found on the Forums: https://forums.factorio.com/viewtopic.php?f=94&t=14506"
which also was published under MIT License.

From "Water As A Resource": updated, refactored, and extended for Factorio >= 2.0 versions by PiotrKaszuba.
Some of the original graphics are still used under the MIT License.

Waterfill icon is borrowed from Waterfill by untraceablesmurf under MIT License, found on Factorio Mod Portal: https://mods.factorio.com/mod/Waterfill_v17 or Github: https://github.com/un-smurf/waterfill.

<!-- PORTAL-DESCRIPTION-END: copy everything above this line to the mod portal. -->

---

## Development

This section is repository documentation and is not part of the mod-portal description.

### Tests and engine acceptance

Run `lua tests/run.lua` from the mod directory. See [test coverage and limitations](tests/README.md).
Run `./scripts/test-integration.ps1` for the separate
[native Factorio 2.1 acceptance suite](tests/integration/README.md), which builds
and tests the actual candidate ZIP in isolated profiles.
The separate mock suite uses a mock Factorio world and exercises event handlers, accounting,
scanning, splits/merges, visual work and queued-state reload together. It does not
certify native collision handling, real robot scheduling or actual saved-game loading.

Native acceptance targets the exact ZIP and includes a retained 2.0.4 save upgrade,
settings/research persistence, robot terrain operations, and explicit actual-partner
profiles. See the [2.1 evidence and boundaries](tests/integration/RESULTS-2.1.md).
Runtime pump registration includes announced script builds/revives and clone destinations;
each pump's actual extraction is read from `pumped_last_tick`.

### Pending terrain-event safeguard

The pending-event visual guard is enabled on development. Per-surface/position
event counts prevent physical drying/reflooding and associated grid transfers
from overtaking queued terrain accounting. Candidate attempts remain bounded by
the existing visual work quota. Regeneration amounts, extraction and ordinary
topology/accounting processing retain their existing behavior.

Two separately runnable diagnostics in `tests/deferred/` reproduce the race on
the pre-guard baseline and pass on current development. Their historical paths
are retained. See [feature scope and verification](tests/PENDING_VISUAL_GUARD.md).
Passing mocks do not certify every native engine interleaving.

### Performance testing

The original scan-performance suite has six configurations. A separate
[performance workload suite](tests/performance/README.md) adds 22 repeatable cases,
including 262,144-tile lakes, 1,024 pumps across 64 lakes, large visual backlogs,
construction bursts and split/reopen settlement. It records phase/cycle CPU times,
scan-slice and tick distributions, queue latency and correctness counters.
Run `lua tests/performance/run.lua 7` separately from the fast correctness suite.
Paired comparisons and a [measured report](tests/performance/PERFORMANCE_REPORT.md)
record the guard's direct cost and its effects on existing terrain processing.
Mock timings do not measure native Factorio API costs or predict game UPS.

Scanning, topology work and visual work use budgeted queues/lazy data structures.
This spreads work across updates, with queue latency as a trade-off. A pending-position
hash lookup does not make split/merge processing constant-time. Guard-versus-eager
comparisons should include quiet operation, dense overlap and construction bursts,
measuring callback peaks and queue drain as well as average throughput.

### Maintained release history

Shared fixes, regression/performance sources and combined release evidence live
on the 2.0.5 maintenance baseline. The rebuilt 2.1 lineage inherits that baseline
and adds only its API adaptation, engine-specific coverage and release guidance.
The original 2.1 history and published `v2.1.0` remain available. See
[history cleanup and provenance](tests/HISTORY-REBUILD-2026-10-26.md).
