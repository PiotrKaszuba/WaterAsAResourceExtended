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

function utils.CheckSubstring(string, substring)
	return string.find(string, substring, 1, true) ~= nil
end

function utils.RemovePrefix(string, prefix)
	return string.sub(string, #prefix + 1)
end

function utils.GetMaxKey(table)
	local maxKey = 0
	for key, _ in pairs(table) do
		if key > maxKey then
			maxKey = key
		end
	end
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

function utils.Queue.new()
    return {
        first = 1,
        last = 0,
        data = {}
    }
end

function utils.Queue.enqueue(queue, value)
    queue.last = queue.last + 1
    queue.data[queue.last] = value
end

function utils.Queue.dequeue(queue)
    if utils.Queue.is_empty(queue) then return nil end
    local value = queue.data[queue.first]
    queue.data[queue.first] = nil
    queue.first = queue.first + 1
    return value
end

function utils.Queue.is_empty(queue)
    return queue.first > queue.last
end

function utils.Queue.merge(queue, other_queue)
    while not utils.Queue.is_empty(other_queue) do
        local val = utils.Queue.dequeue(other_queue)
        utils.Queue.enqueue(queue, val)
    end
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
