--[[
Performance profiling helpers for Factorio API calls (test harness edition).

This module is designed to gather real runtime measurements inside Factorio and
reuse them when executing mock-based tests.  It focuses on three core tasks:

1. Initialise storage buckets for every API call you wish to observe.
2. Decorate API functions so each invocation records runtime and argument
   complexity data.
3. Export collected samples to the script-output directory for later analysis.

Typical workflow:

    local profiling = require("tests.helpers.mock_performance_profiling")

    -- Step 1: prepare buckets (call once during on_init/on_load)
    profiling.init(storage, {
        "LuaSurface.find_entities_filtered",
        "LuaEntityPrototype.get_fuel_value",
    }, {
        metadata = {map = "biter-battleground"}
    })

    -- Step 2: decorate the Factorio API you want to track.
    local original = surface.find_entities_filtered
    surface.find_entities_filtered = profiling.make_decorator(storage,
        "LuaSurface.find_entities_filtered",
        {target_arg = 2, context = "spawn-scan"}
    )(original)

    -- Step 3: once you finish profiling, export the gathered samples.
    profiling.write_to_file(storage, "performance_profile.json")

    -- Optional: register cost definitions so mock tests can estimate the
    -- runtime impact of invoking API calls without replaying the profiler.
    profiling.register_definition(storage,
        "LuaSurface.find_entities_filtered",
        {base_cost = 0.0003, complexity_multiplier = 0.00002}
    )

When running inside Factorio, you can hook the exporter to a command:

    -- commands.add_command("DumpPerfProfile",
    --     "Writes collected API profiling data to script-output",
    --     function() profiling.write_to_file(storage, "performance_profile.json") end
    -- )

]]

local profiling = {}

local table_unpack = table.unpack or unpack
local table_pack = table.pack or function(...)
    return {n = select("#", ...), ...}
end

---Resolve which storage table to use (defaults to the global `storage`).
---@param storage_table table|nil
---@return table
local function resolve_storage(storage_table)
    local target = storage_table or storage
    if type(target) ~= "table" then
        error("performance profiling requires a storage table; pass `storage` or a custom table")
    end
    return target
end

---Ensure a profiling bucket exists and return it.
---@param store table
---@param api_name string
---@return table
local function ensure_bucket(store, api_name)
    if type(store.performance_profile) ~= "table" then
        store.performance_profile = {}
    end
    local profile = store.performance_profile
    local bucket = profile[api_name]
    if not bucket then
        bucket = {}
        profile[api_name] = bucket
    end
    return bucket
end

---Start a timing measurement using LuaProfiler when available.
---@return table
local function start_timer()
    local profiler
    if helpers and helpers.create_profiler then
        local ok, created = pcall(helpers.create_profiler, true)
        if ok and created then
            profiler = created
        end
    elseif game and game.create_profiler then
        local ok, created = pcall(game.create_profiler, true)
        if ok and created then
            profiler = created
        end
    end
    if profiler then
        if profiler.reset then profiler.reset(profiler) end
        if profiler.restart then profiler.restart(profiler) end
    end
    return {profiler = profiler, started = os.clock()}
end

---Stop a previously started timer and normalise results into seconds/ticks.
---@param state table
---@return table
local function stop_timer(state)
    local seconds = os.clock() - state.started
    local profiler = state.profiler
    local profiler_ticks
    if profiler then
        if profiler.stop then
            profiler.stop(profiler)
        end
        local ok, value = pcall(function() return profiler.ticks end)
        if ok and type(value) == "number" then
            profiler_ticks = value
        else
            local ok_time, profiler_time = pcall(function() return profiler.time end)
            if ok_time and type(profiler_time) == "number" then
                profiler_ticks = profiler_time
            end
        end
    end
    local ticks = profiler_ticks or (seconds * 60)
    return {
        seconds = seconds,
        ticks = ticks,
        profiler_ticks = profiler_ticks,
    }
end

---Normalise any call record into a (table, api_name) tuple.
---@param call_record table|string
---@return table, string|nil
local function normalise_call(call_record)
    if type(call_record) == "table" then
        local name = call_record.api_name or call_record.name or call_record[1]
        return call_record, name
    end
    return {name = call_record}, call_record
end

