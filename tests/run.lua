local tests = {}
for file in io.popen("ls tests"):lines() do
    if file:match("^test_.*%.lua$") and file ~= "run.lua" then
        tests[#tests + 1] = file
    end
end

local failures = 0
for _, test in ipairs(tests) do
    print("Running " .. test)
    local ok, err = pcall(dofile, "tests/" .. test)
    if not ok then
        failures = failures + 1
        print("[ERROR] " .. err)
    end
    collectgarbage()
end

if failures > 0 then
    print(string.format("\n%d test file(s) failed", failures))
    os.exit(1)
else
    print("\nAll tests passed")
end
