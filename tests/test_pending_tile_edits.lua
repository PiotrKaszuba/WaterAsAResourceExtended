local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")

t.start("Pending terrain edits protect selected visual work")

local function fixture(dry)
    local world, surface = test_env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump",
        position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 }, surface = surface })
    test_env.run_ticks(120)
    local body
    for _, candidate in pairs(storage.ValidWaterBodies) do body = candidate end
    t.ok(body ~= nil, "fixture tracks a lake")
    if dry then
        t.eq(waterbody_depletion.getTilesDepleting(body, true, 1), 1, "fixture dries its tile")
    end
    local position = { x = 0, y = 0 }
    local old = surface.get_tile(position).name
    -- Use the engine's post-build contract directly; do not depend on the mock
    -- world's historical landfill convenience helper to change physical terrain.
    surface.set_tiles({ { name = "landfill", position = position } })
    event_handlers.handlePlayerTileEvents({ surface_index = surface.index,
        tile = { name = "landfill" }, tiles = { { position = position, old_tile = { name = old } } } })
    return surface, body, position
end

do
    local surface, body, position = fixture(true)
    t.eq(waterbody_depletion.getTilesDepleting(body, false, 1), 0,
        "queued landfill prevents pending regeneration from restoring its tile")
    t.eq(surface.get_tile(position).name, "landfill", "regeneration leaves landfill intact")
    local grids = body.gridsData
    t.ok(utils.LazyTables.get(hot_utils.GridKey(position), grids.driedTilesGridWithData,
        grids.lazyDriedTilesGridWithData) ~= nil, "skipped visual work retains its source record")
    tiles.processTileEventQueue(100, { budget = 10000 })
    t.eq(waterbodies.getWaterTile(hot_utils.GridKey(position), surface), -1,
        "normal landfill accounting eventually removes ownership")
    t.eq(surface.get_tile(position).name, "landfill", "processed landfill stays intact")
end

do
    local surface, body, position = fixture(false)
    t.eq(waterbody_depletion.getTilesDepleting(body, true, 1), 0,
        "queued landfill prevents drying from replacing land too")
    t.eq(surface.get_tile(position).name, "landfill", "drying leaves landfill intact")
end

do
    local surface, body, position = fixture(true)
    tiles.addTileEvent("waterfill", position, surface, { tileName = "water" })
    -- A pre-fix saved queue has no derived protection table. Reconstruct it
    -- without consuming any work, then process only the first of two edits.
    storage.PendingTileChanges = nil
    tiles.processTileEventQueue(0, { budget = 10000 })
    local key = hot_utils.GridKey(position)
    t.eq(storage.PendingTileChanges[surface.name][key], 2, "old queues rebuild edit counts")
    tiles.processTileEventQueue(1, { budget = 10000 })
    t.eq(storage.PendingTileChanges[surface.name][key], 1, "first edit does not unlock a later edit")
    tiles.processTileEventQueue(1, { budget = 10000 })
    t.ok(storage.PendingTileChanges[surface.name] == nil or
        storage.PendingTileChanges[surface.name][key] == nil, "completed queue retains no per-position history")
end

t.finish()
