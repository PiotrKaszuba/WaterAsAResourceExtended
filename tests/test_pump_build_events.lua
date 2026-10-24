local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 8, y2 = 0 })
local blacklist = {}
remote.interfaces.PickerDollies = { add_blacklist_name = true }
remote.call = function(interface, method, name)
    t.eq(interface, "PickerDollies", "uses existing Dolly interface")
    t.eq(method, "add_blacklist_name", "blacklists by prototype name")
    blacklist[name] = true
end
local source
for i, event_id in ipairs({ defines.events.script_raised_built,
    defines.events.script_raised_revive, defines.events.on_entity_cloned }) do
    local pump = world:add_existing_entity({ name = i == 1 and "burner-offshore-pump" or "electric-offshore-pump",
        type = "offshore-pump", surface = surface, position = { x = i, y = -1 },
        input_position = { x = i, y = 0 } })
    local event = event_id == defines.events.on_entity_cloned and { destination = pump, source = source } or { entity = pump }
    mock.raise_event(event_id, event)
    mock.raise_event(event_id, event)
    t.ok(entities.getTrackedEntity(pump.unit_number) ~= nil, "event registers pump " .. i)
    source = pump
end
env.run_ticks(120)
t.eq(#storage.WaterBodies[1].waterBodyStateData.Pumps, 3, "duplicate events do not duplicate lake membership")
t.ok(blacklist["burner-offshore-pump"], "burner variant movement blocked")
t.ok(blacklist["electric-offshore-pump"], "electric variant movement blocked")
blacklist = {}
control.VersionChanged({ mod_changes = {} })
t.ok(blacklist["burner-offshore-pump"], "blacklist refreshed when configuration changes")
local invalid = setmetatable({ valid = false }, { __index = function() error("invalid object accessed") end })
t.ok(pcall(mock.raise_event, defines.events.script_raised_built, { entity = invalid }), "consumed script-built entity is ignored")
t.finish("Pump script and clone events")
