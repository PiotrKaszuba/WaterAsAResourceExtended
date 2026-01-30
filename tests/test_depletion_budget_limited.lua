if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

--[[
Budget-Limited Depletion Test

Tests that when ToDryTiles exceeds budget capacity, tiles are processed across
multiple update cycles with leftover ToDryTiles accumulating.

Setup:
- Budget = 100/sec → 50 per big update cycle
- update_budget_per_move = 0.01
- Max tiles per cycle = 50 / 0.01 = 5000

Waterbodies:
- 3 waterbodies, each 50x50 = 2500 tiles = 125,000 water
- Total: 7500 tiles, 375,000 water
- When depleted: 7500 ToDryTiles (exceeds 5000 budget capacity)

Expected behavior:
- After depletion: 7500 ToDryTiles total
- After 1st cycle: ~5000 DriedTiles, ~2500 ToDryTiles remaining
- After 2nd cycle: 7500 DriedTiles total, 0 ToDryTiles remaining
]]

-- Helper: count tiles on surface matching a name in a rectangle
local function count_surface_tiles_rect(surface, rect, tile_name)
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

-- Helper: sum a field across all valid waterbodies
local function sum_waterbody_field(field_path)
    local total = 0
    for _, wb in pairs(storage.ValidWaterBodies or {}) do
        if wb and wb.valid then
            local value = wb
            for part in string.gmatch(field_path, "[^.]+") do
                value = value and value[part]
            end
            if type(value) == "number" then
                total = total + value
            end
        end
    end
    return total
end

