-- Opt-in diagnostic for deferred queued-terrain/visual-work protection.
-- Expected to fail while that protection is deliberately not implemented.
local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
t.start()

local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 9, y2 = 9 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(600)
local body = storage.WaterBodies[1]
waterbody_depletion.getTilesDepleting(body, true, 100)
local grids = body.gridsData
local stack = grids.driedStack
local covered, unaffected = {}, {}
-- Arrange a real backlog at the front of the upcoming LIFO restoration work.
for offset = stack.size - 1, 0, -1 do
    local key = stack.buffer[(stack.head + offset - 1) % stack.capacity + 1]
    local tile = utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData)
    local group = #covered < 90 and covered or unaffected
    group[#group + 1] = tile.position
end
world:build_tiles(surface, covered, "landfill")
t.eq(tiles.getTileEventQueue().size, 90, "backlog contains exactly the successful terrain edits")

local original_get, original_next = utils.LazyTables.get, utils.LazyTables.next
local selected_lookups = 0
utils.LazyTables.get = function(key, map, ...)
    if map == grids.driedTilesGridWithData then selected_lookups = selected_lookups + 1 end
    return original_get(key, map, ...)
end
utils.LazyTables.next = function(map, ...)
    if map == grids.driedTilesGridWithData then selected_lookups = selected_lookups + 1 end
    return original_next(map, ...)
end
local changed = waterbody_depletion.getTilesDepleting(body, false, 1)
local first_attempt_lookups = selected_lookups
utils.LazyTables.get, utils.LazyTables.next = original_get, original_next
t.ok(first_attempt_lookups <= 4,
    "one selected visual-work request does not sweep the pending lake (lookups=" .. first_attempt_lookups .. ")")
for _ = 1, 110 do changed = changed + waterbody_depletion.getTilesDepleting(body, false, 1) end
t.eq(changed, 10, "unaffected restoration continues while queued edits remain pending")
for _, position in ipairs(covered) do
    assert(surface.get_tile(position).name == "landfill", "visual work overwrote pending landfill")
end
for _, position in ipairs(unaffected) do
    assert(surface.get_tile(position).name == "water", "unaffected terrain failed to restore")
end
t.eq(tiles.getTileEventQueue().size, 90, "visual work does not consume or duplicate queued accounting events")
t.eq(tiles.processTileEventQueue(5, { budget = 100000 }), 5, "partial event budget processes exactly five edits")
t.eq(tiles.getTileEventQueue().size, 85, "partial event drain retains the remaining backlog")
t.eq(tiles.processTileEventQueue(1000, { budget = 100000 }), 85, "remaining events drain exactly once")
t.eq(tiles.getTileEventQueue().size, 0, "terrain queue is empty after drain")

t.finish("Pending tile backlog bounds and unaffected visual progress")
assert(not t.has_failures(), "pending terrain backlog test failed")
