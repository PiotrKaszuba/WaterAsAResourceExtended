-- Shared, deterministic workloads. Timed regions exclude fixture construction.
-- No optional-branch imports: this exact file also runs on master.
local env = require("tests.helpers.test_env")
local M = {}
local active_ticks

local function distribution(result, prefix, values)
    if #values == 0 then return end
    table.sort(values)
    local total = 0
    for _, value in ipairs(values) do total = total + value end
    result[prefix .. "_count"] = #values
    result[prefix .. "_mean_s"] = total / #values
    result[prefix .. "_p50_s"] = values[math.ceil(#values * 0.5)]
    result[prefix .. "_p95_s"] = values[math.ceil(#values * 0.95)]
    result[prefix .. "_p99_s"] = values[math.ceil(#values * 0.99)]
    result[prefix .. "_max_s"] = values[#values]
end

local function measure(result, name, fn)
    local ticks, scans = {}, {}
    local previous_ticks = active_ticks
    active_ticks = ticks
    local scan = waterbody_scan and waterbody_scan.scanningUpdateAll
    if scan then
        waterbody_scan.scanningUpdateAll = function(...)
            local start = os.clock()
            local value = scan(...)
            scans[#scans + 1] = os.clock() - start
            return value
        end
    end
    local start = os.clock()
    local value = fn()
    result[name] = os.clock() - start
    if scan then waterbody_scan.scanningUpdateAll = scan end
    active_ticks = previous_ticks
    distribution(result, name .. "_tick", ticks)
    distribution(result, name .. "_scan_slice", scans)
    return value
end

local function fixture(side, pumps)
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    settings.global["Map-EnableMarkers"].value = false
    settings.global["Alarms-Tile-Message"].value = false
    settings.global["Scan-Tiles-Per-Second"].value = 100000
    storage.UpdateBudget = 100000
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = side - 1, y2 = side - 1 })
    for i = 1, pumps or 1 do
        world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
            position = { x = i - 1, y = -1 }, input_position = { x = 0, y = 0 } })
    end
    return world, surface
end

local function settle(limit)
    for tick = 1, limit or 10000 do
        local start = os.clock()
        env.run_ticks(1)
        if active_ticks then active_ticks[#active_ticks + 1] = os.clock() - start end
        local done = tiles.getTileEventQueue().size == 0
        for _, body in pairs(storage.ValidWaterBodies) do
            if not body.searchData.finished or body.waterBodyStateData.ToDryTiles ~= 0 then done = false end
        end
        if done and tick > 120 then return tick end
    end
    error("workload failed to settle within its explicit tick bound")
end

local function ready(side, pumps)
    local world, surface = fixture(side, pumps)
    settle()
    local body = assert(storage.WaterBodies[1])
    assert(body.valid and body.searchData.finished)
    assert(body.waterBodyShapeData.Area == nil or body.waterAreaData.AmountWtr > 0)
    return world, surface, body
end

local function drain(result, batch)
    local calls, max_call = 0, 0
    local batches = {}
    measure(result, "drain_s", function()
        while tiles.getTileEventQueue().size > 0 do
            local before = os.clock()
            local processed = tiles.processTileEventQueue(batch, { budget = 1000000 })
            local elapsed = os.clock() - before
            max_call = math.max(max_call, elapsed)
            batches[#batches + 1] = elapsed
            assert(processed > 0 and processed <= batch)
            calls = calls + 1
            assert(calls < 100000, "bounded queue drain")
        end
    end)
    result.drain_calls, result.max_drain_call_s = calls, max_call
    distribution(result, "drain_batch", batches)
    if storage.PendingTileChanges then assert(next(storage.PendingTileChanges) == nil, "pending index must be cleaned") end
    return batches
end

M.cases = {
    "scan_4096", "scan_16384", "scan_65536", "scan_262144",
    "pumps_256", "pumps_1024_many_lakes", "visual_cycles", "visual_16384",
    "queue_unique_8192", "queue_repeated_8192", "shoreline_brush", "split_reopen",
    "pending_sparse", "pending_dense_1024", "pending_dense_4096", "pending_dense_16384",
    "pending_drying_4096", "mixed_backlog_scan", "pending_reload_8192", "dry_merge_16384",
    "repair_wet_262144", "repair_dry_65536",
}

function M.run(name)
    local result = {}
    if name:match("^repair_") then
        local dry = name:match("^repair_dry_") ~= nil
        local area = tonumber(name:match("%d+"))
        local _, _, body = ready(math.sqrt(area))
        if not waterbodies.repairScanAccounting then
            result.supported = 0
            return result
        end
        if dry then
            body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr
            env.run_ticks(600)
            assert(body.waterBodyStateData.DriedTiles == area, "repair fixture must be fully dry")
        end
        local remaining = waterbodies.calculateRemainingWater(body)
        body.waterBodyStateData.DriedTiles = -1
        body.searchData.totalArea = -1
        collectgarbage("collect")
        local memory = collectgarbage("count")
        measure(result, "repair_s", waterbodies.repairScanAccounting)
        result.allocated_kib = collectgarbage("count") - memory
        result.tiles, result.supported = area, 1
        assert(body.waterBodyStateData.DriedTiles == (dry and area or 0))
        assert(body.searchData.totalArea == area and body.waterBodyShapeData.TileCount == area)
        assert(waterbodies.calculateRemainingWater(body) == remaining, "repair must not change reserve")
    elseif name == "dry_merge_16384" then
        local world, surface, body = ready(128)
        settings.global["Cleanup-Remove-Depleted-Orphaned"].value = false
        for _, x in ipairs({ 16, 32, 48, 80, 96, 127 }) do
            world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
                position = { x = x, y = -1 }, input_position = { x = x, y = 0 } })
        end
        body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * 0.98
        env.run_ticks(600)
        local original, merges = waterbody_merge.mergeWaterBody, 0
        waterbody_merge.mergeWaterBody = function(...)
            merges = merges + 1
            return original(...)
        end
        result.ticks = measure(result, "lifecycle_s", function()
            for y = 0, 127 do
                world:build_tiles(surface, { { x = 63, y = y }, { x = 64, y = y } }, "landfill")
                env.run_ticks(7)
            end
            -- Fixed window: broken counters may leave impossible visual work,
            -- so waiting for ToDryTiles == 0 would conceal the baseline cost.
            env.run_ticks(4000)
            return 4896
        end)
        waterbody_merge.mergeWaterBody = original
        result.merges, result.counter_gap, result.visual_work_left = merges, 0, 0
        for _, b in pairs(storage.ValidWaterBodies) do
            local count, seen = 0, {}
            local function add(grid) for key in pairs(grid) do
                if not seen[key] then seen[key] = true; count = count + 1 end
            end end
            add(b.gridsData.driedTilesGridWithData)
            for _, grid in ipairs(b.gridsData.lazyDriedTilesGridWithData) do add(grid) end
            result.counter_gap = result.counter_gap + math.abs(count - b.waterBodyStateData.DriedTiles)
            result.visual_work_left = result.visual_work_left + math.abs(b.waterBodyStateData.ToDryTiles)
            assert(b.searchData.finished, "large dry merge scans must settle")
        end
    elseif name:match("^scan_") then
        local side = math.sqrt(tonumber(name:match("%d+")))
        fixture(side)
        result.ticks = measure(result, "scan_s", settle)
        assert(storage.WaterBodies[1].waterAreaData.AmountWtr == side * side * 50)
        result.tiles = side * side
    elseif name == "pumps_1024_many_lakes" then
        local world, surface = env.create_world()
        settings.global["Waterbody-Regen-Rate"].value = 0
        settings.global["Map-EnableMarkers"].value = false
        settings.global["Alarms-Tile-Message"].value = false
        storage.UpdateBudget = 100000
        for lake = 0, 63 do
            local x = (lake % 8) * 16
            local y = math.floor(lake / 8) * 16
            world:set_water_rectangle(surface, { x1 = x, y1 = y, x2 = x + 7, y2 = y + 7 })
            for pump = 1, 16 do
                world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
                    position = { x = x + pump, y = y - 1 }, input_position = { x = x, y = y } })
            end
        end
        settle()
        local bodies, pumps = 0, 0
        for _, body in pairs(storage.ValidWaterBodies) do
            bodies = bodies + 1
            pumps = pumps + #body.waterBodyStateData.Pumps
            for i, pump in ipairs(body.waterBodyStateData.Pumps) do
                -- A mix of active, idle and inactive pumps, without draining the
                -- fixture completely during this direct hot-path measurement.
                pump.entity.pumped_last_tick = i % 3 == 0 and 0.01 or 0
                if i % 4 == 0 then pump.entity.disabled_by_script = true end
            end
        end
        assert(bodies == 64 and pumps == 1024)
        measure(result, "collect_s", function()
            for _ = 1, 1000 do waterbody_update.collectWaterUsageStats() end
        end)
        local used = 0
        for _, b in pairs(storage.ValidWaterBodies) do used = used + b.waterBodyStateData.TempUsedWater end
        assert(used > 0 and used < 10000, "mixed pumps collect plausible, nonzero extraction")
        result.pump_samples = 1024 * 1000
    elseif name == "pumps_256" then
        local _, _, body = ready(8, 256)
        assert(#body.waterBodyStateData.Pumps == 256)
        local before = body.waterBodyStateData.TempUsedWater
        measure(result, "collect_s", function()
            for _ = 1, 2000 do waterbody_update.collectWaterUsageStats() end
        end)
        assert(body.waterBodyStateData.TempUsedWater == before, "idle pumps must not consume water")
        result.pump_samples = 256 * 2000
    elseif name == "visual_cycles" or name == "visual_16384" then
        local side = name == "visual_cycles" and 32 or 128
        local area = side * side
        local cycles = name == "visual_cycles" and 24 or 4
        local _, surface, body = ready(side)
        local drying, restoring = {}, {}
        measure(result, "visual_s", function()
            for _ = 1, cycles do
                for _, dry in ipairs({ true, false }) do
                    local changed = 0
                    local start = os.clock()
                    for _ = 1, area / 64 do changed = changed + waterbody_depletion.getTilesDepleting(body, dry, 64) end
                    local samples = dry and drying or restoring
                    samples[#samples + 1] = os.clock() - start
                    assert(changed == area, "all requested terrain must change without pending edits")
                end
            end
        end)
        distribution(result, "dry_cycle", drying)
        distribution(result, "restore_cycle", restoring)
        assert(body.waterBodyStateData.DriedTiles == 0 and surface.get_tile({ x = 0, y = 0 }).name == "water")
        result.changed = cycles * area * 2
    elseif name == "queue_unique_8192" or name == "queue_repeated_8192" or name == "pending_reload_8192" then
        local _, surface = ready(8)
        -- Isolate queue/index maintenance from topology: ignored, unowned terrain.
        -- Real landfill dispatch still executes; repeated entries model edit churn.
        local unique = name ~= "queue_repeated_8192"
        collectgarbage("collect")
        local memory_before = collectgarbage("count")
        local function enqueue()
            for i = 1, 8192 do
                tiles.addTileEvent("landfill", { x = 1000 + (unique and i or i % 16), y = 0 }, surface,
                    { originalTileName = "water" })
            end
        end
        measure(result, "enqueue_s", enqueue)
        collectgarbage("collect")
        result.retained_queue_kib = collectgarbage("count") - memory_before
        assert(tiles.getTileEventQueue().size == 8192)
        if name == "pending_reload_8192" then
            -- Same old-save/configuration reconstruction call-site, when present.
            -- Baseline has no derived map to rebuild; do not invent equivalent work.
            measure(result, "rebuild_s", function()
                if tiles.rebuildPendingTileChanges then
                    for _ = 1, 32 do tiles.rebuildPendingTileChanges() end
                end
            end)
        end
        local all_batches = drain(result, 32)
        -- Batch enough real operations to exceed the native clock's resolution.
        for _ = 1, 15 do
            local batch = {}
            measure(batch, "enqueue_s", enqueue)
            local batches = drain(batch, 32)
            for _, elapsed in ipairs(batches) do all_batches[#all_batches + 1] = elapsed end
            result.enqueue_s = result.enqueue_s + batch.enqueue_s
            result.drain_s = result.drain_s + batch.drain_s
            result.max_drain_call_s = math.max(result.max_drain_call_s, batch.max_drain_call_s)
        end
        result.events = 8192 * 16
        result.drain_calls = 256 * 16
        distribution(result, "drain_batch", all_batches)
    elseif name == "shoreline_brush" then
        local world, surface, body = ready(48)
        body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * 0.4
        local positions = {}
        for x = 0, 47 do for y = 0, 3 do positions[#positions + 1] = { x = x, y = y } end end
        measure(result, "enqueue_s", function() world:build_tiles(surface, positions, "landfill") end)
        drain(result, 8)
        result.ticks = measure(result, "settle_s", settle)
        local total = 0
        for _, b in pairs(storage.ValidWaterBodies) do total = total + waterbodies.calculateRemainingWater(b) end
        assert(math.abs(total - (48 * 48 - #positions) * 50 * 0.6) < 1e-6, "brush must conserve depletion")
        result.events = #positions
    elseif name == "split_reopen" then
        local world, surface = env.create_world()
        settings.global["Waterbody-Regen-Rate"].value = 0
        settings.global["Map-EnableMarkers"].value = false
        settings.global["Alarms-Tile-Message"].value = false
        settings.global["Scan-Tiles-Per-Second"].value = 10000
        storage.UpdateBudget = 500
        local cuts = {}
        for lake = 0, 7 do
            local y = lake * 12
            world:set_water_rectangle(surface, { x1 = 0, y1 = y, x2 = 23, y2 = y + 7 })
            for row = y, y + 7 do cuts[#cuts + 1] = { x = 12, y = row } end
            world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
                position = { x = 0, y = y - 1 }, input_position = { x = 0, y = y } })
        end
        settle(20000)
        for _, b in pairs(storage.ValidWaterBodies) do
            b.waterBodyStateData.WaterUsed = b.waterAreaData.AmountWtr * 0.4
        end
        result.cover_ticks = measure(result, "cover_s", function()
            world:build_tiles(surface, cuts, "landfill", true)
            return settle(20000)
        end)
        local before = 0
        for _, b in pairs(storage.ValidWaterBodies) do before = before + waterbodies.calculateRemainingWater(b) end
        result.reopen_ticks = measure(result, "reopen_s", function()
            world:mine_tiles(surface, cuts, true)
            return settle(20000)
        end)
        local after = 0
        for _, b in pairs(storage.ValidWaterBodies) do after = after + waterbodies.calculateRemainingWater(b) end
        assert(math.abs(before - after) < 1e-6, "reopening split lakes must add zero water")
        result.events = #cuts * 2
    elseif name == "mixed_backlog_scan" then
        local world, surface, body = ready(64)
        waterbody_depletion.getTilesDepleting(body, true, 4096)
        local positions = {}
        for x = 0, 63 do for y = 0, 31 do positions[#positions + 1] = { x = x, y = y } end end
        world:build_tiles(surface, positions, "landfill")
        body.waterBodyStateData.ToDryTiles = -4096
        world:set_water_rectangle(surface, { x1 = 200, y1 = 0, x2 = 327, y2 = 127 })
        world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
            position = { x = 200, y = -1 }, input_position = { x = 200, y = 0 } })
        settings.global["Scan-Tiles-Per-Second"].value = 1000
        storage.UpdateBudget = 2000
        result.ticks = measure(result, "lifecycle_s", function() return settle(20000) end)
        assert(tiles.getTileEventQueue().size == 0)
        result.events = #positions
        result.overwritten = 0
        for _, p in ipairs(positions) do
            if surface.get_tile(p).name ~= "landfill" then result.overwritten = result.overwritten + 1 end
        end
        if storage.PendingTileChanges then assert(next(storage.PendingTileChanges) == nil) end
    elseif name:match("^pending_") then
        local side = name == "pending_dense_16384" and 128 or
            ((name == "pending_dense_4096" or name == "pending_drying_4096") and 64 or 32)
        local world, surface, body = ready(side)
        local area = side * side
        local drying = name == "pending_drying_4096"
        if not drying then assert(waterbody_depletion.getTilesDepleting(body, true, area) == area) end
        local stack, grids = body.gridsData.driedStack, body.gridsData
        local positions = {}
        local overlap = name == "pending_sparse" and math.floor(area * 0.02) or math.floor(area * 0.95)
        -- Put pending records first in the actual restoration selection order.
        if drying then
            for x = 0, side - 1 do for y = 0, side - 1 do
                if #positions < overlap then positions[#positions + 1] = { x = x, y = y } end
            end end
        else
            for offset = stack.size - 1, stack.size - overlap, -1 do
                local key = stack.buffer[(stack.head + offset - 1) % stack.capacity + 1]
                positions[#positions + 1] = utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData).position
            end
        end
        measure(result, "enqueue_s", function() world:build_tiles(surface, positions, "landfill") end)
        local changed, examined, max_call = 0, nil, 0
        local calls = {}
        measure(result, "visual_s", function()
            -- Finite requests while events are pending: models a delayed queue,
            -- rather than accidentally draining it before the interesting work.
            for _ = 1, area * 2 do
                local start = os.clock()
                local n, attempts = waterbody_depletion.getTilesDepleting(body, drying, 1)
                local elapsed = os.clock() - start
                max_call = math.max(max_call, elapsed)
                calls[#calls + 1] = elapsed
                changed = changed + n
                if attempts then examined = (examined or 0) + attempts end
            end
        end)
        distribution(result, "visual_request", calls)
        local overwritten = 0
        for _, p in ipairs(positions) do if surface.get_tile(p).name ~= "landfill" then overwritten = overwritten + 1 end end
        result.changed, result.examined, result.overwritten = changed, examined, overwritten
        result.max_visual_call_s, result.events = max_call, #positions
        -- Both variants must progress on unaffected terrain. The known baseline
        -- overwrite defect is measured, not concealed by a fake common invariant.
        assert(changed >= area - overlap and changed <= area)
        assert(tiles.getTileEventQueue().size == overlap, "visual work must preserve FIFO accounting")
        drain(result, 8)
    else error("unknown performance workload: " .. name) end
    return result
end

return M
