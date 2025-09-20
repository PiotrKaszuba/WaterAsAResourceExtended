local mock = require("tests.mock.factorio_runtime")
local world_mod = require("tests.mock.world")

local test_env = {}

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
        ["Alarms-Low-Level"] = true,
        ["Alarms-High-Level"] = true,
        ["Alarms-Tile-Message"] = true,
        ["FluidArea-Start-Area"] = 50,
        ["FluidArea-Additional-Tiles-Per-Second"] = 1000,
        ["FluidArea-MaxFluidAreaSize"] = 0,
        ["FluidArea-Scanning-Loop-Period"] = 20,
        ["TileFluidAmount-Shallow"] = 50,
        ["TileFluidAmount-Deep"] = 150,
        ["FluidArea-RegenRate"] = 100,
        ["WaterBody-Centroid-Shift-Threshold"] = 0.025,
        ["Visual-Depletion-Start-Percentage"] = 80,
        ["Pumps-Reactivation-LevelPerThousand"] = 990,
        ["FluidArea-RemoveDepletedOrphaned"] = true,
        ["Map-EnableMarkers"] = true,
        ["Update-Budget-Per-Second"] = 2000,
        ["Split-Max-BBox-Side"] = 32,
        ["Split-Max-Adjacent-Landfill-Depth-Check"] = 16,
        ["Split-Finalize-Max-Landfills-Per-Update"] = 100,
    }
    local startup_defaults = {
        ["WaterBody-Regen-Scaling"] = 1.5,
    }

    for name, value in pairs(global_defaults) do
        settings.global[name] = {value = value}
    end
    for name, value in pairs(startup_defaults) do
        settings.startup[name] = {value = value}
    end
end

function test_env.reset_world()
    mock.reset()
    for _, m in ipairs(modules_to_reset) do
        package.loaded[m] = nil
    end
    load_default_settings()
end

function test_env.create_world(world_options, surface_options)
    test_env.reset_world()
    local world = world_mod.World.new(world_options)
    local surface = world:create_surface("nauvis", nil, surface_options)
    require("control")
    mock.on_init()
    return world, surface
end

function test_env.run_ticks(n)
    mock.run_ticks(n)
end

return test_env

