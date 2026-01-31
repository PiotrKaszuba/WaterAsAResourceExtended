# Water As A Resource Extended

**Turns water into a finite resource in Factorio 2.0+**

Offshore pumps now deplete the waterbodies they draw from. Waterbodies visually shrink as they're consumed, and water slowly regenerate over time. Research technologies to reduce water consumption, use waterfill to extend water sources, and manage your water supply strategically.

---

> ⚠️ **Beta Release Notice**
> 
> This mod is currently in beta. You may encounter debug messages, unexpected behavior, or errors during gameplay.
> 
> **Contributions welcome!** Help improve this mod by:
> - Reporting bugs or error messages on the [Mod Portal](https://mods.factorio.com/mod/WaterAsAResourceExtended) discussion page
> - Opening issues on [GitHub](https://github.com/PiotrKaszworowski/WaterAsAResourceExtended)
> - Submitting pull requests with bug fixes, code improvements, or new features
> - Suggesting design changes, functionality additions/removals, or graphics/content enhancements

---

## Core Mechanics

### Finite Water System
- **Waterbody Tracking**: Connected water tiles form "waterbodies" with unique IDs, scanned asynchronously when pumps are placed
- **Per-Pump Usage**: Each pump's actual fluid extraction is tracked individually using Factorio 2.0's `pumped_last_tick` API
- **Water Tile Capacity**: 
  - Shallow water: 50L per tile (configurable)
  - Deep water: 150L per tile (configurable)

### Visual Depletion
- Water tiles "dry out" as the waterbody depletes (starting at 80% used, configurable)
- Depletion spreads from the edges toward the waterbody's center (centroid)
- "Furthest First" mode ensures tiles farthest from the center dry first (enabled by default)
- Custom tile types are used for depleted areas to avoid conflicts with other mods.

### Regeneration
- Waterbodies slowly regenerate water over time
- Non-linear scaling for strategic resource management:
  - Best regeneration at 75% depleted (150% of base rate)
  - Reduced regeneration at 0% depleted (75% rate) and 100% depleted (50% rate)
- Configurable base regeneration rate

### Pump Behavior
- Pumps automatically deactivate when their waterbody reaches 100% depletion
- Pumps reactivate when water returns above threshold (default: 99% remaining)
- Water usage is multiplied by the force's technology bonus

## Technology Tree

### Yield Boost Research
Reduce water consumption through research. Each level reduces water consumption of offshore pumps by 15% (multiplicative).

| Tier | Effect | Science Packs | Cost |
|------|--------|---------------|------|
| 1 | 85% usage | Automation | 100 |
| 2 | 72.25% usage | + Logistic | 200 |
| 3 | 61.4% usage | + Logistic | 300 |
| 4 | 52.2% usage | + Chemical | 400 |
| 5 | 44.4% usage | + Utility | 500 |
| 6+ | -15% each | + Space | 1k, 2k, ... |

### Waterfill Technology
- **Prerequisites**: Landfill, Explosives
- **Recipe**: 1 Explosives + 500 Water = 3 Waterfill
- Places shallow water adjacent to existing water tiles
- Cannot be placed on dried (depleted) tiles

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

- **Update Budget System**: Configurable operations per second (default: 2000) prevents lag spikes
- **Async Scanning**: Initial waterbody scans spread over time (configurable tiles/second)
- **Lazy Data Migration**: Large data operations spread across multiple game ticks

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
