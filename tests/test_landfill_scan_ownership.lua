local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
t.start()

for _,route in ipairs({ "scan", "edge" }) do
    for _,drying in ipairs({ false, true }) do
        local world, surface = env.create_world()
        settings.global["Waterbody-Regen-Rate"].value = 0
        settings.global["Map-EnableMarkers"].value = false
        settings.global["Cleanup-Remove-Depleted-Orphaned"].value = false
        local position = { x = 1, y = 0 }
        local key = hot_utils.GridKey(position)
        world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 2, y2 = 0 })
        world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
            position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
        env.run_ticks(120)
        local body = waterbodies.getWaterBody(waterbodies.getWaterTile(key, surface))
        local capacity = body.waterAreaData.AmountWtr
        if not drying then
            body.waterBodyStateData.WaterUsed = capacity
            env.run_ticks(120)
        end
        local label = route .. (drying and "/wet cover, then dry" or "/dry cover, then restore")
        world:build_tiles(surface, { position }, "landfill")

        -- A second scan represents a split successor encountering a covered
        -- position whose removal event is still queued. No merge is needed.
        local scanner, scanner_id = waterbodies.createNewWaterBody(surface)
        if route == "scan" then
            waterbody_scan.beginScanWaterArea(scanner_id, position, 1)
        else
            waterbody_scan.EdgePattern({ x = 1, y = -1 }, surface, surface.name, scanner, true, false)
        end
        t.eq(waterbodies.getWaterTile(key, surface), body.waterBodyId, label .. ": owner retained for queued removal")
        t.eq(surface.get_tile(position).name, "landfill", label .. ": scan leaves physical landfill intact")
        t.eq(storage.TileEventQueue.size, 1, label .. ": scanner does not consume or add events")
        tiles.processTileEventQueue(100, { budget = 1000 })
        t.eq(body.waterAreaData.TotalArea, 2, label .. ": queued removal subtracts exactly one tile")
        t.eq(body.waterAreaData.AmountWtr, capacity * 2 / 3, label .. ": queued removal subtracts its capacity")
        t.eq(waterbodies.getWaterTile(key, surface), -1, label .. ": completed removal clears ownership")
        t.eq(storage.TileEventQueue.size, 0, label .. ": accounting queue drains")
        t.ok(next(storage.PendingTileChanges) == nil, label .. ": pending index drains")
        local grids = body.gridsData
        t.ok(not utils.LazyTables.get(key, grids.waterGridWithData, grids.lazyWaterGridWithData)
            and not utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData),
            label .. ": removed from both visual grids")

        -- Controlled reserve changes schedule ordinary visual work; the only
        -- terrain operation under test remains player landfill placement.
        for _,fraction in ipairs({ drying and 1 or 0, drying and 0 or 1 }) do
            body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * fraction
            env.run_ticks(120)
            t.eq(surface.get_tile(position).name, "landfill", label .. ": landfill survives visual cycle " .. fraction)
        end

        -- Once no event is pending, an ordinary land boundary still follows
        -- the original marking path; the scan must not retain stale owners.
        local _, settled_scanner_id = waterbodies.createNewWaterBody(surface)
        waterbody_scan.beginScanWaterArea(settled_scanner_id, position, 1)
        t.eq(waterbodies.getWaterTile(key, surface), -1, label .. ": settled land remains unassigned")
    end
end

t.finish("Landfill ownership during scanning")