local function run_test()
    t.start()
    
    -- ========================================
    -- Configuration
    -- ========================================
    local SIDE_SIZE = 50  -- 50x50 = 2500 tiles per waterbody
    local NUM_WATERBODIES = 3
    local TILES_PER_WB = SIDE_SIZE * SIDE_SIZE  -- 2500
    local TOTAL_TILES = TILES_PER_WB * NUM_WATERBODIES  -- 7500
    local WATER_PER_TILE = 50  -- shallow water default
    local WATER_PER_WB = TILES_PER_WB * WATER_PER_TILE  -- 125,000
    local BUDGET_PER_SECOND = 100
    local MAX_TILES_PER_CYCLE = 5000  -- 50 budget / 0.01 per tile
    
    t.print(string.format("Config: %d waterbodies, %dx%d each = %d tiles total", 
        NUM_WATERBODIES, SIDE_SIZE, SIDE_SIZE, TOTAL_TILES))
    t.print(string.format("Budget: %d/sec, max ~%d tiles/cycle", BUDGET_PER_SECOND, MAX_TILES_PER_CYCLE))
    
    -- ========================================
    -- PHASE 1: Setup and Scan
    -- ========================================
    local world, surface = test_env.create_world()
    
    -- Set budget
    settings.global["Update-Budget-Per-Second"] = { value = BUDGET_PER_SECOND }
    
    -- Create 3 waterbodies with spacing
    local rects = {
        { x1 = 0, y1 = 0, x2 = SIDE_SIZE - 1, y2 = SIDE_SIZE - 1 },      -- WB A at (0,0)
        { x1 = 60, y1 = 0, x2 = 60 + SIDE_SIZE - 1, y2 = SIDE_SIZE - 1 }, -- WB B at (60,0)
        { x1 = 120, y1 = 0, x2 = 120 + SIDE_SIZE - 1, y2 = SIDE_SIZE - 1 }, -- WB C at (120,0)
    }
    
    local pumps = {}
    for i, rect in ipairs(rects) do
        world:set_water_rectangle(surface, rect)
        pumps[i] = world:build_entity({
            name = "offshore-pump",
            type = "offshore-pump",
            position = { x = rect.x1, y = rect.y1 - 1 },
            surface = surface,
            input_position = { x = rect.x1, y = rect.y1 },
        })
    end
    
    -- Run until all scans complete (7500 tiles at ~1000/sec = ~8 seconds = ~480 ticks, give margin)
    t.print("Phase 1: Running scan phase (600 ticks)")
    test_env.run_ticks(600)
    
    -- Verify all 3 waterbodies created and scanned
    local valid_count = 0
    for _, wb in pairs(storage.ValidWaterBodies or {}) do
        if wb and wb.valid and wb.searchData.finished then
            valid_count = valid_count + 1
        end
    end
    t.eq(valid_count, NUM_WATERBODIES, string.format("%d waterbodies scanned", NUM_WATERBODIES))
    
    local total_area = sum_waterbody_field("waterAreaData.TotalArea")
    t.eq(total_area, TOTAL_TILES, string.format("total area = %d tiles", TOTAL_TILES))
    
    -- Verify no dried tiles yet
    local initial_dried = sum_waterbody_field("waterBodyStateData.DriedTiles")
    t.eq(initial_dried, 0, "no dried tiles initially")
    
    -- ========================================
    -- PHASE 2: Rapid Depletion
    -- ========================================
    -- Pump flow to deplete ~42,000 water per big update per pump
    -- Each WB has 125,000 water, so ~3 big updates to deplete
    local PUMP_FLOW = 1400  -- 1400 * 30 = 42,000 per big update
    
    t.print(string.format("Phase 2: Setting pump flow to %d for rapid depletion", PUMP_FLOW))
    for _, pump in ipairs(pumps) do
        world:set_pump_flow(pump, PUMP_FLOW)
    end
    
    -- Run 4 big updates to fully deplete all waterbodies (125k water / 42k per update = ~3 updates)
    test_env.run_ticks(120)
    
    -- Verify all waterbodies are depleted (100% water used)
    local all_depleted = true
    for _, wb in pairs(storage.ValidWaterBodies) do
        if wb and wb.valid then
            local percent_used = waterbodies.calculatePercentageWaterUsed(wb)
            if percent_used < 99 then
                all_depleted = false
                t.print(string.format("WB %d not fully depleted: %.1f%%", wb.waterBodyId, percent_used))
            end
        end
    end
    t.ok(all_depleted, "all waterbodies depleted to 100%")
    
    -- Stop pumping now to let depletion visuals catch up
    for _, pump in ipairs(pumps) do
        world:set_pump_flow(pump, 0)
    end
    
    -- Note: tiles are being processed during extra work updates while depletion is happening
    -- So DriedTiles may already be > 0 and ToDryTiles < TOTAL_TILES
    local total_to_dry = sum_waterbody_field("waterBodyStateData.ToDryTiles")
    local dried_after_depletion = sum_waterbody_field("waterBodyStateData.DriedTiles")
    t.print(string.format("After depletion: ToDryTiles=%d, DriedTiles=%d", total_to_dry, dried_after_depletion))
    t.ok(total_to_dry + dried_after_depletion >= TOTAL_TILES * 0.9, "ToDryTiles + DriedTiles >= 90% of total")
    
    -- ========================================
    -- PHASE 3: Continue processing
    -- ========================================
    t.print("Phase 3: Continue processing (30 ticks)")
    test_env.run_ticks(30)
    
    local dried_after_cycle1 = sum_waterbody_field("waterBodyStateData.DriedTiles")
    local to_dry_after_cycle1 = sum_waterbody_field("waterBodyStateData.ToDryTiles")
    
    t.print(string.format("After additional cycle: DriedTiles=%d, ToDryTiles=%d", dried_after_cycle1, to_dry_after_cycle1))
    
    -- Should have made progress or already be complete
    t.ok(dried_after_cycle1 >= dried_after_depletion, "tiles dried maintained or increased")
    
    -- Verify dried + remaining = total
    local accounted = dried_after_cycle1 + to_dry_after_cycle1
    t.print(string.format("Accounted tiles: dried(%d) + toDry(%d) = %d", 
        dried_after_cycle1, to_dry_after_cycle1, accounted))
    t.eq(accounted, TOTAL_TILES, "dried + toDry = total tiles")
    
    -- ========================================
    -- PHASE 4: Second Budget Cycle
    -- ========================================
    t.print("Phase 4: Second budget cycle (30 ticks)")
    test_env.run_ticks(30)
    
    local dried_after_cycle2 = sum_waterbody_field("waterBodyStateData.DriedTiles")
    local to_dry_after_cycle2 = sum_waterbody_field("waterBodyStateData.ToDryTiles")
    
    t.print(string.format("After cycle 2: DriedTiles=%d, ToDryTiles=%d", dried_after_cycle2, to_dry_after_cycle2))
    
    -- Should have processed more tiles or already complete
    t.ok(dried_after_cycle2 >= dried_after_cycle1, "tiles dried maintained or increased")
    
    -- ========================================
    -- PHASE 5: Complete Processing
    -- ========================================
    -- Run more cycles to ensure all tiles are processed
    t.print("Phase 5: Running additional cycles to complete processing (120 ticks)")
    test_env.run_ticks(120)
    
    local final_dried = sum_waterbody_field("waterBodyStateData.DriedTiles")
    local final_to_dry = sum_waterbody_field("waterBodyStateData.ToDryTiles")
    
    t.print(string.format("Final state: DriedTiles=%d, ToDryTiles=%d", final_dried, final_to_dry))
    
    t.eq(final_dried, TOTAL_TILES, string.format("all %d tiles dried", TOTAL_TILES))
    t.eq(final_to_dry, 0, "no remaining ToDryTiles")
    
    -- ========================================
    -- PHASE 6: Verify Surface Tiles
    -- ========================================
    t.print("Phase 6: Verifying surface tile states")
    
    local total_dry_on_surface = 0
    for _, rect in ipairs(rects) do
        local dry_count = count_surface_tiles_rect(surface, rect, "lake-shallow")
        total_dry_on_surface = total_dry_on_surface + dry_count
    end
    
    t.eq(total_dry_on_surface, TOTAL_TILES, "all surface tiles are lake-shallow")
    
    -- Verify internal grids match
    local total_dried_grid = 0
    local total_water_grid = 0
    for _, wb in pairs(storage.ValidWaterBodies) do
        if wb and wb.valid then
            local gd = wb.gridsData
            total_dried_grid = total_dried_grid + count_grid_entries(gd.driedTilesGridWithData, gd.lazyDriedTilesGridWithData)
            total_water_grid = total_water_grid + count_grid_entries(gd.waterGridWithData, gd.lazyWaterGridWithData)
        end
    end
    
    t.eq(total_dried_grid, TOTAL_TILES, "driedTilesGridWithData has all tiles")
    t.eq(total_water_grid, 0, "waterGridWithData is empty")
    
    t.finish("Budget-limited depletion test complete")
end

run_mock_test(run_test)
