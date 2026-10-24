local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(120)
local body = storage.WaterBodies[1]
t.eq(waterbody_depletion.getTilesDepleting(body, true, 1), 1, "initial drying succeeds")
t.eq(waterbody_depletion.getTilesDepleting(body, true, 1), 0, "exhausted visual work returns zero without crashing")
t.eq(select(3, dynamic_bins.batch_pop({}, 0)), 0, "zero-request bin pop retains the count contract")
assert(not t.has_failures(), "empty visual work regression")
