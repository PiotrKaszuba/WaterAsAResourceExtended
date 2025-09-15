if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

local test_env = require("tests.helpers.test_env")
local world_mod = require("tests.mock.world")
local t = require("tests.helpers.test_assert")
local mock = require("tests.mock.factorio_runtime")
local run_mock_test = require("tests.helpers.mock_test")

local QueueProbe = {}
QueueProbe.__index = QueueProbe

function QueueProbe.attach(queue_utils)
    local queue_module = queue_utils.Queue
    local probe = setmetatable({
        queue_module = queue_module,
        original = {
            new = queue_module.new,
            enqueue = queue_module.enqueue,
            dequeue_back = queue_module.dequeue_back,
        },
        stats_by_queue = setmetatable({}, {__mode = "k"}),
    }, QueueProbe)

    queue_module.new = function(...)
        local queue = probe.original.new(...)
        probe.stats_by_queue[queue] = {
            enqueues = 0,
            enqueue_front = false,
            dequeue_back = false,
            grew = false,
            max_size = 0,
        }
        return queue
    end

    queue_module.enqueue = function(queue, value, at_front, ...)
        local stats = probe.stats_by_queue[queue]
        local capacity_before = queue.capacity
        local result = probe.original.enqueue(queue, value, at_front, ...)
        if stats and result then
            stats.enqueues = stats.enqueues + 1
            if at_front then
                stats.enqueue_front = true
            end
            if queue.capacity > capacity_before then
                stats.grew = true
            end
            if queue.size > stats.max_size then
                stats.max_size = queue.size
            end
        end
        return result
    end

    queue_module.dequeue_back = function(queue, ...)
        local stats = probe.stats_by_queue[queue]
        if stats then
            stats.dequeue_back = true
        end
        return probe.original.dequeue_back(queue, ...)
    end

    return probe
end

function QueueProbe:get_stats(queue)
    local stats = self.stats_by_queue[queue]
    if not stats then
        return nil
    end
    return {
        enqueues = stats.enqueues,
        enqueue_front = stats.enqueue_front,
        dequeue_back = stats.dequeue_back,
        max_size = stats.max_size,
        grew = stats.grew,
    }
end

function QueueProbe:restore()
    local queue_module = self.queue_module
    queue_module.new = self.original.new
    queue_module.enqueue = self.original.enqueue
    queue_module.dequeue_back = self.original.dequeue_back
end

local function with_queue_probe(queue_utils, fn)
    local probe = QueueProbe.attach(queue_utils)
    local ok, result = xpcall(function()
        return fn(probe)
    end, debug.traceback)
    probe:restore()
    if not ok then
        error(result)
    end
    return result
end

local function with_update_probes(fn)
    local scan_module = _G.waterbody_scan
    local control_module = _G.control

    local original_scan = scan_module.scanningUpdateAll
    local original_big_update = control_module.BigUpdate

    local samples = {
        scanning = {},
        big_update = {},
    }

    scan_module.scanningUpdateAll = function(updateBudget)
        local tick = mock.tick
        local water_body = storage.WaterBodies and storage.WaterBodies[1]
        local search_data = water_body and water_body.searchData or nil
        local queue_before = search_data and search_data.searchQueue and search_data.searchQueue.size or nil
        local area_before = search_data and search_data.totalArea or nil
        local budget_before = updateBudget and updateBudget.budget or nil

        local result = original_scan(updateBudget)

        water_body = storage.WaterBodies and storage.WaterBodies[1]
        search_data = water_body and water_body.searchData or nil
        local queue_after = search_data and search_data.searchQueue and search_data.searchQueue.size or nil
        local area_after = search_data and search_data.totalArea or nil
        local budget_after = updateBudget and updateBudget.budget or nil

        samples.scanning[#samples.scanning + 1] = {
            tick = tick,
            queue_before = queue_before,
            queue_after = queue_after,
            processed = (area_before and area_after) and (area_after - area_before) or nil,
            budget_spent = (budget_before and budget_after) and (budget_before - budget_after) or nil,
        }

        return result
    end

    control_module.BigUpdate = function(updateBudget, periodicTick)
        local tick = mock.tick
        local water_body = storage.WaterBodies and storage.WaterBodies[1]
        local search_data = water_body and water_body.searchData or nil
        local queue_before = search_data and search_data.searchQueue and search_data.searchQueue.size or nil
        local area_before = search_data and search_data.totalArea or nil
        local budget_before = updateBudget and updateBudget.budget or nil

        local result = original_big_update(updateBudget, periodicTick)

        water_body = storage.WaterBodies and storage.WaterBodies[1]
        search_data = water_body and water_body.searchData or nil
        local queue_after = search_data and search_data.searchQueue and search_data.searchQueue.size or nil
        local area_after = search_data and search_data.totalArea or nil
        local budget_after = updateBudget and updateBudget.budget or nil

        samples.big_update[#samples.big_update + 1] = {
            tick = tick,
            queue_before = queue_before,
            queue_after = queue_after,
            processed = (area_before and area_after) and (area_after - area_before) or nil,
            budget_spent = (budget_before and budget_after) and (budget_before - budget_after) or nil,
            periodic_tick = periodicTick,
        }

        return result
    end

    local ok, result = xpcall(function()
        return fn(samples)
    end, debug.traceback)

    scan_module.scanningUpdateAll = original_scan
    control_module.BigUpdate = original_big_update

    if not ok then
        error(result)
    end

    return result
