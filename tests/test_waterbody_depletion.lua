if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

--[[
Precise Depletion Test

Setup: 5 shallow water tiles (0,0) to (4,0)
- TotalArea = 5
- AmountWtr = 5 * 50 = 250
- WaterBodyType = 2 (Pond)
- BonusValue = 1.5^(-1) = 0.667
- Visual-Depletion-Start-Percentage = 80%

Timing:
- PeriodicEveryXTicks = 1
- PeriodicTicksPerBigUpdate = 30
- pump_flow = 1 → uses 30 water per big update

Checkpoints:
- After scan (120 ticks): WaterUsed=0, DriedTiles=0
- After 7 big updates (+210 ticks): ~84% used, DriedTiles=1
- After 3 more big updates (+90 ticks): 100% depleted, DriedTiles=5
- After boosted regen: tiles restored
]]

-- Helper: count tiles on surface matching a name
local function count_surface_tiles(surface, rect, tile_name)
    local count = 0
    for x = rect.x1, rect.x2 do
        for y = rect.y1, rect.y2 do
            if surface.get_tile({x=x, y=y}).name == tile_name then
                count = count + 1
            end
        end
    end
    return count
end

-- Helper: count entries in a grid (including lazy arrays)
local function count_grid_entries(grid, lazy_array)
    local count = 0
    for _ in pairs(grid or {}) do count = count + 1 end
    for _, lazy in ipairs(lazy_array or {}) do
        for _ in pairs(lazy) do count = count + 1 end
    end
    return count
end

