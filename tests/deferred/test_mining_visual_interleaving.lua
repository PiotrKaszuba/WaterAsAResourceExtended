-- Opt-in regression demonstrating the deferred visual-work/accounting race.
-- Expected to fail; excluded from tests/run.lua default discovery deliberately.
local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
t.start("DEFERRED: mining between queued terrain accounting and visual restoration")

local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 2, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(120)
local body = storage.WaterBodies[1]
body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr
body.waterBodyStateData.TempAvailableWater = 0
env.run_ticks(120)
-- Simulate reserve regeneration having completed before visual restoration.
waterbody_update.updateWaterLevel(body, 0, body.waterAreaData.AmountWtr)
local position = { x = 2, y = 0 }
world:build_tiles(surface, { position }, "landfill")
world:mine_tiles(surface, { position })
-- Extra visual work can run before the next big update drains tile events.
waterbody_depletion.getTilesDepleting(body, false, body.waterBodyStateData.DriedTiles)
env.run_ticks(600)
-- The apparent wet tile was skipped by queued empty-capacity restoration. A
-- fresh paid waterfill and legitimate pump now expose the stale accounting.
world:waterfill(surface, { x = 3, y = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 3, y = -1 }, input_position = { x = 3, y = 0 } })
env.run_ticks(600)
local remaining = 0
for _, live in pairs(storage.ValidWaterBodies) do remaining = remaining + waterbodies.calculateRemainingWater(live) end
t.eq(remaining, 125, "100 retained reserve + 25 paid waterfill; mining must not recreate another 50")
t.finish("DEFERRED: mining/visual-work interleaving")
assert(not t.has_failures(), "Known deferred race reproduced; no protection is currently implemented")
