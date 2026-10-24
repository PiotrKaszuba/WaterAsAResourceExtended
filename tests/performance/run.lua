-- Run separately from the fast correctness suite. CPU time includes mock API
-- implementations and their deterministic iteration; it is not Factorio UPS.
local workloads = require("tests.performance.workloads")
local repeats = tonumber(arg[1]) or 7
local filter = arg[2]
local label = arg[3] or "checkout"
assert(repeats >= 1)
local output = io.write
local normal_print = print
-- Mod/mock warnings are not timed console I/O. Assertions still fail normally.
print = function() end
output("label,case,sample,metric,value\n")
for _, name in ipairs(workloads.cases) do
    if not filter or name:find(filter, 1, true) then
        for sample = 0, repeats do
            collectgarbage("collect")
            local ok, result = xpcall(function() return workloads.run(name) end, debug.traceback)
            if not ok then print = normal_print; error(result) end
            if sample > 0 then
                local keys = {}
                for key in pairs(result) do keys[#keys + 1] = key end
                table.sort(keys)
                for _, key in ipairs(keys) do
                    output(string.format("%s,%s,%d,%s,%.9f\n", label, name, sample, key, result[key]))
                end
            end
        end
    end
end
print = normal_print
