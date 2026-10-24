-- Paired, alternately ordered on/off comparisons in the same Lua process.
-- Timings are evidence, not fragile pass/fail percentage gates.
local modes = require("tests.performance.guard_mode")
local workloads = require("tests.performance.workloads")
local repeats = tonumber(arg[1]) or 7
local cases = { "pumps_1024_many_lakes", "visual_16384", "queue_unique_8192", "queue_repeated_8192",
    "pending_reload_8192", "pending_dense_16384", "pending_drying_4096", "mixed_backlog_scan" }
local normal_print = print
print = function() end
io.write("label,case,sample,metric,value\n")
for _, name in ipairs(cases) do
    for sample = 0, repeats do
        local order = sample % 2 == 0 and { true, false } or { false, true }
        for _, on in ipairs(order) do
            modes.set(on)
            collectgarbage("collect")
            local ok, result = xpcall(function() return workloads.run(name) end, debug.traceback)
            if not ok then print = normal_print; error(result) end
            if result.overwritten then
                assert(on and result.overwritten == 0 or not on and result.overwritten > 0,
                    "comparison must exercise the intended terrain race in both modes")
            end
            if result.examined and on then
                local area = name == "pending_dense_16384" and 16384 or 4096
                assert(result.examined <= area * 2, "candidate work must stay within requested attempts")
            end
            if sample > 0 then
                local keys = {}
                for key in pairs(result) do keys[#keys + 1] = key end
                table.sort(keys)
                for _, key in ipairs(keys) do
                    io.write(string.format("%s,%s,%d,%s,%.9f\n", on and "paired-on" or "paired-off",
                        name, sample, key, result[key]))
                end
            end
        end
    end
end
modes.set(true)
print = normal_print
