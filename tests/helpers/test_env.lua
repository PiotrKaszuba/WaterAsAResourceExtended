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
    local defaults = {
        ["Alarms-Low-Level"] = true,
        ["Alarms-High-Level"] = true,
        ["Alarms-Tile-Message"] = true,
        ["FluidArea-Start-Area"] = 50,
        ["FluidArea-Additional-Tiles-Per-Second"] = 200,
        ["TileFluidAmount-Shallow"] = 50,
        ["TileFluidAmount-Deep"] = 150,
        ["FluidArea-RegenRate"] = 100,
        ["Visual-Depletion-Start-Percentage"] = 80,
        ["Pumps-Reactivation-LevelPerThousand"] = 990,
        ["FluidArea-RemoveDepletedOrphaned"] = true,
        ["Map-EnableMarkers"] = false,
        ["FluidArea-MaxFluidAreaSize"] = 2000000,
        ["Update-Budget-Per-Second"] = 200,
        ["Splits-EnableFamilies"] = true,
        ["Splits-Family-Timeout-Seconds"] = 120,
        ["Splits-Reeval-Threshold"] = 0.10,
        ["Split-Max-BBox-Side"] = 32,
    }
    for name, value in pairs(defaults) do
        settings.global[name] = {value = value}
    end
end

function test_env.reset_world()
    mock.reset()
    for _, m in ipairs(modules_to_reset) do
        package.loaded[m] = nil
    end
    load_default_settings()
end

function test_env.create_world()
    test_env.reset_world()
    local world = world_mod.World.new()
    local surface = world:create_surface("nauvis")
    require("control")
    mock.on_init()
    return world, surface
end

function test_env.run_ticks(n)
    mock.run_ticks(n)
end

return test_env

