local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 39, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(600)
local positions = {}
for x = 0, 29 do positions[#positions + 1] = { x = x, y = 0 } end
world:build_tiles(surface, positions, "landfill")
-- The first edit cannot see a real wet/dry neighbor within the bounded
-- landfill search. Later queued edits will reach the surviving water.
while tiles.getTileEventQueue().size > 0 do tiles.processTileEventQueue(1, { budget = 10000 }) end
local capacity = 0
for _, body in pairs(storage.ValidWaterBodies) do capacity = capacity + body.waterAreaData.AmountWtr end
t.eq(capacity, 10 * 50, "large brush without a visible split seed retains the surviving capacity")

-- A central removal can initially expose no seed, then reach two surviving
-- components. Delaying that first decision must not lose the later split.
world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 79, y2 = 0 })
for _, x in ipairs({ 0, 79 }) do
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
end
env.run_ticks(600)
storage.WaterBodies[1].waterBodyStateData.WaterUsed = 80 * 50 * 0.4
positions = { { x = 40, y = 0 } }
for x = 10, 69 do if x ~= 40 then positions[#positions + 1] = { x = x, y = 0 } end end
world:build_tiles(surface, positions, "landfill")
while tiles.getTileEventQueue().size > 0 do tiles.processTileEventQueue(1, { budget = 10000 }) end
env.run_ticks(1200)
local remaining, bodies = 0, 0
capacity = 0
for _, body in pairs(storage.ValidWaterBodies) do
    bodies = bodies + 1
    capacity = capacity + body.waterAreaData.AmountWtr
    remaining = remaining + waterbodies.calculateRemainingWater(body)
end
t.eq(bodies, 2, "later frontier removals still split both surviving components")
t.eq(capacity, 20 * 50, "both surviving components retain their exact capacity")
t.ok(math.abs(remaining - 20 * 50 * 0.6) < 1e-7, "delayed split retains the original depletion fraction")
assert(not t.has_failures(), "landfill without split seed regression")
