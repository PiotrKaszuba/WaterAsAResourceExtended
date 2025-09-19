if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local test_assert = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local default_args = {
    waterbody_left = 0,
    waterbody_top = 0,
    waterbody_width = 100,
    waterbody_height = 100,

    -- at top center of the waterbody
    pump_wb_offset_left = 50,
    pump_wb_offset_top = 0,

    -- at center-center of the waterbody
    brush_offset_left = 50,
    brush_offset_top = 50,
    brush_size = 1,
    
    wait_ticks = 60,

    expected_valid_waterbodies = 1,
    brush_area_outside_waterbody = 0,
}

local function single_waterbody_world_setup(args)
    -- unpack and set default args
    if args == nil then args = default_args end
    local waterbody_width = args.waterbody_width or default_args.waterbody_width
    local waterbody_height = args.waterbody_height or default_args.waterbody_height
    local waterbody_left = math.floor(args.waterbody_left or default_args.waterbody_left)
    local waterbody_top = math.floor(args.waterbody_top or default_args.waterbody_top)
    local pump_wb_offset_left = args.pump_wb_offset_left or default_args.pump_wb_offset_left
    local pump_wb_offset_top = args.pump_wb_offset_top or default_args.pump_wb_offset_top
    -- compute additional local values
    local waterbody_right = math.floor(waterbody_left + waterbody_width - 1)
    local waterbody_bottom = math.floor(waterbody_top + waterbody_height - 1)
    -- pump is placed at the center of the tile, so add 0.5 to the position
    local pump_left = math.floor(waterbody_left + pump_wb_offset_left) + 0.5
    local pump_top = math.floor(waterbody_top + pump_wb_offset_top) + 0.5
    -- messages
    local setup_msg = string.format("Waterbody area: %s x %s; pump offset: %s x %s", waterbody_width, waterbody_height, pump_wb_offset_left, pump_wb_offset_top)

    local world, surface = test_env.create_world()
    world:set_water_rectangle(surface, {x1 = waterbody_left, y1 = waterbody_top, x2 = waterbody_right, y2 = waterbody_bottom})
    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = pump_left, y = pump_top - 1},
        surface = surface,
        input_position = {x = pump_left, y = pump_top},
    })
    return world, surface, setup_msg
end

local function test_waterbody_ok_and_scan_finished(world, surface, check_every_n_ticks, do_test)
    -- run ticks until waterbody is finished scanning
    local wb = storage.WaterBodies and storage.WaterBodies[1]
    if not wb then return end

    if do_test then test_assert.ok(wb and wb.valid, "water body created") end

    local search_data = wb.searchData
    while not search_data.finished do
        test_env.run_ticks(check_every_n_ticks)
    end
    if do_test then test_assert.ok(search_data.finished, "water body finished scanning") end
end

local function wait_for_all_waterbodies_finished_scanning(world, surface, check_every_n_ticks)
    local waterbodies = storage.WaterBodies
    if not waterbodies then return end

    local all_finished = false
    while not all_finished do
        all_finished = true
        for _, wb in ipairs(waterbodies) do
            if wb and wb.valid and not wb.searchData.finished then
                all_finished = false
                break
            end
        end
        test_env.run_ticks(check_every_n_ticks)
    end
end

local function landfill_brush(args, world, surface)
    local brush_size = args.brush_size or default_args.brush_size
    local brush_offset_left = args.brush_offset_left or default_args.brush_offset_left
    local brush_offset_top = args.brush_offset_top or default_args.brush_offset_top
    local waterbody_left = args.waterbody_left or default_args.waterbody_left
    local waterbody_top = args.waterbody_top or default_args.waterbody_top

    local brush_left = math.floor(waterbody_left + brush_offset_left)
    local brush_top = math.floor(waterbody_top + brush_offset_top)

    test_assert.print(string.format("Landfill brush applied: brush_left: %s, brush_top: %s, brush_size: %s x %s", brush_left, brush_top, brush_size, brush_size))

    world:landfill_rectangle(surface, {x = brush_left, y = brush_top}, brush_size, brush_size)
end

local function run_test(args)
    -- unpack and set default args
    if args == nil then args = default_args end
    local brush_size = args.brush_size or default_args.brush_size
    local wait_ticks = args.wait_ticks or default_args.wait_ticks
    local expected_valid_waterbodies = args.expected_valid_waterbodies or default_args.expected_valid_waterbodies
    local waterbody_width = args.waterbody_width or default_args.waterbody_width
    local waterbody_height = args.waterbody_height or default_args.waterbody_height
    local brush_area_outside_waterbody = args.brush_area_outside_waterbody or default_args.brush_area_outside_waterbody
    -- set test msg and start test
    local test_msg = string.format("Landfill brush test: %s x %s \n", brush_size, brush_size)
    test_assert.start(test_msg)

    local world, surface, setup_msg = single_waterbody_world_setup(args)

    test_assert.print(setup_msg)

    test_waterbody_ok_and_scan_finished(world, surface, 1, true)

    landfill_brush(args, world, surface)
    test_env.run_ticks(wait_ticks)
    wait_for_all_waterbodies_finished_scanning(world, surface, 60)
    local num_valid_waterbodies = 0
    local biggest_waterbody_area = 0
    for _, wb in pairs(storage.ValidWaterBodies) do
        test_assert.ok(wb and wb.valid, string.format("waterbody: %s is valid", wb.waterBodyId))
        num_valid_waterbodies = num_valid_waterbodies + 1
        if wb.waterAreaData.TotalArea > biggest_waterbody_area then
            biggest_waterbody_area = wb.waterAreaData.TotalArea
        end
    end

    test_assert.eq(num_valid_waterbodies, expected_valid_waterbodies, string.format("number of valid waterbodies: %s, expected: %s", num_valid_waterbodies, expected_valid_waterbodies))

    local brush_overlap_with_waterbody = brush_size * brush_size - brush_area_outside_waterbody
    local expected_biggest_waterbody_area = waterbody_width * waterbody_height - brush_overlap_with_waterbody
    
    test_assert.eq(biggest_waterbody_area, expected_biggest_waterbody_area, string.format("biggest waterbody area: %s, expected: %s", biggest_waterbody_area, expected_biggest_waterbody_area))
    test_assert.finish("Landfill brush test complete")
end

local tests = {
    {brush_size = 1,},
    {brush_size = 2,},
    {brush_size = 3,},
    {brush_size = 4,},
    {brush_size = 5,},
    {brush_size = 5, brush_offset_top = -1, brush_area_outside_waterbody = 5},
    {brush_size = 20, wait_ticks = 300 },
}

for _, test in ipairs(tests) do
    run_mock_test(run_test, test)
end