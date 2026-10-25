-- Observation only, appended to the staged mod by run_dry_bed_repro.py.
-- No changes to reserves, budgets, ownership, event delivery or update order.
local counts = { scans = 0, edges = 0, split_checks = 0, splits = 0, merges = 0, new_bodies = 0 }
local function members(main, lazy)
    local seen, n, duplicates = {}, 0, 0
    local function add(t)
        for key in pairs(t) do
            if seen[key] then duplicates = duplicates + 1 else seen[key] = true; n = n + 1 end
        end
    end
    add(main)
    for _, t in ipairs(lazy) do add(t) end
    return n, duplicates
end
local function snapshot()
    local s = { tick = game.tick, periodic = storage.PeriodicTick, bodies = {},
        queued = storage.TileEventQueue.size, counts = {} }
    for k, v in pairs(counts) do s.counts[k] = v end
    for id, body in pairs(storage.ValidWaterBodies) do
        local g, state = body.gridsData, body.waterBodyStateData
        local dry, duplicates = members(g.driedTilesGridWithData, g.lazyDriedTilesGridWithData)
        local wet = members(g.waterGridWithData, g.lazyWaterGridWithData)
        s.bodies[#s.bodies + 1] = { id = id, area = body.waterAreaData.TotalArea,
            capacity = body.waterAreaData.AmountWtr,
            remaining = waterbodies.calculateRemainingWater(body) - state.TempUsedWater,
            finished = body.searchData.finished, actual_dry = dry, recorded_dry = state.DriedTiles,
            gap = dry - state.DriedTiles, wet = wet, duplicates = duplicates,
            to_dry = state.ToDryTiles, depleted = state.Depleted, pumps = #state.Pumps }
    end
    table.sort(s.bodies, function(a, b) return a.id < b.id end)
    return s
end
local function trace(kind, extra)
    helpers.write_file('internals.jsonl', helpers.table_to_json({ kind = kind,
        extra = extra, state = snapshot() }) .. '\n', true)
end
remote.add_interface('water_exact_repro', { snapshot = snapshot })
for _, spec in ipairs({ { waterbody_scan, 'EdgePattern', 'edges' },
    { waterbodies, 'createNewWaterBody', 'new_bodies' } }) do
    local module, name, field = spec[1], spec[2], spec[3]
    local original = module[name]
    module[name] = function(...)
        counts[field] = counts[field] + 1
        return original(...)
    end
end
local scan = waterbody_scan.ScanWaterArea
waterbody_scan.ScanWaterArea = function(...)
    counts.scans = counts.scans + 1
    local finished, body = scan(...)
    for _, b in ipairs(snapshot().bodies) do
        if b.gap ~= 0 then trace('gap-after-scan', { id = b.id, gap = b.gap }) end
    end
    return finished, body
end
local split = waterbody_split.checkIfWaterBodyGotSplit
waterbody_split.checkIfWaterBodyGotSplit = function(id, ...)
    counts.split_checks = counts.split_checks + 1
    local body = waterbodies.getWaterBody(id)
    local result = split(id, ...)
    if body and not body.valid then counts.splits = counts.splits + 1; trace('split', { parent = id }) end
    return result
end
local merge = waterbody_merge.mergeWaterBody
waterbody_merge.mergeWaterBody = function(a, b)
    local ids = { a.waterBodyId, b.waterBodyId }
    counts.merges = counts.merges + 1
    trace('before-merge', { ids = ids })
    local result = merge(a, b)
    trace('after-merge', { ids = ids, survivor = result })
    return result
end
