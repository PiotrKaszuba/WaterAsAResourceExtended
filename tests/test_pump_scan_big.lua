if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 9, y2 = 9 })

    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 0, y = -1 },
        surface = surface,
        input_position = { x = 0, y = 0 },
    })

    test_env.run_ticks(240)

    local wbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(wbody ~= nil, "water body created")
    if wbody then
        t.eq(wbody.waterAreaData.WaterBodyType, 2, "water body type")
        t.eq(wbody.waterAreaData.AmountWtr, 5000, "water amount")
    end

    t.finish("Large pump scan tests complete")
end

run_mock_test(run_test)
