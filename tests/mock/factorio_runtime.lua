local lua_pairs = _G.pairs

local function deterministic_pairs(tbl)
    local keys = {}
    for k in lua_pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb then
            if ta == "number" or ta == "string" then
                return a < b
            else
                return tostring(a) < tostring(b)
            end
        else
            return ta < tb
        end
    end)
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key ~= nil then
            return key, tbl[key]
        end
    end
end

local mock = {}

-- chunk generation ---------------------------------------------------------

local chunk_surfaces = {}
local chunk_surfaces_lookup = {}

local function reset_chunk_surfaces()
    chunk_surfaces = {}
    chunk_surfaces_lookup = {}
end

local function register_chunk_surface(surface)
    if not surface or chunk_surfaces_lookup[surface] then return end
    chunk_surfaces[#chunk_surfaces + 1] = surface
    chunk_surfaces_lookup[surface] = true
end

local function advance_chunk_generation()
    for i = 1, #chunk_surfaces do
        local surface = chunk_surfaces[i]
        if surface and surface._advance_chunk_generation then
            surface._advance_chunk_generation()
        end
    end
end

mock._register_chunk_surface = register_chunk_surface

-- performance tracking -----------------------------------------------------

local performance = {}
mock.performance = performance

local function reset_performance()
    performance.events = {}
    performance.ticks = {}
    performance.real_ticks = {}
    performance.pending_event_time = 0
end

local function record_event(name, tick, time)
    local list = performance.events[name]
    if not list then
        list = {}
        performance.events[name] = list
    end
    list[#list + 1] = { tick = tick, time = time }
    performance.pending_event_time = performance.pending_event_time + time
end

local function record_tick(tick, time)
    performance.ticks[#performance.ticks + 1] = { tick = tick, time = time }
    local total = time + performance.pending_event_time
    performance.real_ticks[#performance.real_ticks + 1] = { tick = tick, time = total }
    performance.pending_event_time = 0
end

local function compute_stats(list, n_longest_ticks)
    local count, min, max, sum = #list, nil, nil, 0
    local longest_ticks = {} -- longest_tick is a sorted array of the longest ticks (from longest to shortest)
    for _, entry in ipairs(list) do
        local t = entry.time
        if not min or t < min then min = t end
        if not max or t > max then max = t end
        sum = sum + t
        for i = 1, n_longest_ticks do
            if #longest_ticks < i then
                longest_ticks[i] = t
                break
            elseif t > longest_ticks[i] then
                -- shift the longest ticks to the right
                table.insert(longest_ticks, i, t)
                -- remove the last element
                table.remove(longest_ticks, #longest_ticks)
                break
            end
        end
    end
    local avg = count > 0 and (sum / count) or 0
    return { count = count, min = min or 0, max = max or 0, avg = avg, sum = sum, longest_ticks = longest_ticks }
end

function performance.report(args)
    local use_color = args and args.use_color or true
    local n_longest_ticks = args and args.n_longest_ticks or 0

    local no_color_format = function(s)
        return string.format("%.3fms", s * 1000)
    end

    local array_format = function(arr_of_s)
        local arr_of_ms = {}
        for _, s in ipairs(arr_of_s) do
            arr_of_ms[#arr_of_ms + 1] = string.format("%.2f", s * 1000)
        end
        return table.concat(arr_of_ms, ", ") .. " ms"
    end
    local color_format
    if use_color then
        color_format = function(s)
            local ms = s * 1000
            local c
            if ms <= 2 then
                c = "\27[32m" -- green
            elseif ms <= 10 then
                c = "\27[33m" -- yellow
            else
                c = "\27[31m" -- red
            end
            return string.format("%s%.3fms\27[0m", c, ms)
        end
    else
        color_format = no_color_format
    end

    print("Performance stats:")
    local tick_stats = compute_stats(performance.ticks, n_longest_ticks)
    print(string.format(
        " Tick: count=%d total=%s avg=%s min=%s max=%s",
        tick_stats.count,
        no_color_format(tick_stats.sum),
        color_format(tick_stats.avg),
        color_format(tick_stats.min),
        color_format(tick_stats.max)
    ))
    if n_longest_ticks > 0 then
        print(string.format(
            " Longest (tick) ticks: %s",
            array_format(tick_stats.longest_ticks)
        ))
    end
    local real_stats = compute_stats(performance.real_ticks, n_longest_ticks)
    print(string.format(
        " Real tick: count=%d total=%s avg=%s min=%s max=%s",
        real_stats.count,
        no_color_format(real_stats.sum),
        color_format(real_stats.avg),
        color_format(real_stats.min),
        color_format(real_stats.max)
    ))
    if n_longest_ticks > 0 then
        print(string.format(
            " Longest (real) ticks: %s",
            array_format(real_stats.longest_ticks)
        ))
    end
    for name, list in pairs(performance.events) do
        local s = compute_stats(list, n_longest_ticks)
        print(string.format(
            " Event %s: count=%d total=%s avg=%s min=%s max=%s",
            name,
            s.count,
            no_color_format(s.sum),
            color_format(s.avg),
            color_format(s.min),
            color_format(s.max)
        ))
        if n_longest_ticks > 0 then
            print(string.format(
                " Longest %s events: %s",
                name,
                array_format(s.longest_ticks)
            ))
        end
    end
end

function performance.reset()
    reset_performance()
end

function performance.has_data()
    if #performance.ticks > 0 then return true end
    for _, list in pairs(performance.events) do
        if #list > 0 then return true end
    end
    return false
end

reset_performance()

-- runtime -----------------------------------------------------------------

function mock.reset()
    -- globals
    storage = {}
    settings = { global = {}, startup = {} }
    remote = { interfaces = {}, call = function() end }

    reset_chunk_surfaces()

    local function make_printer(kind, id)
        return function(msg)
            if msg ~= nil then
                if id then
                    print(string.format("tick: %d, type: %s, id: %s, %s", mock.tick, kind, id, msg))
                else
                    print(string.format("tick: %d, type: %s, %s", mock.tick, kind, msg))
                end
            end
        end
    end

    mock.make_printer = make_printer
    mock.safe_print = make_printer("game")

    game = {
        surfaces = {},
        forces = {},
        players = {},
        print = mock.safe_print,
        tick = 0,
    }

    defines = {
        events = {
            on_built_entity = 1,
            on_robot_built_entity = 2,
            on_player_mined_entity = 3,
            script_raised_destroy = 4,
            on_robot_mined_entity = 5,
            on_entity_died = 6,
            script_raised_teleported = 7,
            on_player_built_tile = 8,
            on_robot_built_tile = 9,
            script_raised_set_tiles = 10,
            on_research_finished = 11,
        },
        direction = { north = 0, east = 2, south = 4, west = 6 },
    }

    performance.reset()

    -- reverse lookup for event names
    mock._event_names = {}
    for name, id in pairs(defines.events) do
        mock._event_names[id] = name
    end

    script = {
        _on_event = {},
        _on_nth_tick = {},
        _on_init = nil,
    }

    function script.on_event(event_ids, handler)
        if type(event_ids) == "table" then
            for _, id in ipairs(event_ids) do
                script._on_event[id] = handler
            end
        else
            script._on_event[event_ids] = handler
        end
    end

    function script.on_nth_tick(n, handler)
        script._on_nth_tick[n] = handler
    end

    function script.on_init(handler)
        script._on_init = handler
    end

    _G.pairs = deterministic_pairs

    mock.tick = 0
end

function mock.raise_event(event_id, data)
    local handler = script._on_event[event_id]
    if handler then
        local start = os.clock()
        handler(data)
        local elapsed = os.clock() - start
        record_event(mock._event_names[event_id] or tostring(event_id), mock.tick, elapsed)
    end
end

function mock.run_tick()
    mock.tick = mock.tick + 1
    game.tick = mock.tick
    advance_chunk_generation()
    local start = os.clock()
    for n, handler in pairs(script._on_nth_tick) do
        if mock.tick % n == 0 then
            handler({ tick = mock.tick })
        end
    end
    local elapsed = os.clock() - start
    record_tick(mock.tick, elapsed)
end

function mock.run_ticks(n)
    for _ = 1, n do mock.run_tick() end
end

function mock.on_init()
    if script._on_init then
        local start = os.clock()
        script._on_init()
        local elapsed = os.clock() - start
        record_event("on_init", mock.tick, elapsed)
    end
end

-- initialize on require
mock.reset()

return mock
