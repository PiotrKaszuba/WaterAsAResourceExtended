local t = require("tests.helpers.test_assert")

local tests = {}
for file in io.popen("ls tests"):lines() do
    if file:match("^test_.*%.lua$") and file ~= "run.lua" then
        tests[#tests + 1] = file
    end
end

local function sep(char)
    print(string.rep(char, 30))
end

local file_failures = 0
local reports = {}
for _, test in ipairs(tests) do
    sep("=")
    print("Running " .. test)
    sep("-")
    -- reset assertion counters in case the test forgets to call t.start()
    t.start()

    local ok, err = pcall(dofile, "tests/" .. test)

    local passed, failed = t.get_counts()
    local failures = {}
    do
        local f = t.get_failures()
        for i = 1, #f do failures[i] = f[i] end
    end

    if not ok or failed > 0 then
        file_failures = file_failures + 1
        if not ok then
            print("[ERROR] " .. err)
        end
    end

    reports[#reports + 1] = {
        name = test,
        passed = passed,
        failed = failed,
        failures = failures,
        runtime_error = not ok and err or nil,
    }
    sep("=")
    collectgarbage()
end

if #tests == 0 then
    print("No tests found! (Discovery of tests does not work on Windows)")
    os.exit(1)
end

if file_failures > 0 then
    print("\nFailure summary:")
    for _, r in ipairs(reports) do
        if r.runtime_error or r.failed > 0 then
            print("- " .. r.name)
            if r.runtime_error then
                print("  runtime error: " .. r.runtime_error)
            end
            for _, name in ipairs(r.failures) do
                print("  [FAIL] " .. tostring(name))
            end
        end
    end
    print(string.format("\n%d test file(s) failed", file_failures))
    os.exit(1)
else
    print("\nAll tests passed")
end
