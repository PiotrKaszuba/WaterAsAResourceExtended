if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test(args)
    if args == nil then args = {} end
    local brush_size = args.brush_size or 1
    local expected_area = args.expected_area or 1
    local expected_water_amount = args.expected_water_amount or 50
    local update_budget_setting = args.update_budget_setting or 200
    local additional_info = args.additional_info or nil
    local msg = string.format("Landfill brush test: %s x 1, update budget: %s", brush_size, update_budget_setting)
    if additional_info then
        msg = msg .. "\n" .. additional_info
    end
    t.start(msg)
    local world, surface = test_env.create_world()
    settings.global["Update-Budget-Per-Second"].value = update_budget_setting
    storage.UpdateBudget = update_budget_setting
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

    -- landfill two tiles at once using Nx1 brush
    world:landfill_rectangle(surface, {x = 1, y = 0}, brush_size, 1)
    test_env.run_ticks(240)

    local remaining
    for _, wb in pairs(storage.WaterBodies) do
        if wb.valid then remaining = wb end
    end
    t.eq(remaining.waterAreaData.TotalArea, expected_area, "area after landfill")
    t.eq(remaining.waterAreaData.AmountWtr, expected_water_amount, "water amount after landfill")
    local finish_msg = string.format("Landfill brush %s x 1", brush_size)
    if args.update_budget_setting ~= nil then
        finish_msg = finish_msg .. ", update budget: " .. args.update_budget_setting
    end
    finish_msg = finish_msg .. ", test complete"

    t.finish(finish_msg)
end

local tests = {
    {brush_size = 1},
    {brush_size = 2, additional_info = "This will print a warning that tile count is 0 in getCentroid"},
    {brush_size = 2, update_budget_setting = 1000, additional_info = "This will print a warning that tile count is 0 in getCentroid"}
}

for _, test in ipairs(tests) do
    run_mock_test(run_test, test)
end
