-- Diagnostic regression: currently fails on factorio-2.1 / v2.1.0.
-- Run separately from the passing suite:
--   lua tests/repros/landfill_dry_counter.lua
-- Wet-only control (same geometry and event timing): append --wet.
local env = require("tests.helpers.test_env")
local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
settings.global["Map-EnableMarkers"].value = false
settings.global["Cleanup-Remove-Depleted-Orphaned"].value = false

local terrain = {}
for x = 0, 47 do
    for y = 0, 31 do
        terrain[#terrain + 1] = { name = "water", position = { x = x, y = y } }
    end
end
surface.set_tiles(terrain)
for _, x in ipairs({ 0, 20, 47 }) do
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
end
env.run_ticks(3000)
local wet_control = arg and arg[1] == "--wet"
for _, body in pairs(storage.ValidWaterBodies) do
    -- Controlled initial depletion; subsequent visual, event, scan, split and
    -- merge work runs through the ordinary production tick handlers.
    body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * (wet_control and 0 or 0.98)
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function check_counters()
    for id, body in pairs(storage.ValidWaterBodies) do
        local grids = body.gridsData
        local actual = count(grids.driedTilesGridWithData)
        for _, lazy in ipairs(grids.lazyDriedTilesGridWithData) do actual = actual + count(lazy) end
        assert(actual == body.waterBodyStateData.DriedTiles,
            string.format("tick %d, body %d: dry grid contains %d tiles but DriedTiles is %d",
                game.tick, id, actual, body.waterBodyStateData.DriedTiles))
    end
end

for step = 0, 35 do
    if step < 32 then
        -- Gradual narrow cut while drying runs; potential splits create seeds
        -- which can meet and merge during the same scan call.
        world:build_tiles(surface, { { x = 22, y = step }, { x = 23, y = step } }, "landfill")
    end
    for _ = 1, 7 do
        env.run_ticks(1)
        check_counters()
    end
end
print("Dry-grid counter invariant holds" .. (wet_control and " (wet-only control)" or ""))
