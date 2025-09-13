## Suggestions (performance/maintainability)

- Debug logging and profiling toggles
  - Add a startup/runtime setting (e.g., `WAAR-Debug-Logging`) to gate all `game.print` diagnostics and `utils.profile_hits` calls.
  - Wrap hot-path prints (usage collection, edge scan, split checks) with a cheap boolean early-return.
  - Consider a simple rate limiter for warnings that might otherwise spam (e.g., once per N seconds per waterbody/case).

- Event coverage and migration
  - Optionally handle `on_force_created`, `on_forces_merged`, and `on_runtime_mod_setting_changed` to refresh `storage.PlayerForces` and recompute cached rates if settings change.
  - Implement a minimal `script.on_configuration_changed` path to initialize missing `storage` fields for migrated saves.

Additional issues/suggestions from another pass
Permanent pump disable on waterbody removal:
entities.disablePumpsAndRemoveWaterBody marks pumps disabled = true. Since pumps aren’t auto-attached on later waterfill and enablePump isn’t called anywhere, those pumps can never auto-reactivate. If that’s not intended, either:
Use deactivatePump (not disablePump) for “empty WB” cases, or
On successful waterfill/merge that restores water at a pump input, call entities.enablePump(pump_data) and reattach/assign to the new waterbody.