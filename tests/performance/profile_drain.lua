-- Diagnostic attribution, separate from uninstrumented comparison timings.
-- Usage: lua tests/performance/profile_drain.lua pending_dense_4096 on
local modes = require("tests.performance.guard_mode")
modes.set(arg[2] ~= "off")
local env = require("tests.helpers.test_env")
local workloads = require("tests.performance.workloads")
local original_create = env.create_world
local stats, counters, stack = {}, {}, {}
local active = 0
local unpack = table.unpack or unpack
local function pack(...) return { n = select("#", ...), ... } end

local function wrap(object, key, name, root)
    local fn = object[key]
    if not fn then return end
    stats[name] = { calls = 0, inclusive = 0, self = 0 }
    object[key] = function(...)
        if name == "queue_dispatch" and tiles.getTileEventQueue().size == 0 then return fn(...) end
        if not root and active == 0 then return fn(...) end
        if root then active = active + 1 end
        local frame = { child = 0, start = os.clock() }
        stack[#stack + 1] = frame
        local results = pack(fn(...))
        local elapsed = os.clock() - frame.start
        stack[#stack] = nil
        if #stack > 0 then stack[#stack].child = stack[#stack].child + elapsed end
        local record = stats[name]
        record.calls = record.calls + 1
        record.inclusive = record.inclusive + elapsed
        record.self = record.self + elapsed - frame.child
        if root then active = active - 1 end
        return unpack(results, 1, results.n)
    end
end

env.create_world = function(...)
    local world, surface = original_create(...)
    -- Reset after fixture modules load. Counting wrappers cover native mock calls;
    -- timings are only taken for coarse functions, avoiding per-tile clock calls.
    local get = surface.get_tile
    surface.get_tile = function(...)
        if active > 0 then counters.tile_reads = (counters.tile_reads or 0) + 1 end
        return get(...)
    end
    local connected = surface.get_connected_tiles
    surface.get_connected_tiles = function(...)
        local result = connected(...)
        if active > 0 then counters.connected_tiles_returned = (counters.connected_tiles_returned or 0) + #result end
        return result
    end
    if arg[4] == "interior-skip" then
        -- Diagnostic hypothesis only, not a production fix. Frontier removals
        -- retain the original bounded split search. Do not widen that search.
        local split = waterbody_split.checkIfWaterBodyGotSplit
        waterbody_split.checkIfWaterBodyGotSplit = function(id, position, target, ...)
            for _, delta in ipairs(utils.AdjacentOffsets) do
                local p = { x = position.x + delta.x, y = position.y + delta.y }
                if utils.IsWaterOrDryTile(target.get_tile(p).name) and waterbodies.getWaterTile(hot_utils.GridKey(p), target) == id then
                    return split(id, position, target, ...)
                end
            end
            counters.experimental_interior_skips = (counters.experimental_interior_skips or 0) + 1
        end
    end
    wrap(surface, "get_connected_tiles", "native_mock_connected_search")
    wrap(tiles, "handleTileEventsInternal", "terrain_event_handler", true)
    wrap(tiles, "addTileEvent", "queue_registration", true)
    wrap(tiles, "processTileEventQueue", "queue_dispatch", true)
    wrap(tiles, "processLandfillEvent", "landfill_event")
    wrap(tiles, "reduceTileFromWaterBody", "capacity_and_grid_removal")
    wrap(waterbody_split, "checkIfWaterBodyGotSplit", "split_check")
    wrap(waterbody_split, "getWaterBodyConnectedTiles", "bounded_component_search")
    wrap(waterbody_scan, "getAdjacentWaterAndLandTiles", "adjacent_owned_land_search")
    wrap(waterbody_scan, "recalculateEdgesAroundPosition", "recalculate_edges")
    wrap(waterbody_scan, "EdgePattern", "edge_pattern")
    wrap(waterbody_scan, "ScanWaterArea", "scan_area")
    wrap(waterbody_scan, "beginScanWaterArea", "begin_scan")
    wrap(waterbodies, "createNewWaterBody", "create_successor")
    wrap(waterbodies, "ensureAndUpdateBinset", "prepare_binset")
    wrap(waterbody_depletion, "requestNewBinsetUpdate", "rebin_visual_candidates")
    wrap(waterbodies, "removeTileFromWaterGrid", "remove_grid_membership")
    wrap(waterbodies, "CalculateAndUpdateWaterBodyAreaData", "recalculate_capacity")
    local pending = require("modules.pending_tile_events")
    wrap(pending, "add", "pending_index_add")
    wrap(pending, "finish", "pending_index_finish")
    wrap(pending, "ensure", "pending_index_ensure")
    return world, surface
end
local previous_print = print
print = function() end
local result
if arg[3] == "same-terrain" then
    local side = (arg[1] or ""):match("16384") and 128 or 64
    local world, surface, positions = require("tests.performance.preserved_fixture")(side)
    world:build_tiles(surface, positions, "landfill")
    -- Deliberately NO visual work here: both modes drain the identical correct
    -- physical terrain and identical dry grid; only index bookkeeping differs.
    while tiles.getTileEventQueue().size > 0 do tiles.processTileEventQueue(8, { budget = 1000000 }) end
    for _, p in ipairs(positions) do assert(surface.get_tile(p).name == "landfill") end
    result = { overwritten = 0 }
else
    result = workloads.run(arg[1] or "pending_dense_4096")
end
print = previous_print
io.write("operation,calls,inclusive_s,self_s\n")
local keys = {}
for name in pairs(stats) do keys[#keys + 1] = name end
table.sort(keys)
for _, name in ipairs(keys) do
    local row = stats[name]
    io.write(string.format("%s,%d,%.6f,%.6f\n", name, row.calls, row.inclusive, row.self))
end
for name, value in pairs(counters) do io.write(string.format("%s,%d,0,0\n", name, value)) end
io.write(string.format("overwritten,%d,0,0\n", result.overwritten or 0))
