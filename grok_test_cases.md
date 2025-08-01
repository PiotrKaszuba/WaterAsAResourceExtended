
# Grok's Test Cases for WaterAsAResourceExtended Mod

This document outlines a broad range of manual test cases to verify the mod's functionalities. Each case is designed for in-game testing: set up scenarios manually, perform actions, and check outputs via game prints, logs, or visual inspection. Use debug prints (e.g., from `game.print`) or enable mod settings for verbose logging if available. Test on a fresh map unless specified.

Cases cover core features like water body management, depletion, events, and edge cases. Run them in a controlled environment (e.g., creative mode for quick setup).

## 1. Water Body Creation and Scanning
### Test 1.1: Basic Water Body Creation
- **Setup**: Start a new game. Find or create (via waterfill) a small puddle (3-4 water tiles).
- **Steps**: Place a pump on the edge. Wait a few seconds for scanning.
- **Expected Outcome**: Print/log shows new water body created (e.g., "Puddle created with X L water"). Check via debug command if body appears in storage.

### Test 1.2: Large Body Scanning with Budget Limits
- **Setup**: Create a large ocean (~1000 tiles) via waterfill.
- **Steps**: Place a pump. Set low "Update-Budget-Per-Second" (e.g., 10). Monitor prints during scanning.
- **Expected Outcome**: Scanning continues over multiple ticks (prints like "Still Scanning FluidArea"). Eventually completes with full water amount; no crashes or infinite loops.

### Test 1.3: Scanning Interruption and Resumption
- **Setup**: Large water body as in 1.2.
- **Steps**: During scanning (watch for "Still Scanning" prints), save/load the game.
- **Expected Outcome**: Scanning resumes post-load without data loss; body fully scanned eventually.

## 2. Tile Events (Landfill/Waterfill)
### Test 2.1: Landfill on Water Body
- **Setup**: Small lake with pump.
- **Steps**: Landfill one tile in the middle, splitting it potentially.
- **Expected Outcome**: Print/log indicates split or reduction. Water amount decreases; pumps may disable if depleted.

### Test 2.2: Waterfill Extending Body
- **Setup**: Existing small puddle.
- **Steps**: Waterfill adjacent tiles to expand it.
- **Expected Outcome**: Body updates (print: updated water amount). Scanning extends without creating new body.

### Test 2.3: Mass Tile Changes
- **Setup**: Medium lake.
- **Steps**: Use a mod/tool to landfill/waterfill many tiles rapidly.
- **Expected Outcome**: Event queue processes without overflow (no infinite backlog); budgets defer excess work.

## 3. Pump and Entity Management
### Test 3.1: Pump Placement and Activation
- **Setup**: Valid water edge.
- **Steps**: Place pump. Connect to pipe and monitor.
- **Expected Outcome**: Pump activates, water flows. Stats collected per tick.

### Test 3.2: Pump on Depleted Body
- **Setup**: Deplete a body fully (pump until 100%).
- **Steps**: Place new pump.
- **Expected Outcome**: New pump disables immediately; print/log shows depletion.

### Test 3.3: Pump Teleportation (Mod Interaction)
- **Setup**: Install PickerDollies or similar. Place pump on water.
- **Steps**: Teleport pump to invalid position.
- **Expected Outcome**: Warning print ("a pump was teleported"), pump disabled and untracked.

## 4. Depletion and Regeneration
### Test 4.1: Gradual Depletion
- **Setup**: Small lake with pump.
- **Steps**: Pump continuously until 80%+ usage.
- **Expected Outcome**: Tiles visually dry (change to lake-shallow/deep). Alarms fire at thresholds (prints).

### Test 4.2: Regeneration Curve
- **Setup**: Deplete to 75%.
- **Steps**: Stop pumping, wait several updates.
- **Expected Outcome**: Regen peaks (faster recovery); percentage drops, visuals restore.

