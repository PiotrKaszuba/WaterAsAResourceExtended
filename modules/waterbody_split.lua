require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.entities")
require("modules.utils")

waterbody_split = {}


function waterbody_split.getWaterBodyLimitedBoundingBox(shape_data, center_position, side_length)
	local minX = shape_data.MinX
	local minY = shape_data.MinY
	local maxX = shape_data.MaxX
	local maxY = shape_data.MaxY

	-- local desired_rect_area = side_length * side_length
	local max_rect_area = (maxX - minX) * (maxY - minY)

	local bbox = {
		left_top = {
			x = math.max(minX, center_position.x - side_length / 2),
			y = math.max(minY, center_position.y - side_length / 2),
		},
		right_bottom = {
			x = math.min(maxX, center_position.x + side_length / 2),
			y = math.min(maxY, center_position.y + side_length / 2),
		},
	}

	local rect_area = (bbox.right_bottom.x - bbox.left_top.x) * (bbox.right_bottom.y - bbox.left_top.y)
	local rect_area_ratio = rect_area / max_rect_area
	return bbox, rect_area_ratio
end

function waterbody_split.getWaterBodyConnectedTiles(waterBody, start_tile_pos, otherTiles_positions, surfaceId, center_position, updateBudget)
	local current_check_size = 2
	local rect_area_ratio = 0.0
	local start_tile_gridKey = utils.PositionToString(start_tile_pos)
	local connected_tiles = {}
	connected_tiles[start_tile_gridKey] = true
	local missing_tiles = {} -- indicator table, gridKey -> true
	for _, tile_pos in pairs(otherTiles_positions) do
		missing_tiles[utils.PositionToString(tile_pos)] = true
	end
	missing_tiles[start_tile_gridKey] = nil

	local bbox = nil
	while rect_area_ratio < 1.0 do
		if updateBudget then
			updateBudget.budget = updateBudget.budget - (current_check_size * current_check_size) / 4
		end
		bbox, rect_area_ratio = waterbody_split.getWaterBodyLimitedBoundingBox(waterBody.waterBodyShapeData, center_position, current_check_size)
		local all_connected_tiles = utils.GetSurface(surfaceId).get_connected_tiles(start_tile_pos, utils.GetWaterTileNamesArray(), true, bbox)
		for _, tile_pos in pairs(all_connected_tiles) do
			if missing_tiles[utils.PositionToString(tile_pos)] then
				connected_tiles[utils.PositionToString(tile_pos)] = true
				missing_tiles[utils.PositionToString(tile_pos)] = nil
			end
		end
		if next(missing_tiles) == nil then
			break
		end
		current_check_size = current_check_size * 2
	end

	return connected_tiles, missing_tiles
end

function waterbody_split.checkIfAllTilesAreUsedAndUnique(all_tiles_positions, connected_tiles_sets_gridKeys)
	local temp_all_tiles_set = {}
	local temp_gridKey = nil
	for _, tile_pos in pairs(all_tiles_positions) do
		temp_gridKey = utils.PositionToString(tile_pos)
		temp_all_tiles_set[temp_gridKey] = true
	end
	for _, connected_tiles_set_gridKeys in pairs(connected_tiles_sets_gridKeys) do
		for grid_key, _ in pairs(connected_tiles_set_gridKeys) do
			if not temp_all_tiles_set[grid_key] then
				return "duplicate"
			end
			temp_all_tiles_set[grid_key] = nil
		end
	end
	return next(temp_all_tiles_set) == nil and "ok" or "not_all_used"
end

function waterbody_split.signalWaterBodySplitToPlayer(waterBody, force, num_new_water_bodies)
	return string.format("%s split into %s waterbodies.", waterbodies.getFullNameForWaterBody(waterBody), num_new_water_bodies)
end

