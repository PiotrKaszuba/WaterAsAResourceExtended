-- hot_utils.lua
-- Performance-sensitive helpers used in on_tick and other tight loops

hot_utils = {}

-- same as utils.GridKey(position) was but optimized for hot paths
-- also, because it has to be used exclusively - the utils.GridKey(position) got removed
-- uses 10 milion as multiplier because factorio limits world to 2 milion x 2 milion
-- Lua uses double-precision floating point (IEEE 754) for all numbers
-- maximum integer value that can be stored precisely in a 
-- double-precision floating-point format is equal to 9,007,199,254,740,991
-- that's about 9 * 10^15
-- so we use 10 milion = 10^7 as multiplier, because 10^7 * 2*10^6 = 2 * 10^13 < 9 * 10^15
function hot_utils.GridKey(position)
	return position.x * 10000000 + position.y
end

-- requires surfaceName
function hot_utils.writeWaterTileAndGetPrevious(gridKey, surfaceName, waterBodyId)
	-- not using getWaterTile on purpose
    local previous_owner = storage.WaterTiles[surfaceName][gridKey]
    local write_id = waterBodyId or -1
    storage.WaterTiles[surfaceName][gridKey] = write_id
	return write_id, previous_owner
end

-- same as waterbodies.getWaterTile() but optimized for hot paths; uses surfaceName instead of surface
-- assumes WaterTiles and surface are initialized
-- requires surfaceName to be passed around in hot loops
function hot_utils.getWaterTile(gridKey, surfaceName)
    return storage.WaterTiles[surfaceName][gridKey]
end

-- same as waterbodies.checkIfTileIsNotAssignedToWaterBody() but optimized for hot paths
-- uses surfaceName instead of surface
-- assumes ValidWaterBodies are initialized and completely trusted
function hot_utils.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceName)
    local waterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)
    return storage.ValidWaterBodies[waterBodyId] == nil
end

-- same as waterbodies.addNewWaterTile() but optimized for hot paths
-- original function is removed as it was used in too few other places
-- and these places got adapted to use hot_utils.addNewWaterTile()
-- uses surfaceName instead of surface
function hot_utils.addNewWaterTile(gridKey, surfaceName, waterBodyId)
	-- not calling getWaterTile on purpose - violate DRY
	-- 3 lines below is just hot_utils.writeWaterTileAndGetPrevious()
	local previous_owner = storage.WaterTiles[surfaceName][gridKey]
    local write_id = waterBodyId or -1
    storage.WaterTiles[surfaceName][gridKey] = write_id

	local waterBodyToNumTiles = storage.WaterBodyToNumTiles
	if previous_owner ~= nil then
		local previous_owner_num_tiles = waterBodyToNumTiles[previous_owner]
		waterBodyToNumTiles[previous_owner] = previous_owner_num_tiles - 1
		if previous_owner_num_tiles <= 1 then
			-- remove from this table and add recycled water body id
			waterBodyToNumTiles[previous_owner] = nil
			table.insert(storage.RecycledWaterBodyIds, previous_owner)
		end
	end
	waterBodyToNumTiles[write_id] = (waterBodyToNumTiles[write_id] or 0) + 1
end

-- same as waterbodies.getWaterTilePercentageWaterUsed() but optimized for hot paths
-- original function is removed as it wasn't used in other places
-- uses surfaceName instead of surface
-- uses storage directly
-- assumes waterbody is not nil (because it still had a tile assigned to it - so its id wasn't recycled)
function hot_utils.getWaterTilePercentageWaterUsed(gridKey, surfaceName)
	local waterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)
	if waterBodyId == nil or waterBodyId == -1 then
		return 0
	end
	local waterBody = storage.WaterBodies[waterBodyId]
	-- valid == false check is important - because we take penalty after invalid waterbodies
	-- and only invalid ones have PercentageWaterUsed field
	if waterBody.valid == false then
		return waterBody.PercentageWaterUsed
	end
	return 0
end