local function run_test()
    t.start()
    
    -- ========================================
    -- PHASE 1: Setup and Scan
    -- ========================================
    local world, surface = test_env.create_world()
    
    -- Create 5x1 water rectangle
    local water_rect = { x1 = 0, y1 = 0, x2 = 4, y2 = 0 }
    world:set_water_rectangle(surface, water_rect)
    
    -- Build pump
    local pump = world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 0, y = -1 },
        surface = surface,
        input_position = { x = 0, y = 0 },
    })
    
    -- Run until scan completes
    test_env.run_ticks(120)
    
    local wbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(wbody ~= nil, "water body created")
    t.ok(wbody and wbody.valid, "water body is valid")
    
    if not wbody then
        t.finish("Depletion test aborted - no water body")
        return
    end
    
    -- Verify initial state
    t.eq(wbody.waterAreaData.TotalArea, 5, "total area is 5")
    t.eq(wbody.waterAreaData.AmountWtr, 250, "water amount is 250")
    t.eq(wbody.waterAreaData.WaterBodyType, 2, "water body type is Pond (2)")
    t.eq(wbody.waterBodyStateData.DriedTiles, 0, "no dried tiles initially")
    t.eq(wbody.waterBodyStateData.WaterUsed, 0, "no water used initially")
    
    local water_count = count_surface_tiles(surface, water_rect, "water")
    t.eq(water_count, 5, "all 5 tiles are water initially")
    
    -- ========================================
    -- PHASE 2: Pump past 80% threshold
    -- ========================================
    -- Pump uses 30 water per big update, but regen reduces this slightly
    -- Need ~9 big updates to cross 80% (200 water)
    t.print("Starting depletion phase: pump_flow=1, 270 ticks (9 big updates)")
    
    world:set_pump_flow(pump, 1)  -- 1 water per tick = 30 per big update
    test_env.run_ticks(270)  -- 9 big updates worth
    
    -- Expected: WaterUsed > 200, percentUsed > 80%
    local state = wbody.waterBodyStateData
    local water_used = state.WaterUsed
    local percent_used = (water_used / 250) * 100
    
    t.print(string.format("After 9 big updates: WaterUsed=%.1f, %%Used=%.1f%%", water_used, percent_used))
    t.ok(water_used >= 200, "water used >= 200 (crossed 80% threshold)")
    t.ok(percent_used >= 80, "percent used >= 80% (depletion threshold)")
    
    -- Check dried tiles
    local dried_tiles = state.DriedTiles
    t.print(string.format("DriedTiles=%d", dried_tiles))
    t.ok(dried_tiles >= 1, "at least 1 tile dried after crossing 80%")
    
    -- Check surface tiles match
    local dry_on_surface = count_surface_tiles(surface, water_rect, "lake-shallow")
    local wet_on_surface = count_surface_tiles(surface, water_rect, "water")
    t.print(string.format("Surface: %d dry, %d wet", dry_on_surface, wet_on_surface))
    t.eq(dry_on_surface, dried_tiles, "dry tiles on surface matches DriedTiles counter")
    t.eq(wet_on_surface, 5 - dried_tiles, "wet tiles = total - dried")
    
    -- Check internal grids
    local gridsData = wbody.gridsData
    local water_grid_count = count_grid_entries(gridsData.waterGridWithData, gridsData.lazyWaterGridWithData)
    local dried_grid_count = count_grid_entries(gridsData.driedTilesGridWithData, gridsData.lazyDriedTilesGridWithData)
    t.eq(dried_grid_count, dried_tiles, "driedTilesGridWithData count matches DriedTiles")
    t.eq(water_grid_count, 5 - dried_tiles, "waterGridWithData count matches remaining wet tiles")
    
    -- ========================================
    -- PHASE 3: Pump to 100% depletion
    -- ========================================
    t.print("Continuing to full depletion: +90 ticks (3 more big updates)")
    
    test_env.run_ticks(90)  -- 3 more big updates to reach 100%
    
    water_used = state.WaterUsed
    percent_used = (water_used / 250) * 100
    dried_tiles = state.DriedTiles
    
    t.print(string.format("After full depletion: WaterUsed=%.1f, %%Used=%.1f%%, DriedTiles=%d", 
        water_used, percent_used, dried_tiles))
    
    t.ok(percent_used >= 99, "percent used >= 99% (fully depleted)")
    t.eq(dried_tiles, 5, "all 5 tiles dried at 100%")
    t.ok(state.Depleted, "waterbody is marked as Depleted")
    
    -- All tiles should be dry on surface
    dry_on_surface = count_surface_tiles(surface, water_rect, "lake-shallow")
    wet_on_surface = count_surface_tiles(surface, water_rect, "water")
    t.eq(dry_on_surface, 5, "all 5 tiles are lake-shallow on surface")
    t.eq(wet_on_surface, 0, "no water tiles remain on surface")
    
    -- Internal grids
    water_grid_count = count_grid_entries(gridsData.waterGridWithData, gridsData.lazyWaterGridWithData)
    dried_grid_count = count_grid_entries(gridsData.driedTilesGridWithData, gridsData.lazyDriedTilesGridWithData)
    t.eq(dried_grid_count, 5, "all 5 tiles in driedTilesGridWithData")
    t.eq(water_grid_count, 0, "no tiles in waterGridWithData")
    
    -- ========================================
    -- PHASE 4: Stop pumping, boost regen, restore
    -- ========================================
    t.print("Stopping pump, boosting regen rate for restoration test")
    
    world:set_pump_flow(pump, 0)  -- Stop pumping
    
    -- Boost regen rate significantly for testable restoration
    -- Default: 100 → gives ~0.017 regen per big update (too slow)
    -- Set to 50000 → gives ~8.3 regen per big update
    -- To restore from 250 to 200 (80%), need to recover 50 water
    -- At 8.3 per update: ~6 big updates = 180 ticks
    settings.global["Waterbody-Regen-Rate"] = { value = 50000 }
    
    -- Need to recalculate water area data to pick up new regen rate
    -- waterbodies is a global after requiring control.lua
    waterbodies.CalculateAndUpdateWaterBodyAreaData(wbody)
    
    t.print(string.format("New RegenAmount: %.2f per second", wbody.waterAreaData.RegenAmount))
    
    -- Run enough ticks to restore below 80%
    test_env.run_ticks(300)  -- 10 big updates
    
    water_used = state.WaterUsed
    percent_used = (water_used / 250) * 100
    dried_tiles = state.DriedTiles
    
    t.print(string.format("After regen phase 1: WaterUsed=%.1f, %%Used=%.1f%%, DriedTiles=%d", 
        water_used, percent_used, dried_tiles))
    
    -- Should be partially restored
    t.ok(percent_used < 100, "percent used < 100% after regen")
    t.ok(dried_tiles < 5, "some tiles restored (DriedTiles < 5)")
    
    -- Continue restoration
    test_env.run_ticks(600)  -- 20 more big updates
    
    water_used = state.WaterUsed
    percent_used = (water_used / 250) * 100
    dried_tiles = state.DriedTiles
    
    t.print(string.format("After regen phase 2: WaterUsed=%.1f, %%Used=%.1f%%, DriedTiles=%d", 
        water_used, percent_used, dried_tiles))
    
    -- Check final restoration state
    if percent_used < 80 then
        t.eq(dried_tiles, 0, "all tiles restored when below 80%")
        
        dry_on_surface = count_surface_tiles(surface, water_rect, "lake-shallow")
        wet_on_surface = count_surface_tiles(surface, water_rect, "water")
        t.eq(wet_on_surface, 5, "all 5 tiles are water on surface after restoration")
        t.eq(dry_on_surface, 0, "no dry tiles on surface after restoration")
        
        -- Internal grids
        water_grid_count = count_grid_entries(gridsData.waterGridWithData, gridsData.lazyWaterGridWithData)
        dried_grid_count = count_grid_entries(gridsData.driedTilesGridWithData, gridsData.lazyDriedTilesGridWithData)
        t.eq(water_grid_count, 5, "all 5 tiles back in waterGridWithData")
        t.eq(dried_grid_count, 0, "no tiles in driedTilesGridWithData")
        
        t.ok(not state.Depleted, "waterbody no longer marked as Depleted")
    else
        t.print("Regen not fast enough to restore below 80% - running more ticks")
        test_env.run_ticks(600)  -- 20 more big updates
        
        water_used = state.WaterUsed
        percent_used = (water_used / 250) * 100
        dried_tiles = state.DriedTiles
        
        t.print(string.format("After regen phase 3: WaterUsed=%.1f, %%Used=%.1f%%, DriedTiles=%d", 
            water_used, percent_used, dried_tiles))
        
        t.ok(percent_used < 80, "percent used < 80% after extended regen")
        t.eq(dried_tiles, 0, "all tiles restored")
    end
    
    t.finish("Waterbody depletion test complete")
end

run_mock_test(run_test)
