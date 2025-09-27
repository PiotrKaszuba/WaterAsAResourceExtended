-- luacheck: globals os
---@diagnostic disable: undefined-global

function a(pos)
    local x, y = pos.x, pos.y
    return { x = x - x % 1, y = y - y % 1 }
end

function b(pos)
    return { x = math.floor(pos.x), y = math.floor(pos.y) }
end

local posx = {
    { x = 10,   y = 10 },
    { x = 10.5, y = 10.5 },
    { x = -10,  y = -10 },
    { x = -9.5, y = -9.5 },
}

local runs = 1000000

local function run_benchmark(fn, iterations)
    local checksum = 0
    local total_time = 0
    for i = 1, iterations do
        for _, pos in ipairs(posx) do
            local start_time = os.clock()
            local t = fn(pos)
            checksum = checksum + t.x + t.y
            total_time = total_time + os.clock() - start_time
        end
    end
    return checksum, total_time
end

local checksum_a, time_a = run_benchmark(a, runs)

local checksum_b, time_b = run_benchmark(b, runs)

print("Benchmark: modulo vs math.floor")
print(("Runs: %d x %d positions"):format(runs, #posx))
print(("----------------------------------------"))
print(("a (x - x%%1):        %.6fs  checksum=%d"):format(time_a, checksum_a))
print(("b (math.floor):     %.6fs  checksum=%d"):format(time_b, checksum_b))
print(("----------------------------------------"))
local faster = time_a < time_b and "a (x - x%1)" or "b (math.floor)"
print(("Faster: %s"):format(faster))
