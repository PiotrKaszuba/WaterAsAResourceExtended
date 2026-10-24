local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local world_mod = require("tests.mock.world")

t.start()

-- Check the actual setting definition, not a second copy of its defaults.
local definitions = {}
local settings_fixture = { data = { extend = function(_, values)
    for _, value in ipairs(values) do definitions[value.name] = value end
end } }
assert(loadfile("settings.lua", "t", settings_fixture))()
local setting = definitions["Enable-Waterfill"]
t.ok(setting ~= nil, "Enable Waterfill is defined")
t.eq(setting.type, "bool-setting", "waterfill switch is boolean")
t.eq(setting.setting_type, "startup", "waterfill switch is startup-only")
t.eq(setting.default_value, true, "waterfill remains enabled by default")

local function deepcopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = deepcopy(item) end
    return copy
end

local function check_data_stage(enabled)
    local required = {}
    local data_fixture = { raw = {
        tile = {
            ["sand-3"] = { type = "tile" },
            ["dry-dirt"] = { type = "tile" },
            ["water-shallow"] = { collision_mask = { layers = {} } },
        },
        item = { landfill = { subgroup = "terrain", order = "a", place_as_tile = {
            condition = { layers = { ground_tile = true, object = true } },
            tile_condition = { "water", "deepwater", "custom-water" },
        } } },
    } }
    function data_fixture:extend(values)
        for _, value in ipairs(values) do
            self.raw[value.type] = self.raw[value.type] or {}
            self.raw[value.type][value.name] = value
        end
    end
    local startup = {}
    for name, definition in pairs(definitions) do
        if definition.setting_type == "startup" then
            startup[name] = { value = definition.default_value }
        end
    end
    startup["Enable-Waterfill"].value = enabled
    local fixture = {
        settings = { startup = startup },
        math = math,
        ipairs = ipairs,
        -- A generic switch must not inspect which other mods are present.
        mods = setmetatable({}, { __index = function() error("unexpected mod detection") end }),
        table = { deepcopy = deepcopy },
        data = data_fixture,
    }
    fixture.require = function(name)
        required[name] = true
        if name == "prototypes.waterfill" then
            assert(loadfile("prototypes/waterfill.lua", "t", fixture))()
        elseif name == "modules.water_tiles" then
            return assert(loadfile("modules/water_tiles.lua", "t", {}))()
        end
    end
    assert(loadfile("data.lua", "t", fixture))()
    for _, prototype in ipairs({
        { "technology", "waterfill-tech" },
        { "recipe", "waterfill-recipe" },
        { "item", "waterfill" },
        { "offshore-pump", "waterfill-placer" },
    }) do
        local group = data_fixture.raw[prototype[1]] or {}
        t.eq(group[prototype[2]] ~= nil, enabled,
            prototype[2] .. " availability follows startup setting")
    end
    t.eq(required["prototypes.technology"], true, "yield research remains loaded")
    t.ok(data_fixture.raw.tile["lake-shallow"] ~= nil, "shallow dry terrain remains defined")
    t.ok(data_fixture.raw.tile["lake-deep"] ~= nil, "deep dry terrain remains defined")
    local allowed = {}
    for _, name in ipairs(data_fixture.raw.item.landfill.place_as_tile.tile_condition) do allowed[name] = true end
    for _, identity in ipairs(require("modules.water_tiles")) do
        t.ok(data_fixture.raw.tile[identity.dry] ~= nil, "typed dry terrain is defined: " .. identity.wet)
        t.eq(allowed[identity.dry], true, "landfill supports typed dry terrain: " .. identity.wet)
    end
    t.eq(allowed["custom-water"], true, "landfill keeps another mod's whitelist entry")
    t.eq(data_fixture.raw.item.landfill.place_as_tile.condition.layers.object, true, "landfill keeps unrelated collision restrictions")
    t.eq(data_fixture.raw.item.landfill.place_as_tile.condition.layers.ground_tile, nil, "landfill can reach whitelisted dry ground")
end

local function check_tile_tracking(enabled)
    env.reset_world()
    settings.startup["Enable-Waterfill"].value = enabled
    local world = world_mod.World.new()
    local surface = world:create_surface("nauvis")
    require("control")
    mock.on_init()
    control.VersionChanged({
        mod_changes = { WaterAsAResourceExtended = { old_version = "2.0.3", new_version = "2.0.4" } },
    })
    local queue = tiles.getTileEventQueue()
    local initial_size = queue.size
    mock.raise_event(defines.events.on_player_built_tile, {
        surface_index = surface.index,
        tile = { name = "landfill" },
        tiles = { { position = { x = 0, y = 0 }, old_tile = { name = "water" } } },
    })
    t.eq(queue.size, initial_size + 1, "player tile events remain tracked: " .. tostring(enabled))
    mock.raise_event(defines.events.script_raised_set_tiles, {
        surface_index = surface.index,
        tiles = { { name = "water-shallow", position = { x = 1, y = 0 }, old_tile = { name = "landfill" } } },
    })
    t.eq(queue.size, initial_size + 2, "announced script tile events remain tracked: " .. tostring(enabled))
end

check_data_stage(true)
check_data_stage(false)
check_tile_tracking(true)
check_tile_tracking(false)
t.finish("Generic waterfill startup toggle")
