local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local world_mod = require("tests.mock.world")

t.start()

-- Execute the real data-stage entry point with only its dependencies stubbed.
local function check_data_stage(enabled, canal_active, expected)
    local required = {}
    local data_fixture = { raw = { tile = { ["sand-3"] = {}, ["dry-dirt"] = {} } } }
    function data_fixture:extend(prototypes)
        t.eq(#prototypes, 2, "dry tile prototypes remain available")
    end
    local fixture = {
        settings = { startup = { ["Enable-Waterfill"] = { value = enabled } } },
        mods = canal_active and { CanalBuilderMAV = "3.0.0" } or {},
        require = function(name) required[name] = true end,
        table = { deepcopy = function(value)
            local copy = {}
            for key, item in pairs(value) do copy[key] = item end
            return copy
        end },
        data = data_fixture,
    }
    assert(loadfile("data.lua", "t", fixture))()
    t.eq(required["prototypes.waterfill"] == true, expected,
        "waterfill prototypes: setting=" .. tostring(enabled) .. ", Canal=" .. tostring(canal_active))
    t.eq(required["prototypes.technology"], true, "yield research remains available")
end

check_data_stage(true, false, true)
check_data_stage(false, false, false)
check_data_stage(true, true, false)
check_data_stage(false, true, false)

local function check_runtime(enabled, canal_active)
    env.reset_world()
    settings.startup["Enable-Waterfill"].value = enabled
    script.active_mods = canal_active and { CanalBuilderMAV = "3.0.0" } or {}
    local world = world_mod.World.new()
    local surface = world:create_surface("nauvis")

    -- Disabled prototypes must not be named in cleanup queries. Canal's shared
    -- placer can remain in the prototype registry, but it is not ours to delete.
    local find_entities_filtered = surface.find_entities_filtered
    surface.find_entities_filtered = function(filter)
        assert(filter.name == nil, "unexpected name-based prototype cleanup")
        return find_entities_filtered(filter)
    end
    game.players[1] = {
        remove_item = function() error("unexpected player inventory cleanup") end,
    }
    require("control")
    local init_ok, init_err = pcall(mock.on_init)
    t.ok(init_ok, "init without artifact cleanup: " .. tostring(init_err))
    local change_ok, change_err = pcall(control.VersionChanged, {
        mod_changes = { WaterAsAResourceExtended = { old_version = "2.0.3", new_version = "2.0.4" } },
    })
    t.ok(change_ok, "configuration change without artifact cleanup: " .. tostring(change_err))

    local placer_calls, pump_calls = 0, 0
    event_handlers.waterfill_placer_handlers.built = function() placer_calls = placer_calls + 1 end
    event_handlers.offshore_pump_handlers.built = function() pump_calls = pump_calls + 1 end
    for _, name in ipairs({ "waterfill-placer", "waterfill-placer-deep" }) do
        event_handlers.BuiltEntity({ entity = {
            valid = true, name = name, prototype = { type = "offshore-pump" },
        } })
    end
    t.eq(placer_calls, enabled and not canal_active and 2 or 0,
        "only enabled built-in placers use waterfill handler")
    t.eq(pump_calls, 0, "known placers never fall through to pump handler")
    event_handlers.BuiltEntity({ entity = {
        valid = true, name = "offshore-pump", prototype = { type = "offshore-pump" },
    } })
    t.eq(pump_calls, 1, "normal offshore pumps retain their handler")

    local invalid_entity = setmetatable({ valid = false }, {
        __index = function(_, key) error("access to invalid entity field " .. key) end,
    })
    local invalid_ok = pcall(event_handlers.BuiltEntity, { entity = invalid_entity })
    t.ok(invalid_ok, "entity destroyed by another mod is ignored")
    t.ok(pcall(event_handlers.BuiltEntity, {}), "missing event entity is ignored")
end

check_runtime(true, false)
check_runtime(false, false)
check_runtime(true, true)
check_runtime(false, true)

t.finish("Waterfill startup toggle")
