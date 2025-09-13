local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")

return function(rect, ticks, expected_type, expected_amount, label)
    t.start()
    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, rect)

    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    })

    test_env.run_ticks(ticks)

    local wbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(wbody ~= nil, "water body created")
    if wbody then
        t.eq(wbody.waterAreaData.WaterBodyType, expected_type, "water body type")
        t.eq(wbody.waterAreaData.AmountWtr, expected_amount, "water amount")
    end

    t.finish(label)
end
