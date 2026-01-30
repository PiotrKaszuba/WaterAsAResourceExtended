if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

--[[
Technology Unlock Test

Tests that water_usage_multiplier is correctly updated when technologies are researched,
and verifies the multiplier affects water consumption calculations.

Technology levels (from forces.lua):
- Level 1: 0.85^1 = 0.85
- Level 2: 0.85^2 = 0.7225  
- Level 3: 0.85^3 = 0.614125
]]

local function run_test()
    t.start()
    
    -- ========================================
    -- PHASE 1: Setup and Scan
    -- ========================================
    local world, surface = test_env.create_world()
    
    -- Create 10x1 water rectangle (500 water total)
    local water_rect = { x1 = 0, y1 = 0, x2 = 9, y2 = 0 }
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
        t.finish("Tech unlock test aborted - no water body")
        return
    end
    
    -- Verify initial state
    t.eq(wbody.waterAreaData.TotalArea, 10, "total area is 10")
    t.eq(wbody.waterAreaData.AmountWtr, 500, "water amount is 500")
    
    local state = wbody.waterBodyStateData
    t.eq(state.WaterUsed, 0, "no water used initially")
    
    -- ========================================
    -- PHASE 2: Verify initial multiplier
    -- ========================================
    t.print("Phase 2: Verifying initial multiplier")
    
    local player_force = storage.PlayerForces and storage.PlayerForces["player"]
    t.ok(player_force ~= nil, "player force exists")
    
    local initial_multiplier = player_force.water_usage_multiplier
    t.eq(initial_multiplier, 1.0, "initial multiplier is 1.0")
    
    -- ========================================
    -- PHASE 3: Unlock tech-1
    -- ========================================
    t.print("Phase 3: Unlocking waar-yield-boost-1")
    
    world:complete_research("waar-yield-boost-1", 1)
    
    local mult_after_tech1 = storage.PlayerForces["player"].water_usage_multiplier
    t.print(string.format("Multiplier after tech-1: %.4f (expected 0.85)", mult_after_tech1))
    t.ok(math.abs(mult_after_tech1 - 0.85) < 0.001, "multiplier is 0.85 after tech-1")
    
    -- ========================================
    -- PHASE 4: Unlock tech-2
    -- ========================================
    t.print("Phase 4: Unlocking waar-yield-boost-2")
    
    world:complete_research("waar-yield-boost-2", 1)
    
    local mult_after_tech2 = storage.PlayerForces["player"].water_usage_multiplier
    local expected_mult2 = 0.85 * 0.85  -- 0.7225
    t.print(string.format("Multiplier after tech-2: %.4f (expected %.4f)", mult_after_tech2, expected_mult2))
    t.ok(math.abs(mult_after_tech2 - expected_mult2) < 0.001, "multiplier is 0.7225 after tech-2")
    
    -- ========================================
    -- PHASE 5: Unlock tech-3
    -- ========================================
    t.print("Phase 5: Unlocking waar-yield-boost-3")
    
    world:complete_research("waar-yield-boost-3", 1)
    
    local mult_after_tech3 = storage.PlayerForces["player"].water_usage_multiplier
    local expected_mult3 = 0.85 * 0.85 * 0.85  -- 0.614125
    t.print(string.format("Multiplier after tech-3: %.4f (expected %.4f)", mult_after_tech3, expected_mult3))
    t.ok(math.abs(mult_after_tech3 - expected_mult3) < 0.001, "multiplier is 0.614 after tech-3")
    
    -- ========================================
    -- PHASE 6: Verify water usage with multiplier
    -- ========================================
    t.print("Phase 6: Verifying water usage affected by multiplier")
    
    -- Run exactly 30 ticks (1 full big update cycle) with pump active
    -- This ensures we get exactly 1 big update processing water usage
    world:set_pump_flow(pump, 10)  -- 10 water per tick
    
    -- Align to next big update boundary - current periodicTick should be ~120
    -- Run 30 ticks to trigger big update at periodicTick 150
    test_env.run_ticks(30)
    
    -- With multiplier = 0.614, expected water = 30 ticks * 10 flow * 0.614 = 184.2
    -- But big update alignment means we might not capture exactly 30 ticks
    local water_used = state.WaterUsed
    t.print(string.format("Water used after 30 ticks with mult=0.614: %.2f", water_used))
    t.ok(water_used > 0, "water is being consumed")
    
    -- Run another 30 ticks
    local water_before = state.WaterUsed
    test_env.run_ticks(30)
    local water_after = state.WaterUsed
    local water_added = water_after - water_before
    
    -- Expected: 30 * 10 * 0.614 = 184.2 (but regen reduces this slightly)
    local expected_water = 30 * 10 * expected_mult3
    t.print(string.format("Water added in 30 ticks: %.2f (expected ~%.2f with mult=%.4f)", 
        water_added, expected_water, expected_mult3))
    t.ok(math.abs(water_added - expected_water) < 20, "water usage matches multiplier")
    
    -- ========================================
    -- PHASE 7: Compare to baseline (no tech)
    -- ========================================
    t.print("Phase 7: Comparison test - reset and run without tech")
    
    -- We can't easily reset, but we can verify the ratio
    -- With tech-3 (mult=0.614), water used should be about 61% of what it would be without tech
    -- The current water_added should reflect this reduction
    local baseline_water = 30 * 10  -- without tech: 300 per 30 ticks
    local ratio = water_added / baseline_water
    t.print(string.format("Ratio of actual/baseline: %.4f (expected ~%.4f)", ratio, expected_mult3))
    t.ok(math.abs(ratio - expected_mult3) < 0.1, "water usage ratio matches tech multiplier")
    
    t.finish("Technology unlock test complete")
end

run_mock_test(run_test)
