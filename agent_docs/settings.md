## progress
- Reorganized user-facing setting definitions for clearer GUI grouping and stable ordering in the Factorio interface.
- Added runtime controls for the waterbody scan status reminder period and centroid shift sensitivity so behaviour can be tuned during play.
- Added startup options for regeneration scaling and optional waterbody caps to let scenario authors tweak world creation.
- Updated localisation strings and mocked defaults to match the expanded setting set.
- Synced all numeric mod-setting descriptions with their min/default/max values from `settings.lua`, fixing outdated defaults like the deep tile capacity entry.
- Confirmed tests load the revised defaults to keep the mocked runtime consistent with the available setting set.

## still missing
- The regeneration curvature in `modules/waterbody_update.lua` still hardcodes the 75% inflection point and 0.5–1.5 multiplier range; it may warrant future settings if players need to tune that behaviour.
