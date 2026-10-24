-- Identical physical terrain AND accounting grids in both diagnostic modes.
local env = require("tests.helpers.test_env")
return function(side)
    local area = side * side
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    settings.global["Alarms-Tile-Message"].value = false
    settings.global["Scan-Tiles-Per-Second"].value = 100000
    storage.UpdateBudget = 100000
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = side - 1, y2 = side - 1 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
    env.run_ticks(600)
    local body = storage.WaterBodies[1]
    assert(body.searchData.finished)
    assert(waterbody_depletion.getTilesDepleting(body, true, area) == area)
    local stack, grids = body.gridsData.driedStack, body.gridsData
    local positions = {}
    for offset = stack.size - 1, stack.size - math.floor(area * 0.95), -1 do
        local key = stack.buffer[(stack.head + offset - 1) % stack.capacity + 1]
        positions[#positions + 1] = utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData).position
    end
    return world, surface, positions
end
