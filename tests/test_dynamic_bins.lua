if pcall(require, "lldebugger") then
  require("lldebugger").start()
end

require("modules/dynamic_bins")
-- ==========================================
-- DynamicBins test suite (print-based)
-- ==========================================

local function printf(fmt, ...)
    print(string.format(fmt, ...))
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

-- --------- Helpers for inspecting structures ---------

local function sum_items_in_bins(D)
    local s = 0
    for i = 1, #D.bins do
        s = s + #D.bins[i].items
    end
    return s
end

local function validate_invariants(D, name)
    local total_calc = sum_items_in_bins(D) + #D.backfill
    local ok_total = (total_calc == D.total)
    if not ok_total then
        printf("  invariant total mismatch: calc=%d D.total=%d", total_calc, D.total)
    end

    local ordered = true
    for i = 1, #D.bins - 1 do
        local a, b = D.bins[i], D.bins[i + 1]
        if not (a.max_ring <= b.min_ring) then
            ordered = false
            printf("  bins not ordered/disjoint at i=%d: a.max_ring=%d, b.min_ring=%d", i, a.max_ring, b.min_ring)
            break
        end
    end

    local inside = true
    for i = 1, #D.bins do
        local b = D.bins[i]
        for j = 1, #b.items do
            local it = b.items[j]
            if not (b.min_ring <= it.ring_index and it.ring_index <= b.max_ring) then
                inside = false
                printf("  item outside bin range: bin[%d] [%d..%d], item.ring_index=%d",
                    i, b.min_ring, b.max_ring, it.ring_index)
                break
            end
        end
        if not inside then break end
    end

    ok(ok_total and ordered and inside, name or "validate_invariants")
end

local function pop_one(D)
    local ids, rings, out = dynamic_bins.batch_pop(D, 1)
    if out and out >= 1 then
        return ids[1], rings[1]
    end
    return nil, nil
end

