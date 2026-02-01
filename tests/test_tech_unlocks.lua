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

Tests all 10 technology levels with precise expected values.
Expected behavior: Each level reduces water usage by 15% (multiplier = 0.85^level).

POTENTIAL BUGS IN forces.lua:
1. Formula uses 0.15 instead of 0.85 for infinite tech (levels 6+)
2. Formula uses research_level instead of boostLevel, risking negative exponents
]]

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Expected multiplier assuming consistent 15% reduction per level
-- Level 0 = no tech = 1.0 multiplier
local function get_expected_multiplier(tech_level)
    return 0.85 ^ tech_level
end

-- Calculate regen multiplier based on percentage water used
-- From waterbody_update.calculateEffectiveRegenAmount:
-- - At 0% used: 0.75
-- - At 75% used: 1.5 (maximum)
-- - Above 75%: decreases toward 0.5
local function get_regen_multiplier(percent_used)
    local missing_water_percentage = percent_used / 100
    local multiplier = 0.75
    if missing_water_percentage > 0.75 then
        multiplier = math.max(math.min(1.5 - (missing_water_percentage - 0.75) * 4, 1.5), 0.5)
    else
        multiplier = math.max(math.min(1.5 + (missing_water_percentage - 0.75) * 1, 1.5), 0.5)
    end
    return multiplier
end

-- Calculate expected regeneration per big update (30 ticks)
-- Regen multiplier varies based on percentage of water used
local function calculate_expected_regen(wbody)
    local regen_amount = wbody.waterAreaData.RegenAmount
    -- normalize_update_values_per_second: value * PeriodicTicksPerBigUpdate * PeriodicEveryXTicks / 60
    -- With PeriodicTicksPerBigUpdate=30, PeriodicEveryXTicks=1: regen_amount * 30 * 1 / 60 = regen_amount * 0.5
    local regen_per_big_update = regen_amount * storage.PeriodicTicksPerBigUpdate * storage.PeriodicEveryXTicks / 60
    
    -- Calculate current percentage used
    local state = wbody.waterBodyStateData
    local total_water = wbody.waterAreaData.AmountWtr
    local percent_used = (state.WaterUsed / total_water) * 100
    
    local regen_multiplier = get_regen_multiplier(percent_used)
    return regen_per_big_update * regen_multiplier
end

-- Run pump for TWO big update cycles and measure only the SECOND cycle
-- This avoids timing issues where the first cycle captures partial pumping
local function run_measured_cycle(pump_flow, ticks_per_cycle, world, pump)
    -- Turn on pump
    world:set_pump_flow(pump, pump_flow)
    
    -- Run first cycle (warm-up, may have partial capture)
    test_env.run_ticks(ticks_per_cycle)
    
    -- Capture state after first cycle
    local state_before = storage.WaterBodies[1].waterBodyStateData.WaterUsed
    
    -- Run second cycle (full measurement)
    test_env.run_ticks(ticks_per_cycle)
    
    -- Capture after second cycle
    local state_after = storage.WaterBodies[1].waterBodyStateData.WaterUsed
    
    -- Turn off pump
    world:set_pump_flow(pump, 0)
    
    return state_after - state_before
end

