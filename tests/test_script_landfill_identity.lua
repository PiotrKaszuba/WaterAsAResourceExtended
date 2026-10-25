local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 4, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(600)
local body = storage.ValidWaterBodies[1]
body.waterBodyStateData.WaterUsed = 100
body.waterBodyStateData.TempAvailableWater = 150

-- This mock API emits the actual documented native payload: name/position,
-- without old_tile. An earlier hand-authored payload hid the missing fallback.
local edit = { { name = "landfill", position = { x = 4, y = 0 } } }
surface.set_tiles(edit, false, false, false, true)
local queue = tiles.getTileEventQueue()
t.eq(queue.buffer[queue.head].tileData.originalTileName, "water", "native-shaped edit resolves tracked water identity")
env.run_ticks(600)
t.eq(body.waterAreaData.AmountWtr, 200, "script landfill removes the recovered capacity class")
t.eq(waterbodies.calculateRemainingWater(body), 120, "script landfill preserves depletion fraction")

surface.set_tiles(edit, false, false, false, true)
env.run_ticks(600)
t.eq(body.waterAreaData.AmountWtr, 200, "repeated script notification does not remove capacity twice")
t.eq(waterbodies.calculateRemainingWater(body), 120, "repeated script notification creates no water")
t.finish("Native script landfill identity")
assert(not t.has_failures(), "script landfill identity failed")
