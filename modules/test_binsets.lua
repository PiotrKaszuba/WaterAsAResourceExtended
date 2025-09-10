if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

require("modules/binsets")

-- =========================
-- Binsets test suite (print-based)
-- Paste this BELOW your binsets implementation.
-- =========================

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

local function shallow_copy_keys(t)
    local ks = {}
    for k, _ in pairs(t) do ks[#ks + 1] = k end
    table.sort(ks)
    return ks
end

local TESTS_PASSED, TESTS_FAILED = 0, 0
local function ok(cond, name)
    if cond then
        TESTS_PASSED = TESTS_PASSED + 1
        printf("[PASS] %s", name)
    else
        TESTS_FAILED = TESTS_FAILED + 1
        printf("[FAIL] %s", name)
    end
end

local function assert_eq(a, b, name)
    local cond = (a == b)
    if not cond then
        printf("  expected: %s", tostring(b))
        printf("  got     : %s", tostring(a))
    end
    ok(cond, name)
end

-- Iterate non-empty rings via DLL from head; returns array of ring indices in order
local function dll_to_list(binset)
    local out = {}
    local k = binset.headRingIndex
    local seen = {}
    local steps = 0
    while k ~= nil do
        if seen[k] then
            -- safety: break potential loops
            break
        end
        seen[k] = true
        out[#out + 1] = k
        k = binset.nonEmptyNext[k]
        steps = steps + 1
        if steps > 100000 then break end
    end
    return out
end

-- Helper to exhaust a binset and return popped ids and ring indices
local function drain(binset)
    local ids, rings = {}, {}
    while true do
        local id, ring = binsets.pop(binset)
        if not id then break end
        ids[#ids + 1] = id
        rings[#rings + 1] = ring
    end
    return ids, rings
end


-- =========================
-- TESTS
-- =========================

local function test_new_structure()
    local B = binsets.new(0, 0, 2.0)
    ok(B.centerX == 0 and B.centerY == 0, "new(): centroid stored")
    assert_eq(B.ringWidthTiles, 2.0, "new(): ring width stored (tiles)")
    assert_eq(B.ringWidthSquared, 4.0, "new(): ring width squared computed")
    assert_eq(B.totalCandidates, 0, "new(): totalCandidates starts at 0")
    ok(B.headRingIndex == nil, "new(): headRingIndex starts nil")
    ok(type(B.ringsByIndex) == "table", "new(): ringsByIndex is a table")
end

local function test_compute_ring_index()
    local B = binsets.new(0, 0, 2.0) -- ringWidthSquared = 4
    assert_eq(binsets.computeRingIndex(B, 0, 0), 0, "computeRingIndex: origin -> ring 0")
    assert_eq(binsets.computeRingIndex(B, 1, 0), 0, "computeRingIndex: (1,0) -> ring 0")
    assert_eq(binsets.computeRingIndex(B, 2, 0), 1, "computeRingIndex: (2,0) -> ring 1")
    assert_eq(binsets.computeRingIndex(B, 3, 0), 2, "computeRingIndex: (3,0) -> ring 2")
    assert_eq(binsets.computeRingIndex(B, 2, 2), 2, "computeRingIndex: (2,2) -> ring floor(8/4)=2")
end

local function test_push_updates_head_and_dll()
    local B = binsets.new(0, 0, 2.0)
    -- Push into ring 2 then ring 0, ensure head updates to smallest
    binsets.push(B, "A", 3, 0) -- ring 2
    ok(B.headRingIndex == 2, "push: first push sets head to that ring")
    binsets.push(B, "B", 0, 0) -- ring 0
    ok(B.headRingIndex == 0, "push: pushing smaller ring updates head to 0")

    local order = dll_to_list(B)
    local cond = (#order >= 2) and order[1] == 0 and order[2] == 2
    ok(cond, "DLL order: nonempty keys are sorted ascending")
end

local function test_pop_lifo_within_ring()
    local B = binsets.new(0, 0, 2.0)
    -- All in ring 0 (LIFO expected)
    binsets.push(B, "t1", 0, 0)
    binsets.push(B, "t2", 1, 0)
    binsets.push(B, "t3", 1, 1)
    local id, ring = binsets.pop(B); assert_eq(ring, 0, "pop: ring index for LIFO #1")
    ok(id == "t3", "pop: LIFO within same ring -> t3")
    id, ring = binsets.pop(B); ok(id == "t2", "pop: LIFO within same ring -> t2")
    id, ring = binsets.pop(B); ok(id == "t1", "pop: LIFO within same ring -> t1")
    id, ring = binsets.pop(B); ok(id == nil and ring == nil, "pop: returns nil,nil when empty")
end

local function test_pop_advances_frontier()
    local B = binsets.new(0, 0, 2.0)
    -- ring 0 and ring 1
    binsets.push(B, "r0_a", 0, 0)
    binsets.push(B, "r0_b", 1, 0)
    binsets.push(B, "r1_a", 2, 0)
    ok(B.headRingIndex == 0, "frontier starts at smallest ring")
    local _, r = binsets.pop(B); assert_eq(r, 0, "pop -> ring 0")
    local _, r2 = binsets.pop(B); assert_eq(r2, 0, "pop -> ring 0 (second)")
    -- next pop should be ring 1 (frontier advanced)
    local _, r3 = binsets.pop(B); assert_eq(r3, 1, "frontier advances to next nonempty ring")
    local id, r4 = binsets.pop(B); ok(id == nil and r4 == nil, "empty after all pops")
end

local function test_defensive_cleanup_of_empty_buckets()
    local B = binsets.new(0, 0, 2.0)
    binsets.push(B, "x", 0, 0)           -- ring 0
    binsets.push(B, "y", 2, 0)           -- ring 1
    -- Manually break ring 0 bucket:
    B.ringsByIndex[B.headRingIndex] = {} -- simulate corrupted/emptied bucket
    local id, ring = binsets.pop(B)
    ok(id == "y" and ring == 1, "defensive cleanup: skipped empty bucket, popped from next ring")
end

local function test_monotonic_rings_on_drain()
    local B = binsets.new(0, 0, 2.0)
    -- Push a bunch of points in rings 0..5
    for i = 1, 2000 do
        local r = math.random(0, 5)
        -- pick an x with squared distance ~ r*4 (1D simplification)
        local x = math.floor(math.sqrt(r * B.ringWidthSquared) + 0.1)
        binsets.push(B, "id" .. i, x, 0)
    end
    local _, rings = drain(B)
    local mono = true
    for i = 2, #rings do
        if rings[i] < rings[i - 1] then
            mono = false; break
        end
    end
    ok(mono, "drain: ring indices are non-decreasing")
    assert_eq(#rings, 2000, "drain: popped exactly all candidates")
    assert_eq(B.totalCandidates, 0, "drain: totalCandidates returns to 0")
    ok(B.headRingIndex == nil, "drain: headRingIndex returns to nil (empty)")
end

local function test_set_center_no_rebucket()
    local B = binsets.new(0, 0, 2.0)
    binsets.push(B, "p", 3, 0)    -- ring 2
    local before = dll_to_list(B)
    binsets.set_center(B, 10, 10) -- DOES NOT re-bucket
    local after = dll_to_list(B)
    -- The internal ring arrangement should not change just by changing center
    local same = (#before == #after)
    for i = 1, #before do if before[i] ~= after[i] then
            same = false; break
        end end
    ok(same, "set_center(): does not mutate ring structure")
    -- However, computing a new ring index for a new push should reflect new center:
    local newIdx = binsets.computeRingIndex(B, 10, 10) -- at center -> 0
    assert_eq(newIdx, 0, "set_center(): new computations use new center")
end

local function test_maybeSplitBucket_placeholder()
    local B = binsets.new(0, 0, 2.0)
    for i = 1, 50 do binsets.push(B, "x" .. i, 0, 0) end
    local ring0 = binsets.computeRingIndex(B, 0, 0)
    local res = binsets.maybeSplitBucket(B, ring0, 10)
    ok(res == false, "maybeSplitBucket(): placeholder returns false")
end

local function test_dll_sorted_property_basic()
    local B = binsets.new(0, 0, 2.0)
    -- Push rings: 3,1,4,2 -> should sort as 1,2,3,4
    binsets.push(B, "r3", 3, 0) -- 2.0^2=4->3^2/4=2 -> actually ring 2; ensure wider spread:
    binsets.push(B, "r1", 2, 0) -- ring 1
    binsets.push(B, "r4", 5, 0) -- ring floor(25/4)=6
    binsets.push(B, "r2", 3, 0) -- ring 2
    local list = dll_to_list(B)
    local sorted = true
    for i = 2, #list do if list[i] < list[i - 1] then
            sorted = false; break
        end end
    ok(sorted, "DLL maintains ascending ring indices")
end

-- Biggish randomized smoke test
local function test_randomized_smoke()
    local B = binsets.new(100, -50, 2.5) -- ringWidthSquared 6.25
    local N = 200
    local idx = nil
    local max_numel = 0
    local max_numel_idx = nil
    local max_numel_id = nil
    for i = 1, N do
        for j = 1, N do
            local x = 100 + i - N / 2
            local y = -50 + j - N / 2
            local idd = "id" .. i .. "-" .. j
            idx = binsets.push(B, idd, x, y)
            local num_el = #B.ringsByIndex[idx]
            if num_el > max_numel then
                max_numel = num_el
                max_numel_idx = idx
                max_numel_id = idd
            end
            --print(i, j, idx, " - ", num_el)
        end
    end
    print(max_numel, max_numel_idx, max_numel_id)
    local ids, rings = drain(B)
    ok(#ids == N*N, "randomized: popped all elements")
    local mono = true
    for i = 2, #rings do if rings[i] < rings[i - 1] then
            mono = false; break
        end end
    ok(mono, "randomized: rings non-decreasing on pop")
    ok(B.headRingIndex == nil and B.totalCandidates == 0, "randomized: binset emptied cleanly")
end

-- =========================
-- MAIN
-- =========================
local function run_all_tests()
    printf("Running Binsets tests...\n")

    local tests = {
        test_new_structure,
        test_compute_ring_index,
        test_push_updates_head_and_dll,
        test_pop_lifo_within_ring,
        test_pop_advances_frontier,
        test_defensive_cleanup_of_empty_buckets,
        test_monotonic_rings_on_drain,
        test_set_center_no_rebucket,
        test_maybeSplitBucket_placeholder,
        test_dll_sorted_property_basic,
        test_randomized_smoke,
    }

    for i, t in ipairs(tests) do
        local ok_status, err = pcall(t)
        if not ok_status then
            TESTS_FAILED = TESTS_FAILED + 1
            printf("[ERROR] test #%d failed with error:\n%s", i, tostring(err))
        end
    end

    printf("\nBinsets tests complete: %d passed, %d failed.", TESTS_PASSED, TESTS_FAILED)
    if TESTS_FAILED == 0 then
        print("All good ✅")
    else
        print("Some tests failed ❌")
    end
end

run_all_tests()