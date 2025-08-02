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

-- any position within tile is valid
-- the returned tile will have position as left-top corner
-- this is a hot path, so we don't want to call utils.GetSurface()
-- we assume that surface is valid
-- 
function hot_utils.GetTile(position, surface)
	return surface.get_tile(position)
end

function hot_utils.writeWaterTileAndGetPrevious(gridKey, surface, waterBodyId)
	-- not using getWaterTile on purpose
	local surfaceName = surface.name
    local previous_owner = storage.WaterTiles[surfaceName][gridKey]
    local write_id = waterBodyId or -1
    storage.WaterTiles[surfaceName][gridKey] = write_id
	return write_id, previous_owner
end

-- same as waterbodies.getWaterTile() but optimized for hot paths
function hot_utils.getWaterTile(gridKey, surface)
    return storage.WaterTiles[surface.name][gridKey]
end