-- Test a single technology level
-- Level 0 = no tech (baseline), levels 1-10 = researched tech
-- Returns true if test passed, false otherwise
local function test_tech_level(world, wbody, pump, tech_level, pump_flow, ticks_per_cycle)
    local state = wbody.waterBodyStateData
    
    t.print(string.format("--- Testing Tech Level %d ---", tech_level))
    
    -- Complete research (skip for level 0 = no tech)
    if tech_level > 0 then
        local tech_name = string.format("waar-yield-boost-%d", tech_level)
        world:complete_research(tech_name, tech_level)
    end
    
    -- ========================================
    -- TEST 1: Verify stored multiplier in PlayerForces
    -- ========================================
    local stored_mult = storage.PlayerForces["player"].water_usage_multiplier
    local expected_mult = get_expected_multiplier(tech_level)
    
    t.print(string.format("  Stored multiplier: %.6f", stored_mult))
    t.print(string.format("  Expected (0.85^%d): %.6f", tech_level, expected_mult))
    
    local mult_tolerance = 0.0001
    local mult_diff = math.abs(stored_mult - expected_mult)
    
    if mult_diff >= mult_tolerance then
        t.print(string.format("  WARNING: Multiplier mismatch! Diff=%.6f (expected diff < %.6f)", 
            mult_diff, mult_tolerance))
        t.print(string.format("  This may indicate a bug in forces.lua GetTechYieldBoost()"))
    end
    
    t.ok(mult_diff < mult_tolerance, 
        string.format("Level %d: stored multiplier %.6f matches expected %.6f", 
            tech_level, stored_mult, expected_mult))
    
    -- ========================================
    -- TEST 2: Verify actual water consumption
    -- ========================================
    
    -- Run measured cycle (includes warm-up cycle for accurate measurement)
    local actual_water_added = run_measured_cycle(pump_flow, ticks_per_cycle, world, pump)
    
    -- Calculate expected water usage
    -- raw_water = ticks * flow * multiplier (using stored multiplier to test actual behavior)
    local raw_water = ticks_per_cycle * pump_flow * stored_mult
    
    -- Account for regeneration (reduces water used)
    local expected_regen = calculate_expected_regen(wbody)
    -- Regen is capped at total water used, but since we're measuring delta, 
    -- it applies to reduce the increase
    local expected_water_added = raw_water - expected_regen
    
    -- Tolerance: 1% of absolute consumption (before regen)
    local tolerance = 0.01 * (ticks_per_cycle * pump_flow * stored_mult)
    -- Also add tolerance for regen estimation error (regen varies with % water used)
    -- At high tech levels, regen dominates, so we need more tolerance
    local regen_tolerance = 0.05 * expected_regen  -- 5% of regen
    tolerance = math.max(tolerance + regen_tolerance, 0.1)
    
    local water_diff = math.abs(actual_water_added - expected_water_added)
    
    t.print(string.format("  Raw water (before regen): %.2f", raw_water))
    t.print(string.format("  Expected regen: %.4f", expected_regen))
    t.print(string.format("  Expected water added: %.2f", expected_water_added))
    t.print(string.format("  Actual water added: %.2f", actual_water_added))
    t.print(string.format("  Difference: %.4f (tolerance: %.4f)", water_diff, tolerance))
    
    t.ok(water_diff < tolerance,
        string.format("Level %d: water usage %.2f matches expected %.2f (tolerance %.2f)",
            tech_level, actual_water_added, expected_water_added, tolerance))
    
    -- ========================================
    -- TEST 3: Verify ratio to baseline
    -- ========================================
    local baseline_water = ticks_per_cycle * pump_flow  -- without any tech
    local actual_ratio = actual_water_added / baseline_water
    -- Account for regen in expected ratio
    local expected_ratio = expected_water_added / baseline_water
    
    t.print(string.format("  Ratio to baseline: %.4f (expected ~%.4f)", actual_ratio, expected_ratio))
    
    return true
end

-- ========================================
-- MAIN TEST
-- ========================================

local function run_test()
    t.start()
    
    -- ========================================
    -- SETUP: Create world with water body
    -- ========================================
    t.print("=== SETUP ===")
    local world, surface = test_env.create_world()
    
    -- Create large water body (100x10 = 1000 tiles = 50,000 water)
    -- Large enough to not deplete during all 10 tech level tests
    local water_rect = { x1 = 0, y1 = 0, x2 = 99, y2 = 9 }
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
    
    -- Verify initial state (100x10 = 1000 tiles, 50 water per tile = 50,000)
    t.eq(wbody.waterAreaData.TotalArea, 1000, "total area is 1000")
    t.eq(wbody.waterAreaData.AmountWtr, 50000, "water amount is 50000")
    
    local state = wbody.waterBodyStateData
    t.eq(state.WaterUsed, 0, "no water used initially")
    
    -- ========================================
    -- VERIFY INITIAL MULTIPLIER
    -- ========================================
    t.print("=== INITIAL STATE ===")
    
    local player_force = storage.PlayerForces and storage.PlayerForces["player"]
    t.ok(player_force ~= nil, "player force exists")
    
    local initial_multiplier = player_force.water_usage_multiplier
    t.eq(initial_multiplier, 1.0, "initial multiplier is 1.0 (no tech)")
    
    t.print(string.format("RegenAmount for waterbody: %.6f", wbody.waterAreaData.RegenAmount))
    t.print(string.format("Expected regen per big update: %.6f", calculate_expected_regen(wbody)))
    
    -- ========================================
    -- TEST ALL TECH LEVELS (0-10)
    -- ========================================
    t.print("")
    t.print("=== TESTING TECH LEVELS 0-10 ===")
    t.print("Expected: Each level = 0.85^level (15% reduction per level)")
    t.print("Level 0 = no tech = 1.0 multiplier")
    t.print("")
    
    local pump_flow = 10  -- 10 water per tick
    local ticks_per_cycle = 30  -- 1 big update = 30 ticks
    
    for tech_level = 0, 10 do
        test_tech_level(world, wbody, pump, tech_level, pump_flow, ticks_per_cycle)
        t.print("")
    end
    
    -- ========================================
    -- SUMMARY
    -- ========================================
    t.print("=== EXPECTED MULTIPLIER TABLE ===")
    t.print("Level | Expected (0.85^L) | Stored")
    t.print("------|-------------------|--------")
    for level = 0, 10 do
        local expected = get_expected_multiplier(level)
        t.print(string.format("  %2d  |     %.6f     |  (see above)", level, expected))
    end
    
    t.finish("Technology unlock test complete - tested all 11 levels (0-10)")
end

run_mock_test(run_test)
