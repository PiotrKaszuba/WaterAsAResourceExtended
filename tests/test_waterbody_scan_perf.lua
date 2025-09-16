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
            begin_value = budget.budget,
            end_value = budget.budget,
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

    if self.current and budget then
        self.current.end_value = budget.budget
        if budget.budget <= 0 then
            if not self.current.exhausted then
                    self.current.first_exhaust_tick = tick
            end
                self.current.exhausted = true
            end
    end
end

function BudgetCycleTracker:finish(tick)
    self:_finalize_cycle(tick)
end

function BudgetCycleTracker:summary()
    local exhausted = 0
    local total_budget = 0
    local total_used = 0
    for _, cycle in ipairs(self.cycles) do
        if cycle.exhausted then
            exhausted = exhausted + 1
        end
        total_budget = total_budget + cycle.begin_value
        total_used = total_used + (cycle.begin_value - cycle.end_value)
    end
    local total = #self.cycles
    local percent = total > 0 and exhausted / total or 0
    local percent_used_total = total_used > 0 and total_used / total_budget or 0
    return {
        total = total,
        exhausted = exhausted,
        percent = percent,
        percent_used_total = percent_used_total,
        cycles = self.cycles,
    }
end

local configs = {
    {name = "tiles-limited-low", tiles_per_sec = 120, update_budget = 150, expected_limiter = "tiles"},
    {name = "tiles-limited-mid", tiles_per_sec = 360, update_budget = 400, expected_limiter = "tiles"},
    {name = "balanced-400-403", tiles_per_sec = 400, update_budget = 403, expected_limiter = "balanced"},

    {name = "budget-limited-400-360", tiles_per_sec = 400, update_budget = 360, expected_limiter = "budget"},
    {name = "budget-limited-525-500", tiles_per_sec = 525, update_budget = 500, expected_limiter = "budget"},
    
    {name = "tiles-limited-10000-50000", tiles_per_sec = 10000, update_budget = 50000, expected_limiter = "tiles", side_size = 1000},


}

local function apply_scan_settings(cfg)
    settings.global["FluidArea-Additional-Tiles-Per-Second"] = {value = cfg.tiles_per_sec}
    settings.global["Update-Budget-Per-Second"] = {value = cfg.update_budget}
end

local function seed_large_water_body(world, surface, side_size)
    world:set_water_rectangle(surface, {x1 = 0, y1 = 0, x2 = side_size - 1, y2 = side_size - 1})
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

        mock.on_init()

        local side_size = cfg.side_size or 100
        seed_large_water_body(world, surface, side_size)

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

        return {
            cfg = cfg,
            ticks = ticks,
            seconds = ticks / 60,
            water_area = wbody.waterAreaData.TotalArea,
            budget_summary = budget_summary,
            search_queue_stats = queue_stats,
            side_size = side_size,
        }
    end)
end

local function classify_budget(percent_exhausted, percent_used_total)
    if percent_exhausted >= 95 then
        return "budget"
    elseif percent_used_total >= 95 then
        return "balanced"
    else
        return "tiles"
    end
end

local function run_config(cfg)
    run_mock_test(function()
        t.start(string.format("Scan performance validation: %s", cfg.name))

        local result = measure(cfg)
        local stats = result.search_queue_stats
        local budget_summary = result.budget_summary
        local percent_exhausted = budget_summary.percent * 100
        local percent_used_total = budget_summary.percent_used_total * 100
        local limiter_description = classify_budget(percent_exhausted, percent_used_total)
        local side_size = result.side_size

        local resulting_scans_per_second = stats and stats.enqueues / result.seconds or 0
        local resulting_tiles_per_second = result.water_area / result.seconds
        local effectiveness_of_scans_percentage = resulting_tiles_per_second / resulting_scans_per_second * 100
        print(string.format(
            "[%s] tiles/sec=%d budget=%d -> %d ticks (%.2f s), water area=%d, enqueues=%s, budget cycles=%d/%d (%.2f%%), budget used=%.2f%% => %s, scans/sec=%.2f, tiles added/sec=%.2f, scan effectiveness=%.2f%%",
            cfg.name,
            cfg.tiles_per_sec,
            cfg.update_budget,
            result.ticks,
            result.seconds,
            result.water_area,
            stats and tostring(stats.enqueues) or "nil",
            budget_summary.exhausted,
            budget_summary.total,
            percent_exhausted,
            percent_used_total,
            limiter_description,
            resulting_scans_per_second,
            resulting_tiles_per_second,
            effectiveness_of_scans_percentage
        ))

        t.eq(result.water_area, side_size * side_size, string.format("Water body area is %d for %s", side_size * side_size, cfg.name))

        t.ok(cfg.expected_limiter == limiter_description, string.format("Expected limiter: %s, got: %s", cfg.expected_limiter, limiter_description))

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
