-- Uninstrumented attribution control: same landfill and dry-grid state.
local modes = require("tests.performance.guard_mode")
local fixture = require("tests.performance.preserved_fixture")
local repeats = tonumber(arg[1]) or 3
local previous_print = print
print = function() end
io.write("label,case,sample,metric,value\n")
for sample = 0, repeats do
    local order = sample % 2 == 0 and { true, false } or { false, true }
    for _, on in ipairs(order) do
        modes.set(on)
        collectgarbage("collect")
        local world, surface, positions = fixture(64)
        local start = os.clock()
        world:build_tiles(surface, positions, "landfill")
        local enqueued = os.clock() - start
        start = os.clock()
        local consumed = 0
        while tiles.getTileEventQueue().size > 0 do
            consumed = consumed + tiles.processTileEventQueue(8, { budget = 1000000 })
        end
        local drained = os.clock() - start
        assert(consumed == #positions)
        for _, p in ipairs(positions) do assert(surface.get_tile(p).name == "landfill") end
        if storage.PendingTileChanges then assert(next(storage.PendingTileChanges) == nil) end
        if sample > 0 then
            for name, value in pairs({ enqueue_s = enqueued, drain_s = drained, events = consumed, overwritten = 0 }) do
                io.write(string.format("%s,preserved_4096,%d,%s,%.9f\n", on and "preserved-on" or "preserved-off", sample, name, value))
            end
        end
    end
end
modes.set(true)
print = previous_print
