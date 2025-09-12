utils = {}


-- Water tile lookup table for fast O(1) checking
utils.WaterTiles = {
	["water"] = true,
	["deepwater"] = true,
	["water-green"] = true,
	["water-shallow"] = true,
	["water-mud"] = true,
	["deepwater-green"] = true
}

utils.DryWaterTiles = {
	["lake-shallow"] = true,
	["lake-deep"] = true,
}

utils.WaterAndDryTiles = {
	["water"] = true,
	["deepwater"] = true,
	["water-green"] = true,
	["water-shallow"] = true,
	["water-mud"] = true,
	["deepwater-green"] = true,
	["lake-shallow"] = true,
	["lake-deep"] = true,
}

-- Mapping from a wet water tile to its "dry" equivalent
utils.WetToDryTileMap = {
	["water"] = "lake-shallow",
	["water-green"] = "lake-shallow",
	["water-shallow"] = "lake-shallow",
	["water-mud"] = "lake-shallow",
	["deepwater"] = "lake-deep",
	["deepwater-green"] = "lake-deep",
}

function utils.getDryTileForWetTile(wetTileName)
	return utils.WetToDryTileMap[wetTileName]
end

function utils.IndicatorTableToArray(indicator_table)
	local array = {}
	for tile_name, _ in pairs(indicator_table) do
		array[#array + 1] = tile_name
	end
	return array
end

utils.DeepWaterTiles = {
	["deepwater"] = true,
	["deepwater-green"] = true
}

-- Adjacent position offsets for 8-directional search
utils.AdjacentOffsets = {
	{x =  0, y = -1}, -- north
	{x =  1, y = -1}, -- northeast
	{x =  1, y =  0}, -- east
	{x =  1, y =  1}, -- southeast
	{x =  0, y =  1}, -- south
	{x = -1, y =  1}, -- southwest
	{x = -1, y =  0}, -- west
	{x = -1, y = -1}  -- northwest
}

function utils.rejectEntityPlacement(entity, reason)
	if entity.valid then
		local mined = false
		local last_user = entity.last_user
		if last_user and last_user.valid then
			last_user.print(reason)
			mined = last_user.mine_entity(entity, true)
		end

		if not mined then
			entity.destroy({raise_destroy=true})
		end
	end
end

function utils.validate_tile_placement(position, surface, required_tile_types, forbidden_tile_types)
	local tile_name = utils.GetTile(position, surface).name
	local correct_placement = true
	if forbidden_tile_types and forbidden_tile_types[tile_name] then
		correct_placement = false
	end
	if required_tile_types and not required_tile_types[tile_name] then
		correct_placement = false
	end
	return correct_placement
end

function utils.IsWaterOrDryTile(tileName)
	return utils.IsWaterTile(tileName) or utils.IsDryTile(tileName)
end

function utils.IsDryTile(tileName)
	return utils.DryWaterTiles[tileName] == true
end

function utils.IsWaterTile(tileName)
	return utils.WaterTiles[tileName] == true
end

function utils.GetSurfaceById(surfaceId)
	return game.surfaces[surfaceId]
end

-- any position within tile is valid
-- the returned tile will have position as left-top corner
function utils.GetTile(position, surface)
	return surface.get_tile(position)
end

function utils.CheckSubstring(str, substring)
	return string.find(str, substring, 1, true) ~= nil
end

function utils.RemovePrefix(str, prefix)
	return string.sub(str, #prefix + 1)
end

function utils.GetMaxKey(t)
	local maxKey = 0
	for key, _ in pairs(t) do
		if key > maxKey then
			maxKey = key
		end
	end
	return maxKey
end

function utils.comma_value(n) -- credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function utils.merge_arrays(array1, array2)
	for _, value in ipairs(array2) do
		array1[#array1 + 1] = value
	end
	return array1
end

function utils.remove_table_from_array(array_of_tables, on_key, value_to_match)
	for i, t in ipairs(array_of_tables) do
		if t[on_key] == value_to_match then
			table.remove(array_of_tables, i)
			return true
		end
	end
	return false
end


utils.Queue = {}

-- Ring buffer queue with optional bounding.
-- API remains compatible: new(), enqueue(), dequeue(), is_empty(), merge()
-- Default: unbounded (capacity grows as needed). If max_capacity is provided,
-- the queue is bounded and new items are dropped when full (enqueue returns false).
function utils.Queue.new(initial_capacity, max_capacity, growth_factor, deduplicate)
    local cap = initial_capacity or 1024
    if cap < 1 then cap = 1 end
    return {
        buffer = {},
        capacity = cap,
        size = 0,
        head = 1, -- next index to read
        tail = 1, -- next index to write
        max_capacity = max_capacity, -- nil => unbounded
        growth_factor = growth_factor or 2.0,
        dropped = 0,
        inQueue = deduplicate and {} or nil,
    }
end

local function rb_grow(q)
    -- Grow capacity if unbounded or below max; return true if grown
    if q.max_capacity ~= nil and q.capacity >= q.max_capacity then
        return false
    end
    local new_cap = math.max(1, math.floor(q.capacity * (q.growth_factor or 2.0)))
    if q.max_capacity ~= nil then
        if new_cap > q.max_capacity then new_cap = q.max_capacity end
        if new_cap <= q.capacity then return false end
    end
    local new_buf = {}
    -- copy existing elements in logical order into new buffer [1..size]
    for i = 1, q.size do
        local idx = ((q.head - 1 + i - 1) % q.capacity) + 1
        new_buf[i] = q.buffer[idx]
    end
    q.buffer = new_buf
    q.capacity = new_cap
    q.head = 1
    q.tail = q.size + 1
    return true
end

function utils.Queue.deduplicate_enqueue(queue, value, at_front, deduplicate_hash_function)
	local set = queue.inQueue
	if not set then
		return utils.Queue.enqueue(queue, value, at_front)
	end
	local hash = deduplicate_hash_function and deduplicate_hash_function(value) or value
	if set[hash] then return false end
	local added  = utils.Queue.enqueue(queue, value, at_front)
	if added then set[hash] = true end
	return added
end

-- in case lazy_queues_array is provided:
-- lazy queues have to have the same deduplicate_hash_function as the main queue
-- deduplication is only applied per queue basis, inQueue is not shared between queues
-- deduplication removes items from the actual queue it was drawn from 
function utils.Queue.deduplicate_dequeue(queue, dequeue_back, deduplicate_hash_function, lazy_queues_array)
	local value = dequeue_back and utils.Queue.dequeue_back(queue) or utils.Queue.dequeue(queue)
	if value ~= nil then
		local set = queue.inQueue
		if not set then return value end
		local hash = deduplicate_hash_function and deduplicate_hash_function(value) or value
		set[hash] = nil
	elseif lazy_queues_array then
		for i = 1, #lazy_queues_array do
			local lazy_queue = lazy_queues_array[i]
			if lazy_queue then
				value = utils.Queue.deduplicate_dequeue(lazy_queue, dequeue_back, deduplicate_hash_function, nil)
				if value ~= nil then return value end
			end
		end
		return nil
	end
	return value
end

function utils.Queue.dequeue_with_lazy_arrays(queue, lazy_queues_array)
	local value = utils.Queue.dequeue(queue)
	if value ~= nil or lazy_queues_array == nil then
		return value
	end
	for i = 1, #lazy_queues_array do
		local lazy_queue = lazy_queues_array[i]
		if lazy_queue then
			value = utils.Queue.dequeue(lazy_queue)
			if value ~= nil then return value end
		end
	end
	return nil
end

function utils.Queue.enqueue(queue, value, at_front)
    -- Hot path: cache fields locally to reduce table lookups
    local buffer = queue.buffer
    local size = queue.size
    local capacity = queue.capacity
    if size >= capacity then
        -- Might grow (unbounded) or drop (bounded)
        if not rb_grow(queue) then
            queue.dropped = (queue.dropped or 0) + 1
            return false
        end
        -- Rebind locals after possible growth
        buffer = queue.buffer
        capacity = queue.capacity
    end

	if at_front then
		-- decrement head position and write value at that position
		local head = queue.head
		if head <= 1 then -- wrap around
			head = capacity
		else
			head = head - 1
		end
		buffer[head] = value
		queue.head = head
	else
		local tail = queue.tail
		buffer[tail] = value
		if tail >= capacity then -- wrap around
			tail = 1
		else
			tail = tail + 1
		end
		queue.tail = tail
	end
	size = size + 1
	queue.size = size
	return true
end

function utils.Queue.dequeue(queue)
    if queue.size == 0 then return nil end
    local buffer = queue.buffer
    local head = queue.head
    local capacity = queue.capacity
    local value = buffer[head]
    buffer[head] = nil
    -- branch wrap instead of modulo
    if head == capacity then
        head = 1
    else
        head = head + 1
    end
    queue.head = head
    queue.size = queue.size - 1
    return value
end

function utils.Queue.dequeue_back(queue)
	if queue.size == 0 then return nil end
	local tail = queue.tail
	-- step to the last valid element (tail points to next write)
	if tail == 1 then tail = queue.capacity else tail = tail - 1 end
  
	local buf = queue.buffer
	local v = buf[tail]
	buf[tail] = nil
	queue.tail = tail
	queue.size = queue.size - 1
	return v
  end

function utils.Queue.is_empty(queue)
    return queue.size == 0
end

function utils.Queue.merge(queue, other_queue)
    while not utils.Queue.is_empty(other_queue) do
        local val = utils.Queue.dequeue(other_queue)
        utils.Queue.enqueue(queue, val)
    end
end

function utils.periodic_ticks_to_seconds(num_periodic_ticks)
	return num_periodic_ticks * storage.PeriodicEveryXTicks / 60
end

function utils.normalize_update_values_per_second(value, as_int_ceiling, periodic_tick_per_update)
	local periodic_ticks_per_update = periodic_tick_per_update or storage.PeriodicTicksPerBigUpdate
	local normalized_value = value * periodic_ticks_per_update * storage.PeriodicEveryXTicks / 60
	if as_int_ceiling then
		return math.ceil(normalized_value)
	end
	return normalized_value
end

function utils.fixPositionToLeftTopCorner(position)
	if not utils.checkIfPositionIsLeftTopCorner(position) then
		local x, y = position.x, position.y
		return {x = x - x % 1, y = y - y % 1}
	end
	return position
end

function utils.checkIfPositionIsLeftTopCorner(position)
	return position.x % 1 == 0 and position.y % 1 == 0
end

-- used for profiling only - measure how many times a case was hit by a caller
function utils.profile_hits(caller_name, case_name)
	if not storage.profiling_hits then
		storage.profiling_hits = {}
	end
	if not storage.profiling_hits[caller_name] then
		storage.profiling_hits[caller_name] = {}
	end
	storage.profiling_hits[caller_name][case_name] = (storage.profiling_hits[caller_name][case_name] or 0) + 1
end

utils.LazyTables = {}

function utils.LazyTables.get(key, main_table, lazy_tables_array)
	local value = main_table[key]
	if value ~= nil	 then
		return value
	end
	local arr = lazy_tables_array or {}
	for i = 1, #arr do
		local lazy_table = arr[i]
		if lazy_table then
			value = lazy_table[key]
			if value ~= nil then
				return value
			end
		end
	end

	return nil
end

function utils.LazyTables.remove(key, main_table, lazy_tables_array)
	main_table[key] = nil
	local arr = lazy_tables_array or {}
	for i = 1, #arr do
		local lazy_table = arr[i]
		if lazy_table then
			lazy_table[key] = nil
		end
	end
end

function utils.LazyTables.moveLazyQueue(main_queue, lazy_queue, max_values_to_move, extra_data, callback)
	local moved = 0
	local k = utils.Queue.dequeue(lazy_queue)
	while moved < max_values_to_move and k ~= nil do
		utils.Queue.enqueue(main_queue, k)
		if callback then
			-- for queues there is no separate key; pass value as both key and value
			callback(k, k, extra_data)
		end
		moved = moved + 1
		k = utils.Queue.dequeue(lazy_queue)
	end
	return moved, utils.Queue.is_empty(lazy_queue)
end

function utils.LazyTables.moveLazyTable(main_table, lazy_table, max_values_to_move, extra_data, callback)
	local moved = 0
	local k, v = next(lazy_table)
	while moved < max_values_to_move and k ~= nil do
		local next_k, next_v = next(lazy_table, k) -- prefetch next key before deleting current
		main_table[k] = v
		lazy_table[k] = nil
		if callback then
			callback(k, v, extra_data)
		end
		moved = moved + 1
		k, v = next_k, next_v
	end
	local tableEmpty = next(lazy_table) == nil
	return moved, tableEmpty
end

function utils.LazyTables.wasAnyTableEmptied(extra_data_array)
	for _, extra_data in ipairs(extra_data_array) do
		if extra_data.tableEmpty then
			return true
		end
	end
	return false
end

function utils.LazyTables.moveLazyTables(main_table, lazy_tables_array, max_values_to_move, max_per_table, is_queue, callback)
	if not lazy_tables_array or max_values_to_move <= 0 then return 0, {} end
	local moved = 0
	local i = 1
	local j = 1
	local extra_data_array = {}
	local function_to_move = is_queue and utils.LazyTables.moveLazyQueue or utils.LazyTables.moveLazyTable
	while moved < max_values_to_move and i <= #lazy_tables_array do
		local currentTable = lazy_tables_array[i]
		if currentTable then
			extra_data_array[j] = {tableEmpty = false}
			local max_to_move = math.min(max_per_table, max_values_to_move - moved)
			local tableMoved, tableEmpty = function_to_move(main_table, currentTable, max_to_move, extra_data_array[j], callback)
			moved = moved + tableMoved
			if tableEmpty then
				-- remove and do not increment i; next table shifts into position i
				table.remove(lazy_tables_array, i)
				extra_data_array[j].tableEmpty = true
			else
				i = i + 1
			end
			j = j + 1
		else
			-- compact holes
			table.remove(lazy_tables_array, i)
		end
		
	end
	return moved, extra_data_array
end

function utils.LazyTables.on_merge(lazy_tables_array, other_main_table, other_lazy_tables_array)
	table.insert(lazy_tables_array, other_main_table)
	for i = 1, #other_lazy_tables_array do
		local lazy_table = other_lazy_tables_array[i]
		if lazy_table then
			table.insert(lazy_tables_array, lazy_table)
		end
	end
end

function utils.LazyTables.next(main_table, lazy_tables_array, k, t)
	if t == nil then t = 0 end
	local v

	-- iterate main table first
	if t == 0 then
		k, v = next(main_table, k)
		-- if item found then return
		if k ~= nil then
			return k, v, 0
		end
		-- if empty move to next lazy table
		t = t + 1
		k = nil
		
	end
	local arr = lazy_tables_array or {}
	while t <= #arr do
		local tab = arr[t]
		if tab then
			k, v = next(tab, k)
			if k ~= nil then
				return k, v, t
			end
		end
		-- current lazy table exhausted or nil -> move to next
		t = t + 1
		k = nil
	end
	-- all tables exhausted
	return nil, nil, nil
end

utils.MapMarker = {}

function utils.MapMarker.new(force, surface, position, text, icon)
    local tag = force.add_chart_tag(surface, {position = position, text = text, icon = icon})
    return {
        tag = tag,
        force = force,
        surface = surface,
        position = position,
        text = text,
        icon = icon
    }
end

function utils.MapMarker.valid(marker)
    return marker.tag and marker.tag.valid
end

function utils.MapMarker.destroy(marker)
    if utils.MapMarker.valid(marker) then
        marker.tag.destroy()
    end
end

function utils.MapMarker.update(marker, position, text, icon)
    if not utils.MapMarker.valid(marker) then return end

    local position_changed = position ~= nil and hot_utils.GridKey(position) ~= hot_utils.GridKey(marker.position)
    local text_changed = text ~= nil and text ~= marker.text
    local icon_changed = icon ~= nil and (icon.type ~= marker.icon.type or icon.name ~= marker.icon.name)
	
	if position_changed then marker.position = position end
	if text_changed then marker.text = text end
    if icon_changed then marker.icon = icon end
	
    if position_changed then
		-- position is read-only so we need to destroy and create a new tag
        utils.MapMarker.destroy(marker)
        marker.tag = marker.force.add_chart_tag(marker.surface, {
            position = marker.position,
            text = marker.text,
            icon = marker.icon
        })
	elseif text_changed or icon_changed then
		-- text and icon are mutable so we can update them
		marker.tag.text = marker.text
		marker.tag.icon = marker.icon
    end
end
