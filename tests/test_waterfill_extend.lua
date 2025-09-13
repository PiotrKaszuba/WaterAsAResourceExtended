local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, {x1 = 0, y1 = 0, x2 = 0, y2 = 0})

    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    })

    test_env.run_ticks(120)

    local wbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(wbody ~= nil, "initial water body created")

    world:waterfill(surface, {x = 1, y = 0})
    test_env.run_ticks(120)

    t.eq(wbody.waterAreaData.AmountWtr, 75, "water amount after extension")
    t.eq(wbody.waterAreaData.TotalArea, 2, "total area after extension")

    t.finish("Waterfill extension test complete")
end

run_mock_test(run_test)
