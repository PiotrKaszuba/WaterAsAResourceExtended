local env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 5, y2 = 0 })
local pumps = {}
for i, name in ipairs({ "offshore-pump", "burner-offshore-pump", "electric-offshore-pump" }) do
    local pump = world:build_entity({ name = name, type = "offshore-pump", surface = surface,
        position = { x = i - 1, y = -1 }, input_position = { x = i - 1, y = 0 } })
    pumps[#pumps + 1] = pump
    t.ok(entities.getTrackedEntity(pump.unit_number) ~= nil, name .. " uses generic water tracking")
end
env.run_ticks(120)
local body = storage.WaterBodies[1]
t.eq(#body.waterBodyStateData.Pumps, 3, "all variants share the same lake")
event_handlers.BuiltPump(pumps[1])
event_handlers.scanForExistingPumps()
t.eq(#body.waterBodyStateData.Pumps, 3, "repeated notifications/scans do not duplicate membership")

surface.set_tiles({ { name = "lava", position = { x = 10, y = 0 } },
    { name = "custom-water", position = { x = 20, y = 0 } } })
for _, spec in ipairs({
    { name = "lava-pump", type = "offshore-pump", x = 10, source_fluid = "lava" },
    { name = "custom-water-pump", type = "offshore-pump", x = 20, source_fluid = "water" },
    { name = "pipeline-pump", type = "pump", x = 1, source_fluid = "water" },
}) do
    local pump = world:build_entity({ name = spec.name, type = spec.type, surface = surface,
        position = { x = spec.x, y = -1 }, input_position = { x = spec.x, y = 0 }, source_fluid = spec.source_fluid })
    t.eq(entities.getTrackedEntity(pump.unit_number), nil, spec.name .. " is unmanaged")
    t.eq(pump.active, true, spec.name .. " is not disabled")
    t.eq(pump.valid, true, spec.name .. " is not rejected/destroyed")
end
local before = body.waterBodyStateData.TempUsedWater
pumps[1].pumped_last_tick = 1
pumps[2].pumped_last_tick = 0
pumps[3].pumped_last_tick = 2
waterbody_update.collectWaterUsageStats()
t.eq(body.waterBodyStateData.TempUsedWater - before, 3, "uses reported extraction, including zero-output pump")
t.finish("Generic water pump recognition")
