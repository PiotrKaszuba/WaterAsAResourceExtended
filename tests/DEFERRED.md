# Deferred Water ideas

Not release blockers or implementation commitments. Updated 27 October 2026.

| Idea | Motivation / source | Boundary |
| --- | --- | --- |
| Staged deep → normal → shallow transitions | [Issue 27, point 3](https://github.com/PiotrKaszuba/WaterAsAResourceExtended/issues/27) | Requires deliberate identity, capacity, topology and restoration rules; keep current direct wet/dry transitions. |
| Arbitrary custom water tiles | General compatibility idea from this catch-up, not a promised request | Recognizing water fluid is insufficient to infer depth/capacity or safe dry/restored terrain. Prefer explicit mappings on request. Alien Biomes 0.8.0 keeps the supported water identities; it does not establish a general classifier. |
| Biome-coloured dry terrain / digging machines | [Deep-ground discussion](https://mods.factorio.com/mod/WaterAsAResourceExtended/discussion/64050c9dab51c1d542a85cba) | Cosmetic palette and new extraction gameplay are separate from shipped dry-bed landfill. |
| Older pump projects / arbitrary wells | [P-U-M-P-S](https://mods.factorio.com/mod/WaterAsAResourceExtended/discussion/641e20b178cc92c799fee7c5), [Burner Offshore Pumps](https://mods.factorio.com/mod/WaterAsAResourceExtended/discussion/65c805fa29fa4f8333da8522) | Do not revive obsolete projects or enable wells that bypass connected-lake scarcity. Modern offshore-burner support is already shipped. |
| CanalBuilder / silent terrain integrations | [Historical PR 26](https://github.com/PiotrKaszuba/WaterAsAResourceExtended/pull/26), closed unmerged | Prototype conflict avoidance does not synchronize silent terrain edits. Retain explicit incompatibility; any future adapter must notify supported tile accounting and verify capacity, split/merge and reload. Generic waterfill toggle is already shipped independently. |
| Full planetary fluids / Space Age | [Planetary ignore request](https://mods.factorio.com/mod/WaterAsAResourceExtended/discussion/69c9b6f63362f56fe2a07390) | Default Nauvis admission gate is shipped. Non-water fluids, other terrain, arbitrary surfaces and expansion gameplay remain unimplemented. |
| Pump runtime tooltips | Original catch-up API opportunity, no demonstrated missing feature | Only pursue useful concrete information with modest runtime cost. |
| Faster repeated split-neighbour searches | Profiling found repeated walks through physically landfilled but still logically owned terrain | Existing algorithm remains. Test-only interior shortcut changes parent invalidation timing; prove topology, families, reserves, brush order and reload before adopting it. See [performance rationale](performance/PERFORMANCE_REPORT.md). |

## Optional 2.0-native coverage

Existing 2.0.5 acceptance passed six profiles. Later additions could include actual
2.0.4 → 2.0.5 configuration-change repair with queued terrain, native circuit and
deconstruction transitions, extended settings/research persistence, and actual
2.0-compatible partner ZIPs. These are coverage opportunities, not defects in the
released evidence or a mandate to backport/redesign the 2.1 harness.

Prefer deterministic engine scripts. Add real inventory/robot routes where payloads
or tile underlays differ; do not duplicate the whole mock topology matrix. No shared
harness library is required.
