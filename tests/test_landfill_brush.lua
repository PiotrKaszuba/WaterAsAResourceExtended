if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()
    -- initial water line of three tiles
    world:set_water_rectangle(surface, {x1 = 0, y1 = 0, x2 = 2, y2 = 0})

    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    })

    test_env.run_ticks(120)

    local wbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(wbody and wbody.valid, "water body created")
    t.eq(wbody.waterAreaData.TotalArea, 3, "initial area")

    -- landfill two tiles at once using 2x1 brush
    world:landfill_rectangle(surface, {x = 1, y = 0}, 2, 1)
    test_env.run_ticks(240)

    local remaining
    for _, wb in pairs(storage.WaterBodies) do
        if wb.valid then remaining = wb end
    end
    t.eq(remaining.waterAreaData.TotalArea, 1, "area after landfill")
    t.eq(remaining.waterAreaData.AmountWtr, 50, "water amount after landfill")

    t.finish("Landfill brush test complete")
end

run_mock_test(run_test)
