-- ==========================================
-- dynamic_bins
-- Adaptive capacity-constrained distance bins
-- ==========================================
-- Key ideas:
--  • N is a number of items in the dataset.
--  • B is a number of bins which grows as: B = N/cap
--  • Bins are ordered by distance range [min_ring..max_ring] (ring indices).
--  • Each bin has a fixed capacity (cap). On overflow, we split the bin.
--  • Approximate key → bin index is a "hint" table that warms up automatically so
--    inserts are ~O(1) in dense regions; fallback is binary search O(log B).
--  • A pre‑front "backfill" stack caches tiles that arrive with ring <= current frontier.max_ring so they are popped first.
--    current frontier.max_ring so they are popped first.
--
-- API:
--   local dynamicBins = dynamic_bins.new(center_x, center_y, ring_width_tiles?, cap?, approx_stride?, local_probe_window?)
--   dynamic_bins.compute_ring_index(dynamicBins, x, y) -> integer ring_index
--   dynamic_bins.push(dynamicBins, item_data, x?, y?, ring_index?) -> ring_index; either both x and y or ring_index must be provided
--   dynamic_bins.batch_push(dynamicBins, items)           -- items array of: {{item_data, x, y}, ... } or {{item_data, ring_index}, ... }
--   dynamic_bins.batch_pop(dynamicBins, k, only_backfill?) -> item_datas{}, ring_indices{}, num_popped
--   dynamic_bins.size(dynamicBins) -> total items across bins + backfill
--   dynamic_bins.front_info(dynamicBins) -> front_min_ring, front_max_ring | nil, nil
--   dynamic_bins.set_center(dynamicBins, center_x, center_y)          -- does not re-bucket existing items
--   dynamic_bins.backfill_consume(dynamicBins, max_items, ignore_front?) -> num_consumed
--	 TODO: add deduplication option such as in utils.Queue

-- ==========================================

dynamic_bins = {}
-- ==========================================
-- Item structure
function dynamic_bins.init_item(
	item_data,
	ring_index
)
	return {
		item_data = item_data or nil,      -- data of the item
		ring_index = ring_index or nil, -- ring index of the item
	}
end

-- Bin structure
function dynamic_bins.init_bin(
	min_ring,
	max_ring,
	items,
	sorted,
	pop_idx,
	apply_bin_range_extension,
	bin_range_extension_flat,
	bin_range_extension_ratio,
	ring_width_tiles,
	prev_bin_max_ring,
	next_bin_min_ring
)
	if apply_bin_range_extension then
		local ring_width_ratio = (ring_width_tiles or 2.0) / 2.0
		local adjusted_bin_range_extension_ratio = (bin_range_extension_ratio or 0.0) * ring_width_ratio
		local adjusted_bin_range_extension_flat = (bin_range_extension_flat or 0.0) * ring_width_ratio
		local adjusted_min_ring = math.ceil(min_ring * (1 - adjusted_bin_range_extension_ratio) - adjusted_bin_range_extension_flat)
		local adjusted_max_ring = math.floor(max_ring * (1 + adjusted_bin_range_extension_ratio) + adjusted_bin_range_extension_flat)
		
		prev_bin_max_ring = prev_bin_max_ring or 0
		next_bin_min_ring = next_bin_min_ring or math.huge
		min_ring = math.max(prev_bin_max_ring, adjusted_min_ring)
		max_ring = math.min(next_bin_min_ring, adjusted_max_ring)
	end
	return {
		-- ranges of bins should be disjoint and ordered
		min_ring = min_ring or nil,  -- minimum ring index contained in the bin
		max_ring = max_ring or nil,  -- maximum ring index contained in the bin
		items = items or {},      -- items contained in the bin
		sorted = sorted or false,  -- whether the items are sorted by ring index
		pop_idx = pop_idx or 1,    -- index of the next item to pop
	}
end

