local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
for _, route in ipairs({
    { "2.0.4", "2.0.5" }, { "2.0.4", "2.1.1" }, { "2.1.0", "2.1.1" },
}) do
    local old_version, new_version = route[1], route[2]
    local label = old_version .. " -> " .. new_version
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
    local repair, calls = waterbodies.repairScanAccounting, 0
    waterbodies.repairScanAccounting = function() calls = calls + 1; return repair() end
    control.VersionChanged({ mod_changes = { WaterAsAResourceExtended = {
        old_version = old_version, new_version = new_version } } })
    waterbodies.repairScanAccounting = repair
    t.eq(calls, 1, label .. ": runs the affected-version repair exactly once")
    t.eq(body.waterBodyStateData.DriedTiles, 100, label .. ": repairs dry count from membership")
    t.eq(body.searchData.totalArea, 100, label .. ": repairs discovered area")
    t.eq(body.waterBodyShapeData.TileCount, 100, label .. ": repairs geometry count")
    t.eq(body.waterBodyShapeData.SumX, 450, label .. ": repairs centroid sum")
    t.eq(waterbodies.calculateRemainingWater(body), remaining, label .. ": repair adds no water")
    t.eq(storage.TileEventQueue.size, 1, label .. ": pending accounting remains ordered")
    env.run_ticks(300)
    body = waterbodies.getWaterBody(waterbodies.getWaterTile(hot_utils.GridKey({ x = 0, y = 0 }), surface))
    assert(body and body.valid, "the surviving lake must remain tracked")
    t.eq(body.waterBodyStateData.DriedTiles, 99, label .. ": pending cover removes exactly one dry member")
    t.eq(body.waterBodyShapeData.TileCount, 99, label .. ": pending cover removes one geometry member")
    t.eq(body.waterBodyStateData.ToDryTiles, 0, label .. ": impossible visual work does not recur")
    t.eq(surface.get_tile({ x = 9, y = 9 }).name, "landfill", label .. ": repair does not alter covered terrain")
end
-- A corrected 2.0.5 save must not pay for or repeat the repair on the 2.1 port.
do
    env.create_world()
    local repair, calls = waterbodies.repairScanAccounting, 0
    waterbodies.repairScanAccounting = function() calls = calls + 1; return repair() end
    control.VersionChanged({ mod_changes = { WaterAsAResourceExtended = {
        old_version = "2.0.5", new_version = "2.1.1" } } })
    waterbodies.repairScanAccounting = repair
    t.eq(calls, 0, "2.0.5 -> 2.1.1 skips the already-applied repair")
end
t.finish("Scan accounting upgrade")
