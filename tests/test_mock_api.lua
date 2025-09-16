if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local t = require("tests.helpers.test_assert")
local run_mock_test = require("tests.helpers.mock_test")


-- Tests:
-- waterbody created
-- pump created at wrong place - with rejection (mine entity triggers)
-- pump created
-- wait for scan to finish
-- destroys pump
-- waits for map marker to be removed
-- checks map marker for player force (before and after pump destruction)
-- checks pump tracking (before and after pump destruction)
-- checks force_to_pump (before and after pump destruction)
-- checks forces on waterbody (before and after pump destruction)
-- adds custom chart tag and checks it, destroys it and checks that it's removed
-- script raises set_tiles and checks that tile event is enqueued
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

    local player = game.players[1]
    local player_index = player.index

    local player_inventory = player._inventory_contents
    -- check if has "offshore-pump - shouldn't have any now
    t.ok(player_inventory["offshore-pump"] == nil or player_inventory["offshore-pump"] == 0, "player doesn't have offshore-pump in inventory")

    -- try to build pump without item
    local pump_wrong_place = world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -2},
        surface = surface,
        input_position = {x = 0, y = -1},
    }, player_index, "offshore-pump")
    t.ok(pump_wrong_place == nil, "pump creation attempt without item fails and returns nil")

    -- now add item to inventory and try again
    player.insert({name = "offshore-pump", count = 1})

    -- check if has "offshore-pump - should have one now
    t.ok(player_inventory["offshore-pump"] == 1, "player has offshore-pump in inventory")

    local pump_wrong_place = world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -2},
        surface = surface,
        input_position = {x = 0, y = -1},
    }, player_index, "offshore-pump")

    -- build should fail because of placement - should still have pump in inventory
    t.ok(player_inventory["offshore-pump"] == 1, "pump still in inventory after failed build")

    t.ok(pump_wrong_place and pump_wrong_place.valid == false, "pump created at wrong place is destroyed")

    local pump = world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    }, player_index, "offshore-pump")

    t.ok(pump and pump.valid, "pump created at correct place")
    t.ok(player_inventory["offshore-pump"] == 0 or player_inventory["offshore-pump"] == nil, "pump removed from inventory after successful build")

    test_env.run_ticks(120)

    local waterbody = storage.WaterBodies and storage.WaterBodies[1]
    t.ok(waterbody ~= nil, "water body created")
    if waterbody then
        local marker = waterbody.waterBodyStateData.MapMarkers["player"]
        t.ok(marker ~= nil and utils.MapMarker.valid(marker), "map marker created for player force")
        if marker and marker.tag then
            t.ok(marker.tag.text ~= nil, "map marker tag has text")
        end
        -- check if stored on surface
        t.ok(surface.chart_tags[1] == marker.tag, "map marker stored on surface")
    end

    local tracked_before = entities.getTrackedEntity(pump.unit_number)
    t.ok(tracked_before ~= nil, "pump tracked before scripted destroy")

    local force_to_pump = entities.getFirstPumpPerForce(waterbody)
    t.ok(force_to_pump ~= nil, "force_to_pump created")
    t.ok(force_to_pump["player"] ~= nil and force_to_pump["player"].entity == pump, "force_to_pump has player force before destroy and it's the same pump")


    local forces_of_wb_before = waterbody.waterBodyStateData.Forces
    t.ok(forces_of_wb_before ~= nil and forces_of_wb_before["player"] ~= nil, "forces_of_wb has player force before destroy")

    pump.destroy({raise_destroy = true})
    local tracked_after = entities.getTrackedEntity(pump.unit_number)
    t.eq(tracked_after, nil, "script raised destroy removed tracked pump")

    local force_to_pump_after = entities.getFirstPumpPerForce(waterbody)
    t.ok(force_to_pump_after ~= nil and force_to_pump_after["player"] == nil, "force_to_pump has no player force after destroy")


    local forces_of_wb_after = waterbody.waterBodyStateData.Forces
    t.ok(forces_of_wb_after ~= nil and forces_of_wb_after["player"] == nil, "forces_of_wb has no player force after destroy")

    test_env.run_ticks(120)

    -- check whether map marker is still there (should be removed)
    local marker = waterbody.waterBodyStateData.MapMarkers["player"]
    t.ok(marker.tag.valid == false, "map marker invalid after pump destruction")
    -- check whether it's removed from surface
    t.ok(surface.chart_tags[1] == nil, "map marker removed from surface after pump destruction")

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