### Test 4.3: Hysteresis on Alarms
- **Setup**: Body near alarm threshold (e.g., 94-96%).
- **Steps**: Fluctuate usage slightly.
- **Expected Outcome**: Alarm triggers once, doesn't spam on minor drops (due to -1 buffer).

## 5. Merging and Splitting
### Test 5.1: Simple Merge
- **Setup**: Two separate small puddles.
- **Steps**: Waterfill to connect them.
- **Expected Outcome**: Print: bodies merged with combined water amount. Penalties inherited correctly.

### Test 5.2: Split with Penalties
- **Setup**: Deplete a medium body to 50%.
- **Steps**: Landfill to split into two.
- **Expected Outcome**: New bodies inherit proportional penalties (no free water); prints confirm split.

### Test 5.3: Merge with Depletion Visuals
- **Setup**: One depleted body (dry tiles), one fresh.
- **Steps**: Connect via waterfill.
- **Expected Outcome**: Merged body uses original wet names for calcs; visuals update based on new average depletion.

## 6. Forces and Tech Boosts
### Test 6.1: Yield Boost Application
- **Setup**: Research "waar-yield-boost-1".
- **Steps**: Place pump, compare usage before/after.
- **Expected Outcome**: Water usage reduced by multiplier (e.g., 85%); stats reflect this.

### Test 6.2: Infinite Research
- **Setup**: Research multiple levels beyond max (e.g., level 6+).
- **Steps**: Pump and check usage.
- **Expected Outcome**: Boost compounds correctly (e.g., 0.15 per extra level).

## 7. Orphan Cleanup
### Test 7.1: Basic Orphan Removal
- **Setup**: Create isolated puddle without pumps.
- **Steps**: Wait for cleanup delay (e.g., 300 ticks).
- **Expected Outcome**: Body removed from storage; optional print if named.

### Test 7.2: Orphan with Age Counter
- **Setup**: Puddle with pump, then remove pump.
- **Steps**: Wait partial delay, add/remove pump again.
- **Expected Outcome**: Counter resets on pump add; only removes after full age without pumps.

## 8. Edge Cases and Stress Tests
### Test 8.1: Infinite Ocean Handling
- **Setup**: Generate map with huge ocean (> max size).
- **Steps**: Place pumps, deplete partially.
- **Expected Outcome**: Scanning caps at max size; no crashes, warnings if over limit.

### Test 8.2: Rapid Event Flood
- **Setup**: Use script/mod to change 100+ tiles in one tick.
- **Steps**: Observe queue processing.
- **Expected Outcome**: Budgets handle it incrementally; no lag spikes or lost events.

### Test 8.3: Multiplayer Sync
- **Setup**: Host multiplayer game with 2+ players.
- **Steps**: One player landfills/splits, others observe.
- **Expected Outcome**: No desyncs; all see consistent bodies, alarms, visuals.

## Sophisticated Testing Methodologies
For more advanced testing beyond manual scenarios:
- **Automated Lua Scripts**: Use Factorio's console or a test mod to script setups (e.g., loop placing/landfilling tiles, assert water amounts via `storage` inspection). Example: `/c local wb = storage.WaterBodies[1]; assert(wb.waterAreaData.AmountWtr > 0, "Water body has zero water")`.
- **Unit Testing Framework**: Integrate a Lua testing lib (e.g., LuaUnit) into a separate test file. Mock Factorio APIs (e.g., fake `surface.get_tile`) to test isolated functions like `calculatePercentageWaterUsed`.
- **Profiling Tools**: Use Factorio's built-in profiler (`/c game.write_file("profile.json", serpent.block(game.get_profiling_data({})))`) to measure tick times during stress tests. Focus on hotspots like stats collection.
- **CI Integration**: Set up GitHub Actions to run headless Factorio instances with scripted tests on commits, verifying no regressions in key metrics (e.g., water calc accuracy).

Prioritize manual tests first, then automate repetitive ones for efficiency! 