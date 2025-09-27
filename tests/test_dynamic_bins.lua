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

local ORIENTATIONS = { false, true }
local function orientation_label(pop_desc)
	return pop_desc and "perimeter-in" or "centroid-out"
end

-- --------- Helpers for inspecting structures ---------

-- Bins keep already-popped slots until the front advances; subtract them when counting.
local function sum_items_in_bins(D)
	local num_backfill = #D.backfill
	local total = D.total + num_backfill
	local total_counting = num_backfill
	local pop_desc = D.pop_descending
	for i = 1, #D.bins do
		local b = D.bins[i]
		local num_items = #b.items
		if pop_desc then
			if b.pop_idx and b.pop_idx > 1 then
				num_items = num_items - (b.pop_idx - 1)
			end
		else
			if b.pop_idx and b.pop_idx < num_items then
				num_items = b.pop_idx
			end
		end
		total_counting = total_counting + num_items
	end
	if total < 0 then total = 0 end
	assert_eq(total, total_counting, "sum_items_in_bins: total mismatch")
	return total
end

-- validates bin structure - does not care about popping order (so always sorted ascending)
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

local function rings_monotone(rings, pop_desc)
	for i = 2, #rings do
		if pop_desc then
			if rings[i] > rings[i - 1] then return false end
		else
			if rings[i] < rings[i - 1] then return false end
		end
	end
	return true
end

-- --------- New instance factory ---------

