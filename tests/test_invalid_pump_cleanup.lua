local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 2, y2 = 0 })
local pump = world:build_entity({ name = "offshore-pump", type = "offshore-pump",
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 }, surface = surface })
env.run_ticks(120)
local tracked = entities.getTrackedEntity(pump.unit_number)
local body = waterbodies.getWaterBody(tracked.waterBodyId)
tracked.entity = setmetatable({ valid = false }, {
    __index = function(_, key) error("invalid entity read: " .. key) end,
    __newindex = function(_, key) error("invalid entity write: " .. key) end,
})
local ok, err = pcall(entities.updatePumpStates)
t.ok(ok, "stale pump cleanup does not access invalid entity: " .. tostring(err))
t.eq(entities.getTrackedEntity(pump.unit_number), nil, "stale tracking removed")
t.eq(#body.waterBodyStateData.Pumps, 0, "stale waterbody membership removed")
t.eq(body.waterBodyStateData.Forces.player, nil, "empty force membership removed")
t.finish("Invalid pump cleanup")