function dynamic_bins.new(
	center_x,
	center_y,
	ring_width_tiles,
	cap,
	approx_stride,
	local_probe_window,
	batch_sort_threshold,
	coalesce_ring_ratio,
	bin_range_extension_ratio,
	bin_range_extension_flat
	)
	local w = ring_width_tiles or dynamic_bins.get_default_ring_width_tiles()
	return {
		-- geometry
		center_x = center_x,
		center_y = center_y,
		initial_center_x = center_x,
		initial_center_y = center_y,
		ring_width_tiles = w,
		ring_width_squared = w * w,

		-- bins
		bins = {}, -- ordered by .max_ring, disjoint ranges [min_ring..max_ring] (allow touching boundaries)
		num_bins = 0, -- number of bins (to avoid calling #bins)
		front = nil, -- frontier is undefined until we actually pop from bins, it alternates between nil and fixed '1' because bins are removed when emptied (no need to be higher than 1)
		total = 0, -- total items across bins + backfill

		-- capacity & search
		cap = cap or dynamic_bins.get_default_bin_cap(),  -- max items per bin before split
		approx_stride = approx_stride or dynamic_bins.get_default_approx_stride(),  -- approx key stride: ring_index // stride → hint index
		local_probe_window = local_probe_window or dynamic_bins.get_default_local_probe_window(),  -- max steps to walk around hinted index before bsearch
		batch_sort_threshold = batch_sort_threshold or dynamic_bins.get_default_batch_sort_threshold(),  -- batch_push: sort if >= threshold
		coalesce_ring_ratio = coalesce_ring_ratio or dynamic_bins.get_default_coalesce_ring_ratio(),  -- coalesce adjacent bins if left.max_ring * (1 + coalesce_ring_ratio) >= right.min_ring
		bin_range_extension_ratio = bin_range_extension_ratio or dynamic_bins.get_default_bin_range_extension_ratio(),  -- extend initial bin range by this ratio up to neighboring bins
		bin_range_extension_flat = bin_range_extension_flat or dynamic_bins.get_default_bin_range_extension_flat(),  -- extend initial bin range by this flat amount up to neighboring bins
		
		-- hints
		hint = {}, -- approx_key -> bin index
		last_hint_idx = nil, -- last hinted bin index

		-- backfill
		backfill = {}, -- array of {item_data, ring_index}; popped before frontier
	}
end

-- ==========================================

-- ---------- Tunables / defaults ----------
function dynamic_bins.get_default_ring_width_tiles() return 2.0 end    -- base width for ring_index (squared distance / w^2)

function dynamic_bins.get_default_bin_cap() return 256 end            -- max items per bin before split

function dynamic_bins.get_default_approx_stride() return 8 end        -- approx key stride: ring // stride → hint index

function dynamic_bins.get_default_local_probe_window() return 8 end    -- max steps to walk around hinted index before bsearch

function dynamic_bins.get_default_batch_sort_threshold() return 64 end -- batch_push: sort if >= threshold

function dynamic_bins.get_default_coalesce_ring_ratio() return 0.5 end -- coalesce adjacent bins if left.max_ring * (1 + coalesce_ring_ratio) >= right.min_ring

function dynamic_bins.get_default_bin_range_extension_ratio() return 0.03 end -- extend initial bin range by this ratio up to neighboring bins

function dynamic_bins.get_default_bin_range_extension_flat() return 2.0 end -- extend initial bin range by this flat amount up to neighboring bins

-- ---------- Helpers ----------
local function ring_index_from_xy(center_x, center_y, w2, x, y)
	local dx, dy = x - center_x, y - center_y
	return math.floor((dx * dx + dy * dy) / w2)
end

local function approx_key(stride, ring_index) -- non-negative integers only (if ring_id is negative, return 0)
	if ring_index < 0 then return 0 end
	return math.floor(ring_index / stride)
end

-- Binary search: first index i with bins[i].max_ring >= ring; returns num_bins+1 if none
local function binary_search(bins, num_bins, ring_index, start_left_index, start_right_index)
	local min_ring, max_ring = start_left_index or 1, start_right_index or num_bins
	local ans = max_ring + 1
	while min_ring <= max_ring do
		local mid = math.floor((min_ring + max_ring) / 2)
		if bins[mid].max_ring >= ring_index then
			ans = mid
			max_ring = mid - 1
		else
			min_ring = mid + 1
		end
	end
	return ans
end

-- Insert bin object at index (1..num_bins+1)
-- Returns the new number of bins
local function insert_bin(dynamicBins, bins, num_bins, idx, bin)
	if idx > num_bins + 1 then idx = num_bins + 1 end
	table.insert(bins, idx, bin)
	local num_bins = dynamicBins.num_bins + 1
	dynamicBins.num_bins = num_bins
	return num_bins
end

-- Remove bin at exact index (no search)
-- Returns the remaining number of bins
local function remove_bin_at(dynamicBins, bins, idx)
	table.remove(bins, idx)
	local num_bins = dynamicBins.num_bins - 1
	dynamicBins.num_bins = num_bins
	return num_bins
end
-- Update (or set) hint mapping for an approx key
local function hint_set(dynamicBins, approx_key, bin_index)
	dynamicBins.hint[approx_key] = bin_index
	dynamicBins.last_hint_idx = bin_index
end

-- Probe near a hinted index; walk left/right up to window steps.
-- Return bin_index if ring_index is inside bins[bin_index]; else nil if not found.
local function local_probe(dynamicBins, ring_index, start_bin_index)
	local bins = dynamicBins.bins
	local num_bins = dynamicBins.num_bins
	if start_bin_index == nil or start_bin_index < 1 or start_bin_index > num_bins or num_bins == 0 then return nil end
	local window_size = dynamicBins.local_probe_window
	local bin_index = start_bin_index
	-- Check start
	local bin = bins[bin_index]
	if bin.min_ring <= ring_index and ring_index <= bin.max_ring then return bin_index end
	-- If ring is left of i, walk left
	if ring_index < bin.min_ring then
		local steps = 0
		while bin_index > 1 and steps < window_size do
			bin_index = bin_index - 1; steps = steps + 1
			bin = bins[bin_index]
			if bin.min_ring <= ring_index and ring_index <= bin.max_ring then return bin_index end
			if ring_index > bin.max_ring then break end -- overshot
		end
		return nil
	end
	-- Else ring is right of i, walk right
	local steps = 0
	while bin_index < num_bins and steps < window_size do
		bin_index = bin_index + 1; steps = steps + 1
		bin = bins[bin_index]
		if bin.min_ring <= ring_index and ring_index <= bin.max_ring then return bin_index end
		if ring_index < bin.min_ring then break end -- overshot
	end
	return nil
end

-- Locate index for ring; returns (idx, inRange)
--  • If inRange=true, bins[idx] already covers ring_index
--  • Else bin_index is where a new [ring_index..ring_index] bin should be inserted
local function locate_idx(dynamicBins, ring_index)
	local bins = dynamicBins.bins
	local num_bins = dynamicBins.num_bins
	if num_bins == 0 then return 1, false end
	local approximate_key = approx_key(dynamicBins.approx_stride, ring_index)
	local hinted = dynamicBins.hint[approximate_key] or dynamicBins.last_hint_idx
	if hinted then
		local bin_index = local_probe(dynamicBins, ring_index, hinted)
		if bin_index then return bin_index, true end
	end
	local bin_index = binary_search(bins, num_bins, ring_index)
	if bin_index <= num_bins then
		local bin = bins[bin_index]
		if bin.min_ring <= ring_index and ring_index <= bin.max_ring then
			return bin_index, true
		end
		-- not covered → insertion point is idx
		return bin_index, false
	else
		-- insert at end
		return num_bins + 1, false
	end
end

-- Recursively split bin at idx until all halves fit under cap.
local function split_bin(dynamicBins, bins, num_bins, start_bin_index)
	local stack = { start_bin_index }
	local cap = dynamicBins.cap
	local approx_stride = dynamicBins.approx_stride
	while #stack > 0 do
		local bin_index = stack[#stack]
		stack[#stack] = nil
		local bin = bins[bin_index]
		if not bin then goto continue end
		local items = bin.items
		local n = #items
		if n <= cap then goto continue end

		-- Sort once; halves inherit sortedness & popIdx semantics
		local keys, idxs = {}, {}
		for i = 1, n do
			keys[i] = items[i].ring_index
			idxs[i] = i
		end
		local function cmp(i, j) return keys[i] < keys[j] end
		table.sort(idxs, cmp)
		local out = {}
		for i = 1, n do
			out[i] = items[idxs[i]]
		end
		for i = 1, n do
			items[i] = out[i]
		end
		bin.sorted = true
		bin.pop_idx = bin.pop_idx or 1

		local mid = math.floor(n / 2)
		local leftItems = items
		local rightItems = {}
		-- move tail to right
		local j = 1
		for k = mid + 1, n do
			rightItems[j] = leftItems[k]
			leftItems[k] = nil
			j = j + 1
		end

		local leftHi   = leftItems[mid].ring_index
		local rightLo  = rightItems[1].ring_index

		local rightBin = dynamic_bins.init_bin(
			rightLo,
			bin.max_ring,
			rightItems,
			true,
			1
		)

		-- mutate left bin
		bin.max_ring = leftHi

		-- insert right neighbor
		num_bins = insert_bin(dynamicBins, bins, num_bins, bin_index + 1, rightBin)

		-- Warm hints for both halves
		hint_set(dynamicBins, approx_key(approx_stride, leftHi), bin_index)
		hint_set(dynamicBins, approx_key(approx_stride, rightLo), bin_index + 1)

		-- If any half still exceeds cap, split again
		if #rightItems > cap then table.insert(stack, bin_index + 1) end
		if #items > cap then table.insert(stack, bin_index) end
		::continue::
	end
	return num_bins
end

-- Optional: coalesce adjacent small bins
local function maybe_coalesce_adjacent(dynamicBins, bins, num_bins, bin_index, cap, approx_stride)
	local left = bins[bin_index]
	local right = bins[bin_index + 1]
	if not left or not right then return false end
	local left_items = left.items
	local right_items = right.items
	local num_left_items = #left_items
	local num_right_items = #right_items
	local total = num_left_items + num_right_items
	local coalesce_ring_ratio = dynamicBins.coalesce_ring_ratio

	if total <= math.floor(cap / 2) and left.max_ring * (1 + coalesce_ring_ratio) >= right.min_ring then
		for i = 1, num_right_items do
			 left_items[num_left_items + i] = right_items[i]
		end
		left.max_ring = right.max_ring
		-- result is sorted only if both bins were sorted
		left.sorted = left.sorted and right.sorted
		num_bins = remove_bin_at(dynamicBins, bins, bin_index + 1)
		hint_set(dynamicBins, approx_key(approx_stride, left.max_ring), bin_index)
		return true, num_bins
	end
	return false, num_bins
end

-- ---------- Public API ----------



function dynamic_bins.set_center(dynamicBins, center_x, center_y)
	dynamicBins.center_x, dynamicBins.center_y = center_x, center_y
	-- does NOT re-bucket existing items
end

function dynamic_bins.compute_ring_index(dynamicBins, x, y)
	return ring_index_from_xy(dynamicBins.center_x, dynamicBins.center_y, dynamicBins.ring_width_squared, x, y)
end

function dynamic_bins._push_item(
	dynamicBins,
	bins,
	num_bins,
	head_bin,
	head_bin_max_ring,
	item_data,
	ring_index,
	cap,
	approx_stride,
	bin_range_extension_flat,
	bin_range_extension_ratio,
	ring_width_tiles
)
	local item = dynamic_bins.init_item(item_data, ring_index)
	
	-- Backfill only after the head bin has been sorted (i.e., once popping started).
	-- Before that, allow normal insert so the head bin can absorb nearby items.
	if head_bin and ring_index <= head_bin_max_ring and head_bin.sorted then
		local backfill = dynamicBins.backfill
		backfill[#backfill + 1] = item
	else
		local bin_index, inRange = locate_idx(dynamicBins, ring_index)
		local bin = nil
		if inRange then
			bin = bins[bin_index]
		else
			local prev_bin = bin_index > 1 and bins[bin_index - 1] or nil
			local next_bin = bin_index <= num_bins and bins[bin_index] or nil
			local prev_bin_max_ring = prev_bin and prev_bin.max_ring or nil
			local next_bin_min_ring = next_bin and next_bin.min_ring or nil
			bin = dynamic_bins.init_bin(
				ring_index,
				ring_index,
				{},
				false,
				1,

			 	true,
				bin_range_extension_flat,
				bin_range_extension_ratio,
				ring_width_tiles,
				prev_bin_max_ring,
				next_bin_min_ring
			 )
			num_bins = insert_bin(dynamicBins, bins, num_bins, bin_index, bin)

		end
		local items = bin.items
		local num_items = #items + 1
		items[num_items] = item
		-- appending into an existing bin invalidates sorted order
		bin.sorted = false
		hint_set(dynamicBins, approx_key(approx_stride, ring_index), bin_index)
		if num_items > cap then num_bins = split_bin(dynamicBins, bins, num_bins, bin_index) end
		if bin_index < num_bins then
			_, num_bins = maybe_coalesce_adjacent(dynamicBins, bins, num_bins, bin_index, cap, approx_stride)
			
		end
		if bin_index > 1 then
			 _, num_bins = maybe_coalesce_adjacent(dynamicBins, bins, num_bins, bin_index - 1, cap, approx_stride)
		end

	end
	dynamicBins.total = dynamicBins.total + 1
	return num_bins
end

-- Push single item_data
-- either both x and y or ring_index must be provided
function dynamic_bins.push(dynamicBins, item_data, x, y, ring_index)
	if x and y then
		ring_index = dynamic_bins.compute_ring_index(dynamicBins, x, y)
	end
	-- Backfill if behind/at frontier
	local bins = dynamicBins.bins
	local num_bins = dynamicBins.num_bins
	local front = dynamicBins.front
	local head_bin = front and bins[front] or nil
	local head_bin_max_ring = head_bin and head_bin.max_ring or nil
	local cap = dynamicBins.cap
	local approx_stride = dynamicBins.approx_stride
	local bin_range_extension_flat = dynamicBins.bin_range_extension_flat
	local bin_range_extension_ratio = dynamicBins.bin_range_extension_ratio
	local ring_width_tiles = dynamicBins.ring_width_tiles
	
	num_bins = dynamic_bins._push_item(dynamicBins, bins, num_bins, head_bin, head_bin_max_ring, item_data, ring_index, cap, approx_stride, bin_range_extension_flat, bin_range_extension_ratio, ring_width_tiles)
	return ring_index
end

-- Batch push: arbitrary K tiles. Pre-sorts by ring for large batches.
-- items array of: {{item_data, x, y}, ... }
-- or {{item_data, ring_index}, ... }
function dynamic_bins.batch_push(dynamicBins, items)
	local num_items = #items
	if num_items == 0 then return 0 end

	local tmp = {}
	local keys, idxs = {}, {}
	for i = 1, num_items do
		local item = items[i]
		local item_data, ring_index = item[1], item[2]
		if #item == 3 then  -- x and y provided instead of ring_index
			local x, y = ring_index, item[3]  -- x is under ring_index variable
			ring_index = dynamic_bins.compute_ring_index(dynamicBins, x, y)
		end
		tmp[i] = dynamic_bins.init_item(item_data, ring_index)
		keys[i] = ring_index
		idxs[i] = i
	end
	local batch_sort_threshold = dynamicBins.batch_sort_threshold
	if num_items >= batch_sort_threshold then
		local function cmp(i, j) return keys[i] < keys[j] end
		table.sort(idxs, cmp)
		local out = {}
		for i = 1, num_items do
			out[i] = tmp[idxs[i]]
		end
		tmp = out
	end

	local inserted = 0
	local bins = dynamicBins.bins
	local num_bins = dynamicBins.num_bins
	local cap = dynamicBins.cap
	local approx_stride = dynamicBins.approx_stride
	local bin_range_extension_flat = dynamicBins.bin_range_extension_flat
	local bin_range_extension_ratio = dynamicBins.bin_range_extension_ratio
	local ring_width_tiles = dynamicBins.ring_width_tiles
	local head_bin = nil
	local head_bin_max_ring = nil
	local front = dynamicBins.front
	for i = 1, num_items do
		-- prepare item
		local item = tmp[i]
		local item_data, ring_index = item.item_data, item.ring_index
		-- reload variables in case they changed
		head_bin = front and bins[front] or nil
		head_bin_max_ring = head_bin and head_bin.max_ring or nil
		-- push item
		num_bins = dynamic_bins._push_item(dynamicBins, bins, num_bins, head_bin, head_bin_max_ring, item_data, ring_index, cap, approx_stride, bin_range_extension_flat, bin_range_extension_ratio, ring_width_tiles)
		inserted = inserted + 1
	end
	return inserted
end

-- Batch pop K
-- (prioritize backfill, then frontier)
-- Popping is monotone by ring within the current head bin: we sort that bin once on first use and pop
-- from a moving pointer (ascending order).
function dynamic_bins.batch_pop(dynamicBins, k, only_backfill)
	local item_datas, ring_indices = {}, {}
	if k <= 0 then return item_datas, ring_indices end
	local out = 0
	-- drain backfill first
	local backfill = dynamicBins.backfill
	local backfill_size = #backfill
	while out < k and backfill_size > 0 do
		local item = backfill[backfill_size]
		backfill[backfill_size] = nil
		backfill_size = backfill_size - 1
		local item_data, ring_index = item.item_data, item.ring_index
		if item_data then
			out = out + 1
			item_datas[out], ring_indices[out] = item_data, ring_index
		else
			break
		end
	end

	if out == k or only_backfill then
		dynamicBins.total = dynamicBins.total - out
		return item_datas, ring_indices, out
	end

	local bins = dynamicBins.bins
	local num_bins = dynamicBins.num_bins
	local front = dynamicBins.front
	
	while out < k and (not front or front <= num_bins) do
		if not front then
			-- re-init front or break if no bins
			if num_bins == 0 then break end
			front = 1
			dynamicBins.front = front
		end
		local bin = bins[front]
		local items = bin.items
		local num_items = #items
		if not bin.sorted then
			local keys, idxs = {}, {}
			for i = 1, num_items do
				keys[i] = items[i].ring_index
				idxs[i] = i
			end
			local function cmp(i, j) return keys[i] < keys[j] end
			table.sort(idxs, cmp)
			local out = {}
			for i = 1, num_items do
				out[i] = items[idxs[i]]
			end
			for i = 1, num_items do
				items[i] = out[i]
			end
			bin.sorted = true
			bin.pop_idx = 1
		end
		local pop_idx = bin.pop_idx
		if pop_idx <= num_items then
			local item = items[pop_idx]
			pop_idx = pop_idx + 1
			bin.pop_idx = pop_idx
			out = out + 1
			if pop_idx > num_items then
				num_bins = remove_bin_at(dynamicBins, bins, front) -- empty bin; next shifts into place front
				-- if we removed the head, reset front to nil so the next iteration can re-init
				front = nil
				dynamicBins.front = front
				
			end
			item_datas[out], ring_indices[out] = item.item_data, item.ring_index
		else
			num_bins = remove_bin_at(dynamicBins, bins, front) -- defensive cleanup
			-- if we removed the head, reset front to nil so the next iteration can re-init
			front = nil
			dynamicBins.front = front
		end
	end

	dynamicBins.total = dynamicBins.total - out
	return item_datas, ring_indices, out
end

function dynamic_bins.size(dynamicBins)
	return dynamicBins.total
end

-- returns info as if the front was initialized (if front is nil use front=1)
function dynamic_bins.front_info(dynamicBins)
	local front = dynamicBins.front
	local head = front and dynamicBins.bins[front] or dynamicBins.bins[1]
	if not head then return nil, nil end
	return head.min_ring, head.max_ring
end

function dynamic_bins.backfill_consume(dynamicBins, max_items, ignore_front)
	-- tries to push backfill to bins
	-- uses ring_index push API instead of x and y
	-- so it doesn't recompute ring_index - if centroid changed on this dynamic bins instance
	-- it won't update ring_index from when item was pushed to backfill

	local backfill = dynamicBins.backfill
	local backfill_size = #backfill
	if backfill_size == 0 then return 0 end

	local old_front = dynamicBins.front
	-- ignore front sets current front to nil and later restores it
	if ignore_front then
		dynamicBins.front = nil
	elseif old_front ~= nil then
		-- if not ignoring front and front is active - don't consume backfill
		return 0
	end

	local item_datas, ring_indices, num_popped = dynamic_bins.batch_pop(dynamicBins, backfill_size, true)

       local consumed_items = {} -- array of { item_data, ring_index }
       for i = 1, num_popped do
               consumed_items[i] = { item_datas[i], ring_indices[i] }
       end

	-- add consumed items to bins
	dynamic_bins.batch_push(dynamicBins, consumed_items)

	-- restore front
	if ignore_front then
		dynamicBins.front = old_front
	end

	return num_popped
end
