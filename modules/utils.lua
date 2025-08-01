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

function utils.GetWaterTileNamesArray()
	local water_tile_names = {}
	for tile_name, _ in pairs(utils.WaterTiles) do
		water_tile_names[#water_tile_names + 1] = tile_name
	end
	return water_tile_names
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

function utils.calculate_direction_offset(position, direction)
	local offset_position = {x = position.x, y = position.y}
	
	if direction == 0 then -- North
		offset_position.y = position.y - 1
	elseif direction == 4 then -- East  
		offset_position.x = position.x + 1
	elseif direction == 8 then -- South
		offset_position.y = position.y + 1
	elseif direction == 12 then -- West
		offset_position.x = position.x - 1
	end
	
	return offset_position
end

function utils.rejectEntityPlacement(entity, reason)
    if entity.last_user and entity.last_user.valid then
        entity.last_user.print(reason)
        entity.last_user.insert{name = entity.name, count = 1}
    end
    entity.destroy()
end

function utils.validate_tile_placement(position, surfaceId, required_tile_types)
	local tile_name = utils.GetTile(position, surfaceId).name
	if required_tile_types[tile_name] then
		return true
	end
	
	return false
end

function utils.IsWaterTile(tileName)
	return utils.WaterTiles[tileName] == true
end

function utils.GetWaterDepthType(fluidname)
	-- return "shallow" or "deep" or nil if not water tile
	if utils.IsWaterTile(fluidname) then
		if utils.DeepWaterTiles[fluidname] then
			return "deep"
		else
			return "shallow"
		end
	end
	return nil
end

function utils.PositionToString (position)
	return string.format ("%.1f , %.1f", position.x , position.y)	-- Print SearchPosition X, Y CoOrds as String
end

function utils.StringToPosition(gridKey)
    local x, y = gridKey:match("([^,]+) , ([^,]+)")
    return {x = tonumber(x), y = tonumber(y)}
end

function utils.GetSurface(surfaceId)
	return game.surfaces[surfaceId]
end

-- any position within tile is valid
-- the returned tile will have position as left-top corner
function utils.GetTile(position, surfaceId)
	return game.surfaces[surfaceId].get_tile(position.x, position.y)
end

function utils.IsThereWater(position, surfaceId)
	local tile = utils.GetTile(position, surfaceId)
	if tile.valid == true then
		return utils.WaterTiles[tile.name] == true
	else
		-- shouldn't happen so show warning
		game.print("Invalid Tile")
		return false
	end
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

utils.Queue = {}
utils.Queue.__index = utils.Queue 

function utils.Queue:new()
    local obj = {
        first = 1,
        last = 0,
        data = {}
    }
    setmetatable(obj, utils.Queue)
    return obj
end

function utils.Queue:enqueue(value)
    self.last = self.last + 1
    self.data[self.last] = value
end

function utils.Queue:dequeue()
    if self:is_empty() then return nil end
    local value = self.data[self.first]
    self.data[self.first] = nil  -- Allow garbage collection
    self.first = self.first + 1
    return value
end

function utils.Queue:is_empty()
    return self.first > self.last
end

function utils.Queue:merge(other_queue)
    while not other_queue:is_empty() do
        local val = other_queue:dequeue()
        self:enqueue(val)
    end
end