end

local function analyze_performance(samples)
    local peak
    for _, entry in ipairs(mock.performance.ticks) do
        if not peak or entry.time > peak.time then
            peak = entry
        end
    end

    if not peak then
        return nil
    end

    local peak_tick = peak.tick
    local peak_sample = nil
    local stage = "other"

    for _, sample in ipairs(samples.scanning) do
        if sample.tick == peak_tick then
            peak_sample = sample
            stage = "scanning"
            break
        end
    end

    if not peak_sample then
        for _, sample in ipairs(samples.big_update) do
            if sample.tick == peak_tick then
                peak_sample = sample
                stage = "big-update"
                break
            end
        end
    end

    local ms = peak.time * 1000

    local detail = {
        tick = peak_tick,
        ms = ms,
        stage = stage,
    }

    if peak_sample then
        detail.queue_before = peak_sample.queue_before
        detail.queue_after = peak_sample.queue_after
        detail.processed = peak_sample.processed
        detail.budget_spent = peak_sample.budget_spent
    end

    return detail
end

local BudgetCycleTracker = {}
BudgetCycleTracker.__index = BudgetCycleTracker

function BudgetCycleTracker.new(initial_budget, tick)
    local tracker = setmetatable({
        cycles = {},
        current = nil,
        last_budget = nil,
    }, BudgetCycleTracker)
    tracker:_begin_cycle(initial_budget, tick)
    return tracker
end

function BudgetCycleTracker:_begin_cycle(budget, tick)
    self.last_budget = budget
    if budget then
        self.current = {
            start_tick = tick,
            exhausted = budget.budget <= 0,
            first_exhaust_tick = budget.budget <= 0 and tick or nil,
        }
    else
        self.current = nil
    end
end

function BudgetCycleTracker:_finalize_cycle(tick)
    if not self.current then
        return
    end
    self.current.end_tick = tick
    self.current.duration = tick - self.current.start_tick
    if self.current.duration > 0 then
        table.insert(self.cycles, self.current)
    end
    self.current = nil
end

function BudgetCycleTracker:update(budget, tick)
    if budget ~= self.last_budget then
        self:_finalize_cycle(tick)
        self:_begin_cycle(budget, tick)
        return
    end

    if self.current and budget and budget.budget <= 0 then
        if not self.current.exhausted then
            self.current.first_exhaust_tick = tick
        end
        self.current.exhausted = true
    end
end

function BudgetCycleTracker:finish(tick)
    self:_finalize_cycle(tick)
end

function BudgetCycleTracker:summary()
    local exhausted = 0
    for _, cycle in ipairs(self.cycles) do
        if cycle.exhausted then
            exhausted = exhausted + 1
        end
    end
    local total = #self.cycles
    local percent = total > 0 and exhausted / total or 0
    return {
        total = total,
        exhausted = exhausted,
        percent = percent,
        cycles = self.cycles,
    }
end

local configs = {
    {name = "tiles-limited-low", tiles_per_sec = 120, update_budget = 600, expected_limiter = "tiles"},
    {name = "tiles-limited-mid", tiles_per_sec = 360, update_budget = 540, expected_limiter = "tiles"},
    {name = "balanced-600-400", tiles_per_sec = 600, update_budget = 400, expected_limiter = "balanced"},
    {name = "balanced-720-400", tiles_per_sec = 720, update_budget = 400, expected_limiter = "balanced"},
    {name = "budget-limited-600-360", tiles_per_sec = 600, update_budget = 360, expected_limiter = "budget"},
    {name = "budget-limited-720-360", tiles_per_sec = 720, update_budget = 360, expected_limiter = "budget"},
    {name = "budget-limited-1200-150", tiles_per_sec = 1200, update_budget = 150, expected_limiter = "budget"},
    {name = "budget-limited-1800-300", tiles_per_sec = 1800, update_budget = 300, expected_limiter = "budget"},
}

local function apply_scan_settings(cfg)
    settings.global["FluidArea-Additional-Tiles-Per-Second"] = {value = cfg.tiles_per_sec}
    settings.global["Update-Budget-Per-Second"] = {value = cfg.update_budget}
end