---Initialise profiling buckets and optional metadata/definitions.
---@param storage_table table|nil
---@param api_names string[]|nil
---@param options table|nil
---@return table
function profiling.init(storage_table, api_names, options)
    local store = resolve_storage(storage_table)
    options = options or {}

    if options.reset or type(store.performance_profile) ~= "table" then
        store.performance_profile = {}
    end
    local profile = store.performance_profile

    if type(api_names) == "table" then
        for i = 1, #api_names do
            local name = api_names[i]
            if type(name) == "string" and profile[name] == nil then
                profile[name] = {}
            end
        end
    end

    if options.reset_metadata or type(store.performance_profile_metadata) ~= "table" then
        store.performance_profile_metadata = {}
    end
    if options.metadata then
        for key, value in pairs(options.metadata) do
            store.performance_profile_metadata[key] = value
        end
    end

    if options.replace_definitions then
        store.performance_profile_definitions = {}
    end
    if type(store.performance_profile_definitions) ~= "table" then
        store.performance_profile_definitions = {}
    end
    if options.definitions then
        for key, value in pairs(options.definitions) do
            store.performance_profile_definitions[key] = value
        end
    end
    if options.default_definition then
        store.performance_profile_definitions._default = options.default_definition
    end

    return profile
end

---Register a single cost definition used for offline cost estimation.
---@param storage_table table|nil
---@param api_name string
---@param definition table
function profiling.register_definition(storage_table, api_name, definition)
    local store = resolve_storage(storage_table)
    if type(store.performance_profile_definitions) ~= "table" then
        store.performance_profile_definitions = {}
    end
    store.performance_profile_definitions[api_name] = definition
end

---Fetch the profiling bucket for a particular API call.
---@param storage_table table|nil
---@param api_name string
---@return table
function profiling.get_bucket(storage_table, api_name)
    local store = resolve_storage(storage_table)
    return ensure_bucket(store, api_name)
end

