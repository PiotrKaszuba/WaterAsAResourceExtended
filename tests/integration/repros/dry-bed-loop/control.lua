-- Native inventory actions at the ticks recorded from the GUI trial.
local plan = require('plan')
local started, next_action, event_count = false, 1, 0
local covered, lost, first_gap, before_differences = {}, {}, nil, {}
local current_action
local function snap() return remote.call('water_exact_repro', 'snapshot') end
local function record(kind, extra, s)
    helpers.write_file('replay.jsonl', helpers.table_to_json({ kind = kind, extra = extra,
        state = s or snap() }) .. '\n', true)
end
local function tiles_key(tiles)
    local entries = {}
    for _, tile in ipairs(tiles) do
        local name = tile.old_tile and tile.old_tile.name or tile.old
        entries[#entries + 1] = tile.position.x .. ',' .. tile.position.y .. ':' .. name
    end
    table.sort(entries)
    return table.concat(entries, ';')
end
script.on_event(defines.events.on_player_built_tile, function(e)
    assert(current_action, 'Unscheduled tile action')
    assert(e.tile.name == 'landfill', 'Unexpected terrain operation')
    assert(tiles_key(e.tiles) == tiles_key(current_action.expected_tiles),
        'Native brush payload differs from recorded GUI brush at tick ' .. game.tick)
    event_count = event_count + 1
    for _, tile in ipairs(e.tiles) do
        covered[tile.position.x .. ',' .. tile.position.y] = tile.position
    end
    record('native-landfill', { action = next_action, tiles = current_action.expected_tiles })
end)
script.on_event({ defines.events.on_player_mined_tile, defines.events.on_robot_mined_tile },
    function() error('Mining is forbidden in this placement-only reproduction') end)
script.on_event(defines.events.on_tick, function()
    if storage.exact_replay_done then return end
    if not started then
        started = true
        game.tick_paused = false
        game.speed = 1
        assert(game.players[1], 'Checkpoint must contain a native player')
        record('initial')
    end
    local state = snap()
    for _, b in ipairs(state.bodies) do
        if b.gap ~= 0 and not first_gap then first_gap = state; record('first-gap', nil, state) end
    end
    local action = plan.actions[next_action]
    while action and game.tick == action.tick do
        local expected = action.expected_before
        -- This companion's on_tick runs after Water, matching the GUI action phase.
        for _, field in ipairs({ 'periodic', 'queued' }) do
            local value = expected[field]
            -- Water registered the GUI event before the observation companion.
            if field == 'queued' then value = value - #action.expected_tiles end
            if state[field] ~= value then
                before_differences[#before_differences + 1] = { action = next_action,
                    field = field, expected = value, actual = state[field] }
            end
        end
        if #state.bodies == 1 then
            for _, field in ipairs({ 'area', 'actual_dry', 'recorded_dry', 'wet' }) do
                if state.bodies[1][field] ~= expected.bodies[1][field] then
                    before_differences[#before_differences + 1] = { action = next_action,
                        field = field, expected = expected.bodies[1][field], actual = state.bodies[1][field] }
                end
            end
        end
        record('before-brush', { action = next_action, position = action.position })
        current_action = action
        local p = game.players[1]
        p.force.character_build_distance_bonus = 200
        p.force.character_reach_distance_bonus = 200
        p.cursor_stack.set_stack({ name = 'landfill', count = 100 })
        p.build_from_cursor({ position = action.position, terrain_building_size = 2 })
        current_action = nil
        next_action = next_action + 1
        action = plan.actions[next_action]
        state = snap()
    end
    for key, pos in pairs(covered) do
        local name = game.surfaces.nauvis.get_tile(pos).name
        if name ~= 'landfill' and not lost[key] then lost[key] = true; record('landfill-lost', { position = pos, name = name }) end
    end
    if game.tick >= plan.end_tick then
        local n, l, gap, settled = 0, 0, 0, state.queued == 0
        for _ in pairs(covered) do n = n + 1 end
        for _ in pairs(lost) do l = l + 1 end
        for _, b in ipairs(state.bodies) do gap = gap + math.abs(b.gap); settled = settled and b.finished end
        local result = { case = plan.case, variant = plan.variant, events = event_count,
            expected_events = #plan.actions, covered = n, lost = l, first_gap = first_gap,
            before_differences = before_differences, settled = settled, final = state,
            harness_valid = event_count == #plan.actions and #before_differences == 0,
            invariant_passed = event_count == #plan.actions and l == 0 and gap == 0 and settled and not first_gap }
        helpers.write_file('result.json', helpers.table_to_json(result), false)
        storage.exact_replay_done = true
    end
end)
