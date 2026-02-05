if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local mock = require("tests.mock.factorio_runtime")
local world_mod = require("tests.mock.world")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

-- Helper to reset and load settings without calling on_init
local modules_to_reset = {
    "control",
    "modules.utils",
    "modules.waterbodies",
    "modules.entities",
    "modules.forces",
    "modules.tiles",
    "modules.waterbody_update",
    "modules.waterbody_scan",
    "modules.event_handlers",
    "modules.split_families",
}

local function load_default_settings()
    local global_defaults = {
        ["Alarm-Depletion-Level"] = "all",
        ["Alarms-Tile-Message"] = true,
        ["Scan-Instant-Tiles"] = 50,
        ["Scan-Tiles-Per-Second"] = 1000,
        ["Scan-Status-Period"] = 20,
        ["Waterbody-Max-Size"] = 0,
        ["Waterbody-Regen-Rate"] = 100,
        ["WaterBody-Centroid-Shift-Threshold"] = 0.025,
        ["Visual-Depletion-Start-Percentage"] = 80,
        ["Visual-Depletion-Furthest-First"] = true,
        ["Pumps-Reactivation-LevelPerThousand"] = 990,
        ["Cleanup-Remove-Depleted-Orphaned"] = true,
        ["Map-EnableMarkers"] = true,
        ["Update-Budget-Per-Second"] = 2000,
        ["Split-Max-BBox-Side"] = 32,
        ["Split-Max-Adjacent-Landfill-Depth-Check"] = 16,
        ["Split-Finalize-Max-Landfills-Per-Update"] = 100,
    }
    local startup_defaults = {
        ["TileFluidAmount-Shallow"] = 50,
        ["TileFluidAmount-Deep"] = 150,
        ["WaterBody-Regen-Scaling"] = 1.5,
    }

    for name, value in pairs(global_defaults) do
        settings.global[name] = { value = value }
    end
    for name, value in pairs(startup_defaults) do
        settings.startup[name] = { value = value }
    end
end

local function run_test()
    t.start()

    -- Step 1: Reset mock environment but don't call on_init yet
    mock.reset()
    for _, m in ipairs(modules_to_reset) do
        package.loaded[m] = nil
    end
    load_default_settings()

    -- Step 2: Create world and surface
    local world = world_mod.World.new()
    local surface = world:create_surface("nauvis")

    -- Step 3: Set up water tiles
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 2, y2 = 2 })

    -- Step 4: Add existing pumps WITHOUT raising events (simulating pumps in a save)
    local existing_pump1 = world:add_existing_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 0, y = -1 },
        surface = surface,
        input_position = { x = 0, y = 0 },
    })

    local existing_pump2 = world:add_existing_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 2, y = -1 },
        surface = surface,
        input_position = { x = 2, y = 0 },
    })

    t.ok(existing_pump1 ~= nil, "existing pump 1 created")
    t.ok(existing_pump2 ~= nil, "existing pump 2 created")

    -- Verify pumps are in surface.entities but NOT tracked yet
    local found_pumps = surface.find_entities_filtered({ type = "offshore-pump" })
    t.eq(#found_pumps, 2, "found 2 existing pumps on surface before init")

    -- Verify pumps are NOT tracked before on_init is called
    t.ok(storage.TrackedEntities == nil, "TrackedEntities not initialized before on_init")

    -- Step 5: Now load control and call on_init (this should scan for existing pumps)
    require("control")

    -- Verify pumps are still NOT tracked after loading control but before on_init
    t.ok(storage.TrackedEntities == nil, "TrackedEntities still nil after require but before on_init")
    mock.on_init()

    -- Step 6: Verify pumps are now tracked
    t.ok(storage.TrackedEntities ~= nil, "TrackedEntities initialized")

    local tracked_pump1 = storage.TrackedEntities[existing_pump1.unit_number]
    local tracked_pump2 = storage.TrackedEntities[existing_pump2.unit_number]

    t.ok(tracked_pump1 ~= nil, "existing pump 1 is now tracked")
    t.ok(tracked_pump2 ~= nil, "existing pump 2 is now tracked")

    if tracked_pump1 then
        t.eq(tracked_pump1.type, "pump", "tracked pump 1 has correct type")
        t.ok(tracked_pump1.waterBodyId ~= nil, "tracked pump 1 has waterBodyId assigned")
    end

    if tracked_pump2 then
        t.eq(tracked_pump2.type, "pump", "tracked pump 2 has correct type")
        t.ok(tracked_pump2.waterBodyId ~= nil, "tracked pump 2 has waterBodyId assigned")
    end

    -- Step 7: Verify water bodies were created
    t.ok(storage.WaterBodies ~= nil, "WaterBodies initialized")

    local waterbody_count = 0
    for _ in pairs(storage.WaterBodies) do
        waterbody_count = waterbody_count + 1
    end
    t.ok(waterbody_count >= 1, "at least one water body created for existing pumps")

    -- Step 8: Run some ticks to let scanning complete
    mock.run_ticks(120)

    -- Verify water body has pumps registered
    local wbody = storage.WaterBodies[tracked_pump1.waterBodyId]
    if wbody then
        t.ok(#wbody.waterBodyStateData.Pumps >= 1, "water body has pumps registered")
    end

    t.finish("Existing pumps scan tests complete")
end

run_mock_test(run_test)