local function seed_large_water_body(world, surface)
    world:set_water_rectangle(surface, {x1 = 0, y1 = 0, x2 = 99, y2 = 99})
    world:build_entity({
        name = "offshore-pump",
        type = "offshore-pump",
        position = {x = 0, y = -1},
        surface = surface,
        input_position = {x = 0, y = 0},
    })
end

local function measure(cfg)
    test_env.reset_world()
    require("modules.utils")
    local queue_utils = _G.utils

    return with_queue_probe(queue_utils, function(probe)
        apply_scan_settings(cfg)

        local world = world_mod.World.new()
        local surface = world:create_surface("nauvis")
        require("control")

        return with_update_probes(function(samples)
            mock.on_init()

            seed_large_water_body(world, surface)

            local ticks = 0
            local tracker = BudgetCycleTracker.new(storage.CurrentUpdateBudget, ticks)
            local wbody

            while true do
                test_env.run_ticks(1)
                ticks = ticks + 1

                local current_budget = storage.CurrentUpdateBudget
                tracker:update(current_budget, ticks)

                wbody = storage.WaterBodies and storage.WaterBodies[1]
                if wbody and wbody.searchData.finished then
                    break
                end

                if ticks > 30000 then
                    error(string.format("Scanning did not finish for %s", cfg.name))
                end
            end

            tracker:finish(ticks)
            local budget_summary = tracker:summary()

            local search_queue = wbody.searchData.searchQueue
            local queue_stats = probe:get_stats(search_queue)
            local performance_detail = analyze_performance(samples)

            return {
                cfg = cfg,
                ticks = ticks,
                seconds = ticks / 60,
                water_area = wbody.waterAreaData.TotalArea,
                budget_summary = budget_summary,
                search_queue_stats = queue_stats,
                search_total_area = wbody.searchData.totalArea,
                performance_detail = performance_detail,
            }
        end)
    end)
end

local function classify_budget(percent)
    if percent >= 0.9 then
        return "budget-limited"
    elseif percent <= 0.1 then
        return "tiles-limited"
    else
        return "balanced"
    end
end

local function describe_peak(detail)
    if not detail then
        return nil
    end

    local function format_number(value, fmt, fallback)
        if value == nil then
            return fallback or "n/a"
        end
        return string.format(fmt or "%d", value)
    end

    local context
    if detail.stage == "scanning" then
        context = string.format(
            "scanning update processed %s tiles (queue %s -> %s, budget spent %s)",
            format_number(detail.processed, "%d"),
            format_number(detail.queue_before, "%d"),
            format_number(detail.queue_after, "%d"),
            format_number(detail.budget_spent, "%.2f")
        )
    elseif detail.stage == "big-update" then
        context = string.format(
            "big update adjusted queue %s -> %s (budget spent %s)",
            format_number(detail.queue_before, "%d"),
            format_number(detail.queue_after, "%d"),
            format_number(detail.budget_spent, "%.2f")
        )
    else
        context = "no instrumented data captured for this tick"
    end

    return string.format(
        "    Peak tick %d (%.3f ms): %s",
        detail.tick,
        detail.ms,
        context
    )
end

local function run_config(cfg)
    run_mock_test(function()
        t.start(string.format("Scan performance validation: %s", cfg.name))

        local result = measure(cfg)
        local stats = result.search_queue_stats
        local budget_summary = result.budget_summary
        local percent_exhausted = budget_summary.percent * 100
        local limiter_description = classify_budget(budget_summary.percent)

        print(string.format(
            "[%s] tiles/sec=%d budget=%d -> %d ticks (%.2f s), search area=%d, enqueues=%s, budget cycles=%d/%d (%.2f%%) => %s",
            cfg.name,
            cfg.tiles_per_sec,
            cfg.update_budget,
            result.ticks,
            result.seconds,
            result.search_total_area,
            stats and tostring(stats.enqueues) or "nil",
            budget_summary.exhausted,
            budget_summary.total,
            percent_exhausted,
            limiter_description
        ))

        local peak_message = describe_peak(result.performance_detail)
        if peak_message then
            print(peak_message)
        end

        t.eq(result.water_area, 10000, string.format("Water body area is 10k for %s", cfg.name))

        if cfg.expected_limiter == "budget" then
            t.ok(
                budget_summary.percent >= 0.9,
                string.format("Budget exhaustion: budget-limited for %s", cfg.name)
            )
        elseif cfg.expected_limiter == "tiles" then
            t.ok(
                budget_summary.percent <= 0.1,
                string.format("Budget exhaustion: tiles-limited for %s", cfg.name)
            )
        end

        t.ok(
            stats and not stats.enqueue_front and not stats.dequeue_back,
            string.format(
                "Result validation OK for %s (stats missing or unexpected queue operations would indicate a problem)",
                cfg.name
            )
        )

        t.finish(string.format("Scan performance results: %s", cfg.name))
    end)
end

local function run_suite(configs)
    for _, cfg in ipairs(configs) do
        run_config(cfg)
    end
end

run_suite(configs)