function waterbody_split.checkIfWaterBodyGotSplit(waterBodyId, split_position, surfaceId, updateBudget)
	-- assume split_position is left-top corner already

	-- water body got split if there is no path between 2 neigboring water tiles (to the landfilled tile)
	-- check all adjacent water tiles
	local adjacent_waterbody_tiles, _ = waterbody_scan.getAdjacentWaterAndLandTiles(split_position, surfaceId, waterBodyId)

	-- we need to check if there is a path between any of the adjacent water tiles
	-- we can use get_connected_tiles with increasing area (BoundingBox)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
    if not waterBody or not waterBody.valid then
        return
    end

	local connected_tile_sets = {} -- table of tables, each table is a set of onnected tiles
	local missing_tiles_positions = {}
	local new_missing_tiles_positions = nil
	for _, tile_pos in pairs(adjacent_waterbody_tiles) do
		missing_tiles_positions[#missing_tiles_positions + 1] = tile_pos
	end
	while #missing_tiles_positions > 0 do
		if updateBudget then
			updateBudget.budget = updateBudget.budget - 1
		end
		local start_tile_pos = table.remove(missing_tiles_positions)
		local connected_tiles, missing_tiles = waterbody_split.getWaterBodyConnectedTiles(waterBody, start_tile_pos, missing_tiles_positions, surfaceId, split_position, updateBudget)
		connected_tile_sets[#connected_tile_sets + 1] = connected_tiles

		new_missing_tiles_positions = {}
		for _, tile_pos in pairs(missing_tiles_positions) do
			local gridKey = utils.PositionToString(tile_pos)
			if missing_tiles[gridKey] then
				new_missing_tiles_positions[#new_missing_tiles_positions + 1] = tile_pos
			end
		end
		missing_tiles_positions = new_missing_tiles_positions
	end

	local check_result = waterbody_split.checkIfAllTilesAreUsedAndUnique(adjacent_waterbody_tiles, connected_tile_sets)
	if check_result ~= "ok" then
		game.print(string.format("WARNING: Water body got split, validation of neighboring water tiles failed: %s", check_result))
	end
	
	-- now we have separated water bodies represented by initial tile_sets in connected_tile_sets
	-- each tile_set represent a separate water body with a few tiles
	-- we need to actually split the water bodies now

	-- select one tile from each connected_tile_set andcreate new water bodies from them
	-- as well as from all the water pumps that are present in the water body
	-- handle the drained water so that none can exploit it for free water

	local got_split = #connected_tile_sets > 1
	

	if got_split then
		waterbodies.signalPerForce(waterBody, waterbody_split.signalWaterBodySplitToPlayer, #connected_tile_sets)
		local new_water_body_ids = {}
		-- TODO should notify interested parties
		local pumps = waterBody.entitiesData.pumps
		waterBody.entitiesData.pumps = {}
		waterbodies.removeWaterBody(waterBody)
		local first_tile_pos = nil
		for _, tile_set in pairs(connected_tile_sets) do
			_, first_tile_pos = next(tile_set)
			local new_water_body_id = waterbodies.createNewWaterBody(surfaceId)
			new_water_body_ids[#new_water_body_ids + 1] = {waterBodyId = new_water_body_id, position = first_tile_pos}
		end

		for pump_unit_number, pump_data in pairs(pumps) do
			local pump_input_position = pump_data.input_position
			-- check if this is still water tile
			if utils.validate_tile_placement(pump_input_position, surfaceId, utils.WaterTiles) then
				local new_water_body_id = waterbodies.createNewWaterBody(surfaceId)
				
				-- fix position to left-top corner in case it was not
				local tile = utils.GetTile(pump_input_position, surfaceId)
				local pump_input_top_left_corner = tile.position
				
				new_water_body_ids[#new_water_body_ids + 1] = {waterBodyId = new_water_body_id, position = pump_input_top_left_corner}
				entities.movePumpToWaterBody(pump_unit_number, new_water_body_id, waterBodyId)
			else
				entities.disablePump(pump_data)
			end
		end

		for _, new_water_body_id in pairs(new_water_body_ids) do
			waterbody_scan.beginScanWaterArea(new_water_body_id.waterBodyId, new_water_body_id.position, 1, updateBudget)
		end

		for _, new_water_body_id in pairs(new_water_body_ids) do
			waterbody_scan.continueScanWaterArea(new_water_body_id.waterBodyId, math.ceil(waterbody_scan.getInitialScanAmount() / #new_water_body_ids))
		end
		
		if updateBudget then
			updateBudget.budget = updateBudget.budget - waterbody_scan.getInitialScanAmount()
		end

	end

end