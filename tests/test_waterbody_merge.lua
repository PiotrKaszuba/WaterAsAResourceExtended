if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
    world:set_water_rectangle(surface, { x1 = 2, y1 = 0, x2 = 2, y2 = 0 })

    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 0, y = -1 },
        surface = surface,
        input_position = { x = 0, y = 0 },
    })
    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = { x = 2, y = -1 },
        surface = surface,
        input_position = { x = 2, y = 0 },
    })

    test_env.run_ticks(120)

    local w1 = storage.WaterBodies and storage.WaterBodies[1]
    local w2 = storage.WaterBodies and storage.WaterBodies[2]
    t.ok(w1 and w1.valid, "first water body created")
    t.ok(w2 and w2.valid, "second water body created")

    world:waterfill(surface, { x = 1, y = 0 })
    test_env.run_ticks(240)

    local valid_count = 0
    local merged
    for _, wb in pairs(storage.WaterBodies) do
        if wb and wb.valid then
            valid_count = valid_count + 1
            merged = wb
        end
    end
    t.eq(valid_count, 1, "water bodies merged")
    t.eq(merged.waterAreaData.AmountWtr, 125, "merged water amount")
    t.eq(merged.waterAreaData.TotalArea, 3, "merged total area")

    t.finish("Waterbody merge test complete")
end

run_mock_test(run_test)