local function drain_all(D)
    local ids_all, rings_all = {}, {}
    while true do
        local ids, rings, out = dynamic_bins.batch_pop(D, 256)
        if not out or out == 0 then break end
        for i = 1, out do
            ids_all[#ids_all + 1] = ids[i]
            rings_all[#rings_all + 1] = rings[i]
        end
    end
    return ids_all, rings_all
end

local function rings_non_decreasing(rings)
    for i = 2, #rings do
        if rings[i] < rings[i - 1] then return false end
    end
    return true
end

-- --------- New instance factory ---------

local function new_dynamic(cx, cy, w, cap, stride, window)
    return dynamic_bins.new(
        cx or 0, cy or 0,
        w or 2.0,
        cap or 16, -- small cap to force splits in tests
        stride or 8,
        window or 6
    )
end

-- ==========================================
-- TESTS
-- ==========================================

local function test_new()
    local D = new_dynamic(0, 0, 2.0, 16)
    assert_eq(D.center_x, 0, "new(): center_x stored")
    assert_eq(D.center_y, 0, "new(): center_y stored")
    assert_eq(D.ring_width_tiles, 2.0, "new(): ring_width_tiles stored")
    assert_eq(D.ring_width_squared, 4.0, "new(): ring_width_squared derived")
    ok(#D.bins == 0 and D.front == nil, "new(): starts empty with front=nil")
    assert_eq(D.total, 0, "new(): total starts 0")
end

local function test_compute_ring()
    local D = new_dynamic(0, 0, 2.0)
    assert_eq(dynamic_bins.compute_ring_index(D, 0, 0), 0, "ring at center is 0")
    assert_eq(dynamic_bins.compute_ring_index(D, 1, 0), 0, "(1,0) -> ring 0")
    assert_eq(dynamic_bins.compute_ring_index(D, 2, 0), 1, "(2,0) -> ring 1")
    assert_eq(dynamic_bins.compute_ring_index(D, 3, 0), 2, "(3,0) -> ring 2")
    assert_eq(dynamic_bins.compute_ring_index(D, 2, 2), 2, "(2,2) -> ring floor(8/4)=2")
end

local function test_push_pop_simple()
    local D = new_dynamic(0, 0, 2.0, 8)
    -- push increasing distance
    for x = 0, 5 do
        dynamic_bins.push(D, "id" .. x, x, 0)
    end
    validate_invariants(D, "push_pop_simple invariants after push")

    local ids, rings = drain_all(D)
    ok(#ids == 6, "push_pop_simple drained all")
    ok(rings_non_decreasing(rings), "push_pop_simple: rings non-decreasing on pop")
    assert_eq(D.total, 0, "push_pop_simple: total returns to 0")
end

local function test_backfill_precedence()
    local D = new_dynamic(0, 0, 2.0, 8)
    -- push rings 0..3
    for x = 0, 3 do dynamic_bins.push(D, "a" .. x, x, 0) end
    -- pop one full bin (ring 0): depending on cap, this might be multiple items;
    -- ensure frontier moves beyond ring 0
    local _, r0 = pop_one(D)
    ok(r0 ~= nil, "backfill: got first pop")
    -- Now front is >= ring of next items; force it forward by draining all ring 0
    while true do
        local id, r = pop_one(D)
        if not id then break end
        if r > r0 then
            -- we popped into the next ring; push a new lagging tile behind current front's hi
            local frontLo, frontHi = dynamic_bins.front_info(D)
            ok(frontHi ~= nil, "backfill: front info present")
            -- Add "lag" tile with ring <= frontHi → goes to backfill
            dynamic_bins.push(D, "lag", 0, 0) -- ring 0
            -- Next pop MUST return "lag" first
            local id2, r2 = pop_one(D)
            ok(id2 == "lag", "backfill: lagging tile popped before frontier")
            return
        end
    end
    ok(false, "backfill: failed to advance frontier in setup")
end

local function test_split_on_cap_and_ranges()
    local D = new_dynamic(0, 0, 2.0, 4) -- tiny cap to guarantee splits
    -- push many items with near-identical ring (~2): x≈3 → ring floor(9/4)=2
    for i = 1, 25 do
        dynamic_bins.push(D, "p" .. i, 3, 0)
    end
    validate_invariants(D, "split_on_cap: invariants hold after pushes")
    ok(#D.bins >= 6, "split_on_cap: bins increased due to splits")
    local ids, rings = drain_all(D)
    ok(rings_non_decreasing(rings), "split_on_cap: rings non-decreasing on pop")
    assert_eq(D.total, 0, "split_on_cap: total returns 0 after drain")
end

local function test_batch_push_sorted_effect()
    local D = new_dynamic(0, 0, 2.0, 8)
    local items = {}
    for i = 1, 200 do
        local x = (i % 16)
        items[i] = { "b" .. i, x, 0 }
    end
    local inserted = dynamic_bins.batch_push(D, items)
    assert_eq(inserted, #items, "batch_push: inserted count matches")
    validate_invariants(D, "batch_push: invariants after batch")

    local ids, rings = drain_all(D)
    ok(#ids == #items, "batch_push: drain count matches")
    ok(rings_non_decreasing(rings), "batch_push: rings non-decreasing on pop")
    assert_eq(D.total, 0, "batch_push: total returns 0")
end

local function test_batch_pop_k_with_backfill()
    local D = new_dynamic(0, 0, 2.0, 8)
    -- prime some items (frontier around ring 1..2)
    for x = 0, 4 do dynamic_bins.push(D, "d" .. x, x, 0) end
    -- create backfill by pushing behind current head.max_ring
    -- in order to init the front - so that backfill is activated
    -- we need to pop one item
    local _, _ = pop_one(D)
    local headLo, headHi = dynamic_bins.front_info(D)
    ok(headHi ~= nil, "batch_pop_k: front present")
    dynamic_bins.push(D, "lag1", 0, 0) -- definitely backfill
    dynamic_bins.push(D, "lag2", 0, 0) -- also backfill

    local ids, rings = dynamic_bins.batch_pop(D, 3)
    ok(ids[1] == "lag2" or ids[1] == "lag1", "batch_pop_k: backfill popped first (1)")
    ok(ids[2] == "lag1" or ids[2] == "lag2", "batch_pop_k: backfill popped second (2)")
    ok(rings[3] ~= nil, "batch_pop_k: third from frontier bins")
end

local function test_set_center_no_rebucket()
    local D = new_dynamic(0, 0, 2.0, 8)
    for x = 0, 6 do dynamic_bins.push(D, "e" .. x, x, 0) end
    validate_invariants(D, "set_center: invariants before")
    dynamic_bins.set_center(D, 10, 10)
    -- Insertion after set_center should use the new center for ring calc:
    dynamic_bins.push(D, "newC", 10, 10) -- at center -> ring 0 w.r.t new center
    validate_invariants(D, "set_center: invariants after")
    -- Drain all to ensure order is monotone
    local ids, rings = drain_all(D)
    ok(rings_non_decreasing(rings), "set_center: rings non-decreasing after mixed center")
end

local function test_front_info_progress()
    local D = new_dynamic(0, 0, 2.0, 8)
    for x = 0, 8 do dynamic_bins.push(D, "f" .. x, x, 0) end
    local min_ring1, max_ring1 = dynamic_bins.front_info(D)
    ok(min_ring1 ~= nil and max_ring1 ~= nil, "front_info: initial")
    -- Pop a few and ensure front moves forward at some point
    local moved = false
    for i = 1, 20 do
        local _, _ = pop_one(D)
        local min_ring2, max_ring2 = dynamic_bins.front_info(D)
        if min_ring2 and max_ring2 and (min_ring2 > min_ring1 or max_ring2 > max_ring1) then
            moved = true
            break
        end
    end
    ok(moved, "front_info: frontier advances after pops")
end

-- A larger random smoke test
local function test_randomized_smoke()
    local D = new_dynamic(100, -50, 2.5, 32, 8, 8) -- non-integer width
    local N = 5000
    for i = 1, N do
        local x = 100 + math.random(-60, 60)
        local y = -50 + math.random(-60, 60)
        dynamic_bins.push(D, "g" .. i, x, y)
    end
    validate_invariants(D, "randomized: invariants after push")
    local ids, rings = drain_all(D)
    ok(#ids == N, "randomized: drained all items")
    ok(rings_non_decreasing(rings), "randomized: rings non-decreasing on pop")
    assert_eq(D.total, 0, "randomized: total returns 0")
end

-- ==========================================
-- MAIN
-- ==========================================
local function run_all_tests()
    printf("Running DynamicBins tests...\n")

    local tests = {
        test_new,
        test_compute_ring,
        test_push_pop_simple,
        test_backfill_precedence,
        test_split_on_cap_and_ranges,
        test_batch_push_sorted_effect,
        test_batch_pop_k_with_backfill,
        test_set_center_no_rebucket,
        test_front_info_progress,
        test_randomized_smoke,
    }

    for i, t in ipairs(tests) do
        local ok_status, err = pcall(t)
        if not ok_status then
            TESTS_FAILED = TESTS_FAILED + 1
            printf("[ERROR] test #%d failed with error:\n%s", i, tostring(err))
        end
    end

    printf("\nDynamicBins tests complete: %d passed, %d failed.", TESTS_PASSED, TESTS_FAILED)
    if TESTS_FAILED == 0 then
        print("All good ✅")
    else
        print("Some tests failed ❌")
    end
end

run_all_tests()