local function new_dynamic(cx, cy, w, cap, stride, window, deduplicate, pop_desc)
	return dynamic_bins.new(
		cx or 0, cy or 0,
		w or 2.0,
		cap or 16, -- small cap to force splits in tests
		stride or 8,
		window or 6,
		nil, nil, nil, nil,
		deduplicate,
		pop_desc
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
	ok(not D.pop_descending, "new(): default orientation is centroid-out")

	local D_desc = new_dynamic(0, 0, 2.0, 16, nil, nil, nil, true)
	ok(D_desc.pop_descending, "new(): perimeter-in flag stored")
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
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 5 do
			dynamic_bins.push(D, label .. "-id" .. x, x, 0)
		end
		validate_invariants(D, string.format("push_pop_simple %s: invariants after push", label))

		local ids, rings = drain_all(D)
		ok(#ids == 6, string.format("push_pop_simple %s drained all", label))
		ok(rings_monotone(rings, pop_desc), string.format("push_pop_simple %s: rings monotone on pop", label))
		assert_eq(D.total, 0, string.format("push_pop_simple %s: total returns to 0", label))
	end
end

local function test_backfill_precedence()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 3 do dynamic_bins.push(D, label .. "-a" .. x, x, 0) end
		local _, r0 = pop_one(D)
		ok(r0 ~= nil, string.format("backfill %s: got first pop", label))

		local advanced = false
		while true do
			local id, r = pop_one(D)
			if not id then break end
			local moved_forward = (not pop_desc and r > r0) or (pop_desc and r < r0)
			if moved_forward then
				advanced = true
				local _, frontHi = dynamic_bins.front_info(D)
				ok(frontHi ~= nil, string.format("backfill %s: front info present", label))
				local lag_name = label .. "-lag"
				dynamic_bins.push(D, lag_name, nil, nil, frontHi)
				local id2 = pop_one(D)
				ok(id2 == lag_name, string.format("backfill %s: lagging tile popped before frontier", label))
				break
			end
		end
		ok(advanced, string.format("backfill %s: advanced beyond first ring", label))
	end
end

local function test_split_on_cap_and_ranges()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 4, nil, nil, nil, pop_desc)
		for i = 1, 25 do
			dynamic_bins.push(D, label .. "-p" .. i, 3, 0)
		end
		validate_invariants(D, string.format("split_on_cap %s: invariants hold after pushes", label))
		ok(#D.bins >= 6, string.format("split_on_cap %s: bins increased due to splits", label))
		local ids, rings = drain_all(D)
		ok(rings_monotone(rings, pop_desc), string.format("split_on_cap %s: rings monotone on pop", label))
		assert_eq(D.total, 0, string.format("split_on_cap %s: total returns 0 after drain", label))
	end
end

local function test_batch_push_sorted_effect()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		local items = {}
		for i = 1, 200 do
			local x = (i % 16)
			items[i] = { label .. "-b" .. i, x, 0 }
		end
		local inserted = dynamic_bins.batch_push(D, items)
		assert_eq(inserted, #items, string.format("batch_push %s: inserted count matches", label))
		validate_invariants(D, string.format("batch_push %s: invariants after batch", label))

		local ids, rings = drain_all(D)
		ok(#ids == #items, string.format("batch_push %s: drain count matches", label))
		ok(rings_monotone(rings, pop_desc), string.format("batch_push %s: rings monotone on pop", label))
		assert_eq(D.total, 0, string.format("batch_push %s: total returns 0", label))
	end
end

local function test_batch_pop_k_with_backfill()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 4 do dynamic_bins.push(D, label .. "-d" .. x, x, 0) end
		pop_one(D)
		local _, headHi = dynamic_bins.front_info(D)
		ok(headHi ~= nil, string.format("batch_pop_k %s: front present", label))
		local lag1 = label .. "-lag1"
		local lag2 = label .. "-lag2"
		dynamic_bins.push(D, lag1, nil, nil, headHi)
		dynamic_bins.push(D, lag2, nil, nil, headHi)

		local ids, rings = dynamic_bins.batch_pop(D, 3)
		local seen = { [lag1] = false, [lag2] = false }
		for i = 1, 2 do
			local id = ids[i]
			if seen[id] ~= nil then seen[id] = true end
		end
		ok(seen[lag1] and seen[lag2], string.format("batch_pop_k %s: backfill drained first", label))
		ok(rings[3] ~= nil, string.format("batch_pop_k %s: third from frontier bins", label))
	end
end

local function test_backfill_consume()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 2 do dynamic_bins.push(D, label .. "-p" .. x, x, 0) end
		pop_one(D)
		local _, headHi = dynamic_bins.front_info(D)
		local lag1 = label .. "-lag1"
		local lag2 = label .. "-lag2"
		dynamic_bins.push(D, lag1, nil, nil, headHi)
		dynamic_bins.push(D, lag2, nil, nil, headHi)
		assert_eq(#D.backfill, 2, string.format("backfill_consume %s: created backfill", label))

		local consumed = dynamic_bins.backfill_consume(D, 10)
		assert_eq(consumed, 0, string.format("backfill_consume %s: no consume with active front", label))
		assert_eq(#D.backfill, 2, string.format("backfill_consume %s: unchanged backfill when front active", label))

		local before = sum_items_in_bins(D)
		consumed = dynamic_bins.backfill_consume(D, 10, true)
		assert_eq(consumed, 2, string.format("backfill_consume %s: consumed with ignore_front", label))
		assert_eq(#D.backfill, 0, string.format("backfill_consume %s: backfill cleared", label))
		assert_eq(sum_items_in_bins(D), before + 2, string.format("backfill_consume %s: items moved to bins", label))
		validate_invariants(D, string.format("backfill_consume %s: invariants after consume", label))
	end
end

local function test_ring_index_push_api()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		assert_eq(dynamic_bins.push(D, label .. "-a", nil, nil, 3), 3,
			string.format("ring_index push %s: push returns ring", label))
		dynamic_bins.push(D, label .. "-b", nil, nil, 1)

		local items = {
			{ label .. "-c", 2 },
			{ label .. "-d", 4 },
			{ label .. "-e", 0 },
		}
		local inserted = dynamic_bins.batch_push(D, items)
		assert_eq(inserted, #items, string.format("ring_index push %s: inserted count", label))
		validate_invariants(D, string.format("ring_index push %s: invariants", label))

		local ids, rings = drain_all(D)
		ok(#ids == #items + 2, string.format("ring_index push %s: drained all", label))
		ok(rings_monotone(rings, pop_desc), string.format("ring_index push %s: rings monotone", label))
		local expected_first = pop_desc and 4 or 0
		local expected_last = pop_desc and 0 or 4
		assert_eq(rings[1], expected_first, string.format("ring_index push %s: first ring", label))
		assert_eq(rings[#rings], expected_last, string.format("ring_index push %s: last ring", label))
	end
end

local function test_deduplication()
	local D = new_dynamic(0, 0, 2.0, 8, nil, nil, true)
	local function hash(v) return v end

	dynamic_bins.push(D, "a", 0, 0, nil, hash)
	dynamic_bins.push(D, "a", 0, 0, nil, hash)
	assert_eq(dynamic_bins.size(D), 1, "dedup: push skips duplicates")

	local items = {
		{ "a", 0, 0 },
		{ "b", 1, 0 },
		{ "b", 1, 0 },
	}
	local inserted = dynamic_bins.batch_push(D, items, hash)
	assert_eq(inserted, 1, "dedup: batch_push inserts uniques")
	assert_eq(dynamic_bins.size(D), 2, "dedup: size after batch_push")

	local _, _, out = dynamic_bins.batch_pop(D, 2, false, hash)
	assert_eq(out, 2, "dedup: batch_pop returns items")
	assert_eq(dynamic_bins.size(D), 0, "dedup: size after pops")

	dynamic_bins.push(D, "a", 0, 0, nil, hash)
	assert_eq(dynamic_bins.size(D), 1, "dedup: reinsert after pop")
end

local function test_set_center_no_rebucket()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 6 do dynamic_bins.push(D, label .. "-e" .. x, x, 0) end
		validate_invariants(D, string.format("set_center %s: invariants before", label))
		dynamic_bins.set_center(D, 10, 10)
		dynamic_bins.push(D, label .. "-newC", 10, 10)
		validate_invariants(D, string.format("set_center %s: invariants after", label))
		local ids, rings = drain_all(D)
		ok(rings_monotone(rings, pop_desc), string.format("set_center %s: rings monotone after mixed center", label))
	end
end

local function test_front_info_progress()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(0, 0, 2.0, 8, nil, nil, nil, pop_desc)
		for x = 0, 8 do dynamic_bins.push(D, label .. "-f" .. x, x, 0) end
		local min_ring1, max_ring1 = dynamic_bins.front_info(D)
		ok(min_ring1 ~= nil and max_ring1 ~= nil, string.format("front_info %s: initial", label))
		local moved = false
		for i = 1, 20 do
			pop_one(D)
			local min_ring2, max_ring2 = dynamic_bins.front_info(D)
			if min_ring2 and max_ring2 then
				local progressed = (not pop_desc and (min_ring2 > min_ring1 or max_ring2 > max_ring1))
					or (pop_desc and (min_ring2 < min_ring1 or max_ring2 < max_ring1))
				if progressed then
					moved = true
					break
				end
			end
		end
		ok(moved, string.format("front_info %s: frontier advances after pops", label))
	end
end

-- A larger random smoke test
local function test_randomized_smoke()
	for _, pop_desc in ipairs(ORIENTATIONS) do
		local label = orientation_label(pop_desc)
		local D = new_dynamic(100, -50, 2.5, 32, 8, 8, nil, pop_desc)
		local N = 5000
		for i = 1, N do
			local x = 100 + math.random(-60, 60)
			local y = -50 + math.random(-60, 60)
			dynamic_bins.push(D, label .. "-g" .. i, x, y)
		end
		validate_invariants(D, string.format("randomized %s: invariants after push", label))
		local ids, rings = drain_all(D)
		ok(#ids == N, string.format("randomized %s: drained all items", label))
		ok(rings_monotone(rings, pop_desc), string.format("randomized %s: rings monotone on pop", label))
		assert_eq(D.total, 0, string.format("randomized %s: total returns 0", label))
	end
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
		test_backfill_consume,
		test_ring_index_push_api,
		test_deduplication,
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
