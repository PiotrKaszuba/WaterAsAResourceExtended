local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
t.start()
for _, dry in ipairs({ false, true }) do
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 4, y2 = 0 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
    env.run_ticks(120)
    local body = storage.ValidWaterBodies[1]
    if dry then body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr; env.run_ticks(120) end
    world:build_tiles(surface, { { x = 4, y = 0 } }, "landfill")
    env.run_ticks(120)
    local label = dry and "dry cover" or "wet cover"
    t.eq(body.waterBodyShapeData.TileCount, 4, label .. ": reclaimed tile leaves geometry")
    t.eq(body.waterBodyShapeData.SumX, 6, label .. ": reclaimed coordinate leaves centroid sum")
    t.eq(waterbodies.getCentroid(body).x, 1.5, label .. ": centroid follows remaining members")
end
t.finish("Landfill geometry removal")
