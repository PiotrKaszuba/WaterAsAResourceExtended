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

function mock.reset()
    -- globals
    storage = {}
    settings = {global = {}, startup = {}}
    remote = {interfaces = {}, call = function() end}

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
        direction = {north = 0, east = 2, south = 4, west = 6},
    }

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
    if handler then handler(data) end
end

function mock.run_tick()
    mock.tick = mock.tick + 1
    for n, handler in pairs(script._on_nth_tick) do
        if mock.tick % n == 0 then
            handler({tick = mock.tick})
        end
    end
end

function mock.run_ticks(n)
    for _ = 1, n do mock.run_tick() end
end

function mock.on_init()
    if script._on_init then script._on_init() end
end

-- initialize on require
mock.reset()

return mock
