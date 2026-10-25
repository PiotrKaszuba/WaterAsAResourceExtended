local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
for _, old_version in ipairs({ "2.0.4", "2.1.0" }) do
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    settings.global["Cleanup-Remove-Depleted-Orphaned"].value = false
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 9, y2 = 9 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
    env.run_ticks(300)
    local body = storage.ValidWaterBodies[1]
    body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr
    env.run_ticks(300)
    -- Retain a pending dry cover while simulating pre-update derived corruption.
    world:build_tiles(surface, { { x = 9, y = 9 } }, "landfill")
    local remaining = waterbodies.calculateRemainingWater(body)
    body.waterBodyStateData.DriedTiles = 97
    body.waterBodyStateData.ToDryTiles = 3
    body.searchData.totalArea = 96
    body.waterBodyShapeData.TileCount = 99
    body.waterBodyShapeData.SumX = 0
    control.VersionChanged({ mod_changes = { WaterAsAResourceExtended = {
        old_version = old_version, new_version = "2.1.1" } } })
    t.eq(body.waterBodyStateData.DriedTiles, 100, old_version .. ": repairs dry count from membership")
    t.eq(body.searchData.totalArea, 100, old_version .. ": repairs discovered area")
    t.eq(body.waterBodyShapeData.TileCount, 100, old_version .. ": repairs geometry count")
    t.eq(body.waterBodyShapeData.SumX, 450, old_version .. ": repairs centroid sum")
    t.eq(waterbodies.calculateRemainingWater(body), remaining, old_version .. ": repair adds no water")
    t.eq(storage.TileEventQueue.size, 1, old_version .. ": pending accounting remains ordered")
    env.run_ticks(300)
    body = waterbodies.getWaterBody(waterbodies.getWaterTile(hot_utils.GridKey({ x = 0, y = 0 }), surface))
    assert(body and body.valid, "the surviving lake must remain tracked")
    t.eq(body.waterBodyStateData.DriedTiles, 99, old_version .. ": pending cover removes exactly one dry member")
    t.eq(body.waterBodyShapeData.TileCount, 99, old_version .. ": pending cover removes one geometry member")
    t.eq(body.waterBodyStateData.ToDryTiles, 0, old_version .. ": impossible visual work does not recur")
    t.eq(surface.get_tile({ x = 9, y = 9 }).name, "landfill", old_version .. ": repair does not alter covered terrain")
end
t.finish("Scan accounting upgrade")
