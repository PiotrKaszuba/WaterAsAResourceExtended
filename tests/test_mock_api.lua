if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")

local function run_test()
    t.start()
    local world, surface = test_env.create_world()

    require("modules.utils")
    require("modules.entities")
    require("modules.tiles")

    local utils = _G.utils
    local entities = _G.entities
    local tiles = _G.tiles

    world:set_water_rectangle(surface, {x1 = 0, y1 = 0, x2 = 0, y2 = 0})
    local pump = world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    })

    test_env.run_ticks(120)

    local waterbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(waterbody ~= nil, "water body created")
    if waterbody then
        local marker = waterbody.waterBodyStateData.MapMarkers["player"]
        t.ok(marker ~= nil and utils.MapMarker.valid(marker), "map marker created for player force")
        if marker and marker.tag then
            t.ok(marker.tag.text ~= nil, "map marker tag has text")
        end
    end

    local tracked_before = entities.getTrackedEntity(pump.unit_number)
    t.ok(tracked_before ~= nil, "pump tracked before scripted destroy")

    pump.destroy({raise_destroy = true})
    local tracked_after = entities.getTrackedEntity(pump.unit_number)
    t.eq(tracked_after, nil, "script raised destroy removed tracked pump")

    local force = game.forces["player"]
    local tag_count = #force.find_chart_tags(surface)
    local extra_tag = force.add_chart_tag(surface.index, {
        position = {x = 5, y = 5},
        text = "Test marker",
    })
    t.ok(extra_tag and extra_tag.valid, "add_chart_tag returns valid tag")
    t.eq(#force.find_chart_tags(surface), tag_count + 1, "find_chart_tags reports new tag")
    t.eq(#surface.chart_tags, tag_count + 1, "chart tag stored on surface")
    extra_tag.destroy()
    t.ok(not extra_tag.valid, "destroy invalidates chart tag")
    t.eq(#surface.chart_tags, tag_count, "destroy removes chart tag from surface")
    t.eq(#force.find_chart_tags(surface), tag_count, "find_chart_tags omits destroyed tag")

    local queue = tiles.getTileEventQueue()
    local initial_size = queue.size
    world:set_water_rectangle(surface, {x1 = 1, y1 = 0, x2 = 1, y2 = 0})
    surface.set_tiles({
        {name = "landfill", position = {x = 1, y = 0}, old_tile = {name = "water"}},
    }, true, true, true, true)
    t.eq(queue.size, initial_size + 1, "script raised set_tiles enqueues tile event")

    t.finish("Mock API coverage")
end

run_mock_test(run_test)

