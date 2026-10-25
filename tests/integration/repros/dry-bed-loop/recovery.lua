local plan = require("plan")
local initial, change, started, first_gap
local function snap() return remote.call("water_exact_repro", "snapshot") end
script.on_configuration_changed(function(e)
    initial = snap()
    change = e.mod_changes.WaterAsAResourceExtended
    helpers.write_file("recovery-before-tick.json", helpers.table_to_json({ initial = initial, change = change }), false)
end)
script.on_event({ defines.events.on_player_built_tile, defines.events.on_player_mined_tile,
    defines.events.on_robot_built_tile, defines.events.on_robot_mined_tile },
    function() error("Recovery trial must not place or mine terrain") end)
script.on_event(defines.events.on_tick, function()
    if storage.exact_replay_done then return end
    assert(initial, "Expected real engine configuration change before recovery")
    if not started then started = game.tick; game.tick_paused = false; game.speed = 1 end
    local state = snap()
    for _, b in ipairs(initial.bodies) do if b.gap ~= 0 and not first_gap then first_gap = initial end end
    for _, b in ipairs(state.bodies) do if b.gap ~= 0 and not first_gap then first_gap = state end end
    if game.tick < started + 600 then return end
    local gap, settled = 0, state.queued == 0
    for _, b in ipairs(state.bodies) do gap = gap + math.abs(b.gap); settled = settled and b.finished end
    local covered, lost = {}, 0
    for _, action in ipairs(plan.actions) do for _, tile in ipairs(action.expected_tiles) do
        local p = tile.position
        covered[p.x .. "," .. p.y] = p
    end end
    local n = 0
    for _, p in pairs(covered) do
        n = n + 1
        if game.surfaces.nauvis.get_tile(p).name ~= "landfill" then lost = lost + 1 end
    end
    helpers.write_file("result.json", helpers.table_to_json({ variant = plan.variant, case = plan.case,
        harness_valid = true, initial = initial, configuration_change = change,
        events = 0, expected_events = 0, covered = n, lost = lost, first_gap = first_gap,
        before_differences = {}, settled = settled, final = state,
        invariant_passed = not first_gap and gap == 0 and settled and lost == 0 }), false)
    storage.exact_replay_done = true
end)
