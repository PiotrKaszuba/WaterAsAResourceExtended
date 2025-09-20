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


-- hot write variant that accepts a pre-bound reference
function hot_utils.addNewWaterTileRef(gridKey, surfaceName, waterBodyRef)
	local previous_owner_ref = storage.WaterTiles[surfaceName][gridKey]
	if previous_owner_ref == waterBodyRef then
		return  -- no need to do anything
	end
	storage.WaterTiles[surfaceName][gridKey] = waterBodyRef

	local waterBodyToNumTiles = storage.WaterBodyToNumTiles
	if previous_owner_ref ~= nil then
		local previous_owner_id = previous_owner_ref[1]
		local previous_owner_num_tiles = waterBodyToNumTiles[previous_owner_id]
		waterBodyToNumTiles[previous_owner_id] = (previous_owner_num_tiles or 0) - 1
		if (previous_owner_num_tiles or 0) <= 1 and previous_owner_id ~= -1 then
			-- remove from this table and add recycled water body id
			waterBodyToNumTiles[previous_owner_id] = nil
			table.insert(storage.RecycledWaterBodyIds, previous_owner_id)
			-- also clear the reference table
			storage.WaterBodyRef[previous_owner_id] = nil
			-- remove from split families -- parent mode
			split_families.on_removed(previous_owner_id, true)
		end
	end
	local write_id = waterBodyRef[1]
	waterBodyToNumTiles[write_id] = (waterBodyToNumTiles[write_id] or 0) + 1
end

-- same as waterbodies.getWaterTile() but optimized for hot paths; uses surfaceName instead of surface
-- assumes WaterTiles and surface are initialized
-- requires surfaceName to be passed around in hot loops
function hot_utils.getWaterTile(gridKey, surfaceName)
    local waterBodyRef = storage.WaterTiles[surfaceName][gridKey]
	if waterBodyRef == nil then
		return nil
	end
	return waterBodyRef[1]
end

-- same as waterbodies.checkIfTileIsNotAssignedToValidWaterBody but optimized for hot paths
-- uses surfaceName instead of surface
-- assumes ValidWaterBodies are initialized and completely trusted
function hot_utils.checkIfTileIsNotAssignedToValidWaterBody(gridKey, surfaceName)
    local waterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)
    return storage.ValidWaterBodies[waterBodyId] == nil
end

-- same as waterbodies.addNewWaterTile but optimized for hot paths
-- original function is removed as it was used in too few other places
-- and these places got adapted to use hot_utils.addNewWaterTile
-- uses surfaceName instead of surface
-- assumes waterBodyId is initialized in waterbodies.addNewWaterBodyAndSetId
function hot_utils.addNewWaterTile(gridKey, surfaceName, waterBodyId)
	local write_id = waterBodyId or -1
	local waterBodyRef = storage.WaterBodyRef[write_id]
	hot_utils.addNewWaterTileRef(gridKey, surfaceName, waterBodyRef)
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

function hot_utils.isTileInGrid(waterGridWithData, lazyWaterGridWithData, driedTilesGridWithData, lazyDriedTilesGridWithData, gridKey)
	return utils.LazyTables.get(gridKey, waterGridWithData, lazyWaterGridWithData) ~= nil or utils.LazyTables.get(gridKey, driedTilesGridWithData, lazyDriedTilesGridWithData) ~= nil
end
