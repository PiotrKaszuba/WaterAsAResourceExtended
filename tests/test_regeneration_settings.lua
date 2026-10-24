local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local t = require("tests.helpers.test_assert")

t.start()
local world, surface = env.create_world()
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 4, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump",
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 }, surface = surface })
env.run_ticks(120)
local body = storage.WaterBodies[1]
local original_regen = body.waterAreaData.RegenAmount
local capacity = body.waterAreaData.AmountWtr
body.waterBodyStateData.WaterUsed = capacity / 2

-- Updating the mod itself must not silently repair/change old cached settings.
settings.global["Waterbody-Regen-Rate"].value = 0
control.VersionChanged({ mod_changes = { WaterAsAResourceExtended = { old_version = "2.0.3" } } })
t.eq(body.waterAreaData.RegenAmount, original_regen, "configuration change does not migrate regeneration")
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Map-EnableMarkers" })
t.eq(body.waterAreaData.RegenAmount, original_regen, "unrelated settings leave cached regeneration alone")
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Rate" })
t.eq(body.waterAreaData.RegenAmount, 0, "next regeneration edit refreshes existing lake")
local used = body.waterBodyStateData.WaterUsed
env.run_ticks(120)
t.eq(body.waterBodyStateData.WaterUsed, used, "zero regeneration actually stops water recovery")
t.eq(body.waterAreaData.AmountWtr, capacity, "refresh does not change capacity")

settings.global["Waterbody-Regen-Rate"].value = 200
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Rate" })
t.ok(math.abs(body.waterAreaData.RegenAmount - original_regen * 2) < 1e-10,
    "nonzero rate refreshes existing cached value")
env.run_ticks(120)
t.ok(body.waterBodyStateData.WaterUsed < used, "nonzero regeneration restores water")
settings.global["Waterbody-Regen-Rate"].value = 0
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Rate" })
waterbodies.CalculateAndUpdateWaterBodyAreaData(body)
t.eq(body.waterAreaData.RegenAmount, 0, "later topology recalculation retains current rate")
t.finish("Regeneration setting changes")