---Create a decorator that records runtime and complexity of each API call.
---@param storage_table table|nil
---@param api_name string
---@param options table|nil
---@return fun(fn:function):function
function profiling.make_decorator(storage_table, api_name, options)
    local store = resolve_storage(storage_table)
    local bucket = ensure_bucket(store, api_name)
    options = options or {}

    local context = options.context
    local target_arg = options.target_arg or options.arg_index
    local arg_getter = options.arg_getter
    local complexity_extractor = options.complexity_extractor
    local metadata_builder = options.metadata_builder
    local allow_nil_complexity = options.allow_nil_complexity

    return function(target_fn)
        return function(...)
            local args = table_pack(...)
            local timer_state = start_timer()
            local ok, result = pcall(function()
                return table_pack(target_fn(table_unpack(args, 1, args.n)))
            end)
            local measurement = stop_timer(timer_state)

            local target_value
            local complexity_error
            if arg_getter then
                local success, value = pcall(arg_getter, args, target_fn)
                if success then
                    target_value = value
                else
                    complexity_error = value
                end
            elseif type(target_arg) == "number" then
                target_value = args[target_arg]
            elseif type(target_arg) == "function" then
                local success, value = pcall(target_arg, table_unpack(args, 1, args.n))
                if success then
                    target_value = value
                else
                    complexity_error = value
                end
            elseif type(target_arg) == "string" then
                local first_arg = args[1]
                if type(first_arg) == "table" then
                    target_value = first_arg[target_arg]
                end
            end

            local complexity
            if complexity_extractor then
                local success, value = pcall(complexity_extractor, target_value, args, target_fn)
                if success then
                    complexity = value
                else
                    complexity_error = value
                end
            elseif target_value ~= nil or allow_nil_complexity then
                complexity = target_value
            end

            local metadata
            if metadata_builder then
                local success, value = pcall(metadata_builder, args, target_fn)
                if success then
                    metadata = value
                else
                    metadata = {error = value}
                end
            end

            local record = {
                context = context,
                tick = game and game.tick or nil,
                runtime_seconds = measurement.seconds,
                runtime_ticks = measurement.ticks,
                profiler_ticks = measurement.profiler_ticks,
                complexity = complexity,
                success = ok,
            }
            if metadata ~= nil then
                record.metadata = metadata
            end
            if complexity_error then
                record.complexity_error = complexity_error
            end
            if not ok then
                record.error = result
            end

            bucket[#bucket + 1] = record

            if ok then
                return table_unpack(result, 1, result.n)
            end
            error(result)
        end
    end
end

---Estimate the cost (seconds) contributed by a single API call record.
---@param call_record table|string
---@param definitions table|nil
---@param default_definition table|nil
---@return number
function profiling.estimate_cost(call_record, definitions, default_definition)
    local call, name = normalise_call(call_record)

    local count = call.count or 1
    if call.override_time ~= nil then
        return call.override_time * count
    end
    if call.override_cost ~= nil then
        return call.override_cost * count
    end
    if call.runtime_seconds ~= nil then
        return call.runtime_seconds * count
    end
    if call.runtime_ticks and type(call.runtime_ticks) == "number" then
        return (call.runtime_ticks / 60) * count
    end

    definitions = definitions or ((storage and storage.performance_profile_definitions) or {})
    local definition = definitions[name]
    if not definition then
        definition = default_definition or definitions._default
    end
    if not definition then
        return 0
    end

    if definition.evaluate then
        local ok, value = pcall(definition.evaluate, call, definition, definitions)
        if ok and type(value) == "number" then
            return value * count
        else
            return 0
        end
    end

    local cost = definition.base_cost or definition.base or 0
    if definition.per_call then
        cost = cost + definition.per_call
    end

    local complexity = call.complexity or call.complexities or call.complexity_value
    if definition.complexity_evaluator then
        local ok, extra = pcall(definition.complexity_evaluator, complexity, call, definition, definitions)
        if ok and type(extra) == "number" then
            cost = cost + extra
        end
    else
        local weights = definition.complexity_weights or definition.complexity_multipliers
        local multiplier = definition.complexity_multiplier or (weights and (weights._default or weights.default))
        if type(complexity) == "number" then
            if multiplier then
                cost = cost + multiplier * complexity
            end
        elseif type(complexity) == "table" then
            weights = weights or {}
            local default_weight = weights._default or weights.default or multiplier
            for key, value in pairs(complexity) do
                local weight = weights[key] or default_weight
                if weight and type(value) == "number" then
                    cost = cost + weight * value
                end
            end
        elseif complexity ~= nil and multiplier then
            local numeric = tonumber(complexity)
            if numeric then
                cost = cost + multiplier * numeric
            end
        end
    end

    if definition.minimum_cost and cost < definition.minimum_cost then
        cost = definition.minimum_cost
    end

    return cost * count
end

---Aggregate the cost for an array of call records, returning totals and per-API breakdown.
---@param call_array table[]|nil
---@param definitions table|nil
---@param default_definition table|nil
---@return number, table
function profiling.calculate_costs(call_array, definitions, default_definition)
    if not call_array then
        return 0, {}
    end

    definitions = definitions or ((storage and storage.performance_profile_definitions) or {})
    local fallback = default_definition or definitions._default

    local total = 0
    local breakdown = {}
    for i = 1, #call_array do
        local record = call_array[i]
        local cost = profiling.estimate_cost(record, definitions, fallback)
        total = total + cost
        local _, name = normalise_call(record)
        if name then
            breakdown[name] = (breakdown[name] or 0) + cost
        end
    end

    return total, breakdown
end

---Serialise collected profiling data to script-output for later analysis.
---@param storage_table table|nil
---@param filename string|nil
---@param options table|nil
---@return boolean, string|nil, string|nil
function profiling.write_to_file(storage_table, filename, options)
    local store = resolve_storage(storage_table)
    if type(store.performance_profile) ~= "table" then
        return false, "performance profile storage is not initialised"
    end

    filename = filename or "performance_profile.json"
    options = options or {}

    local payload = {
        generated_at_tick = game and game.tick or nil,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        profile = store.performance_profile,
        metadata = store.performance_profile_metadata,
        definitions = store.performance_profile_definitions,
    }
    if options.extra then
        for key, value in pairs(options.extra) do
            payload[key] = value
        end
    end

    local encoded
    if helpers and helpers.table_to_json then
        local ok, json = pcall(helpers.table_to_json, payload)
        if ok and json then
            encoded = json
        end
    end
    if not encoded and game and game.table_to_json then
        local ok, json = pcall(game.table_to_json, payload)
        if ok and json then
            encoded = json
        end
    end
    if not encoded and type(serpent) == "table" then
        encoded = serpent.block(payload, {comment = false, numformat = "%0.6f"})
    end
    if not encoded then
        return false, "unable to encode performance profile"
    end

    if helpers and helpers.write_file then
        helpers.write_file(filename, encoded, options.append, options.for_player)
        return true, filename, encoded
    elseif game and game.write_file then
        game.write_file(filename, encoded, options.append, options.for_player)
        return true, filename, encoded
    end
    return false, "no available file writer"
end

return profiling
