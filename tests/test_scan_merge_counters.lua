local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local survivors = { changed = 0, retained = 0 }

local function check_members()
    for id, body in pairs(storage.ValidWaterBodies) do
        local g, count, dry, sx, sy, seen = body.gridsData, 0, 0, 0, 0, {}
        local function add(grid, is_dry)
            for key, tile in pairs(grid) do
                assert(not seen[key], "duplicate grid membership for body " .. id)
                seen[key] = true; count = count + 1; dry = dry + (is_dry and 1 or 0)
                sx = sx + tile.position.x; sy = sy + tile.position.y
            end
        end
        add(g.waterGridWithData, false); add(g.driedTilesGridWithData, true)
        for _, grid in ipairs(g.lazyWaterGridWithData) do add(grid, false) end
        for _, grid in ipairs(g.lazyDriedTilesGridWithData) do add(grid, true) end
        local shape = body.waterBodyShapeData
        local prefix = "tick " .. game.tick .. ", body " .. id .. ": "
        assert(body.waterBodyStateData.DriedTiles == dry, prefix .. "dry counter differs from membership")
        assert(body.searchData.totalArea == count, prefix .. "search area differs from membership")
        assert(shape.TileCount == count and shape.SumX == sx and shape.SumY == sy,
            prefix .. "geometry count/sums differ from membership")
    end
end

for _, fraction in ipairs({ 0, 0.98 }) do
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    settings.global["Cleanup-Remove-Depleted-Orphaned"].value = false
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 47, y2 = 31 })
    for _, x in ipairs({ 0, 20, 47 }) do
        world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
            position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
    end
    env.run_ticks(3000)
    for _, body in pairs(storage.ValidWaterBodies) do
        body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * fraction
    end
    local original_merge = waterbody_merge.mergeWaterBody
    waterbody_merge.mergeWaterBody = function(a, b)
        local current = b.waterBodyId
        local id = original_merge(a, b)
        local key = id == current and "retained" or "changed"
        survivors[key] = survivors[key] + 1
        return id
    end
    for step = 0, 35 do
        if step < 32 then
            world:build_tiles(surface, { { x = 22, y = step }, { x = 23, y = step } }, "landfill")
        end
        for _ = 1, 7 do env.run_ticks(1); check_members() end
    end
    env.run_ticks(1800); check_members()
    waterbody_merge.mergeWaterBody = original_merge
    t.ok(true, fraction == 0 and "wet cut retains all scan/geometry counters" or
        "dry cut retains all scan/geometry counters")
end
t.ok(survivors.changed > 0, "exercises a merge that changes the scanning body ID")
t.ok(survivors.retained > 0, "exercises a merge that retains the scanning body ID")
t.finish("Scan/merge batch accounting")
