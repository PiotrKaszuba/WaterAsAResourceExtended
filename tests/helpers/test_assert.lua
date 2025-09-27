local M = {}

local passed, failed, failures

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

function M.print(msg)
    printf("[INFO] %s", msg)
end

function M.start(msg)
    passed, failed = 0, 0
    failures = {}
    if msg then
        print(msg)
    end
end

function M.ok(cond, name)
    if cond then
        passed = passed + 1
        printf("[PASS] %s", name)
    else
        failed = failed + 1
        printf("[FAIL] %s", name)
        if failures then
            failures[#failures + 1] = name or "(unnamed assertion)"
        end
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

-- Introspection helpers for runners
function M.get_counts()
    return passed or 0, failed or 0
end

function M.get_failures()
    return failures or {}
end

function M.has_failures()
    return (failed or 0) > 0
end

return M
