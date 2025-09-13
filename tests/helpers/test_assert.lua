local M = {}

local passed, failed

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

function M.start()
    passed, failed = 0, 0
end

function M.ok(cond, name)
    if cond then
        passed = passed + 1
        printf("[PASS] %s", name)
    else
        failed = failed + 1
        printf("[FAIL] %s", name)
    end
end

function M.eq(a, b, name)
    local cond = (a == b)
    if not cond then
        printf("  expected: %s", tostring(b))
        printf("  got     : %s", tostring(a))
    end
    M.ok(cond, name)
end

function M.finish(label)
    print(string.rep("-", 30))
    printf("%s: %d passed, %d failed.", label, passed, failed)
    if failed == 0 then
        print("All good ✅")
    else
        print("Some tests failed ❌")
    end
end

return M
