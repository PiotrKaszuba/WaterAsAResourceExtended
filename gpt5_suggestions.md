## Suggestions (performance/maintainability)

- Debug logging and profiling toggles
  - Add a startup/runtime setting (e.g., `WAAR-Debug-Logging`) to gate all `game.print` diagnostics and `utils.profile_hits` calls.
  - Wrap hot-path prints (usage collection, edge scan, split checks) with a cheap boolean early-return.
  - Consider a simple rate limiter for warnings that might otherwise spam (e.g., once per N seconds per waterbody/case).

- Map marker updates
  - Update markers only when a meaningful threshold changes, e.g., percentage-used crosses integer percent or configured step (5%).
  - Keep a cached marker position per waterbody (e.g., centroid of pumps or bounding-box center) and only recreate when the anchor moves substantially; otherwise update text/icon in place.
  - Optionally allow a global toggle per-force to disable markers for that force.

- Unified use of surface.set_tiles raise_event
  - Standardize calls to `surface.set_tiles` so that scripted changes used for visuals (depletion/restoration) pass `raise_event = false` to avoid double handling; explicit booleans for the first 4 parameters improve readability.
  - For programmatic water placement (`tiles.placerWater`), either rely exclusively on manual queueing (current `handleTileEventsInternal`) with `raise_event = false`, or let the engine raise events and remove the manual queueing to prevent duplicate work.

- Gradual depletion visuals (future rework)
  - Replace full-array sort with incremental selection:
    - Maintain a queue or ring of candidates pre-ordered relative to a cached focus point; refresh only when pumps set or bounding box changes notably.
    - Process a small budgeted number of tiles per big update; sample if the candidate set is very large.
    - Consider storing a LIFO "dried tiles stack" to make restoration O(k) without rescanning.

- Event coverage and migration
  - Optionally handle `on_force_created`, `on_forces_merged`, and `on_runtime_mod_setting_changed` to refresh `storage.PlayerForces` and recompute cached rates if settings change.
  - Implement a minimal `script.on_configuration_changed` path to initialize missing `storage` fields for migrated saves.

Additional issues/suggestions from another pass
Permanent pump disable on waterbody removal:
entities.disablePumpsAndRemoveWaterBody marks pumps disabled = true. Since pumps aren’t auto-attached on later waterfill and enablePump isn’t called anywhere, those pumps can never auto-reactivate. If that’s not intended, either:
Use deactivatePump (not disablePump) for “empty WB” cases, or
On successful waterfill/merge that restores water at a pump input, call entities.enablePump(pump_data) and reattach/assign to the new waterbody.