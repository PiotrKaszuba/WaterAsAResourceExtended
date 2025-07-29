require("utils")
require("forces")

waterbodies = {}

function waterbodies.initWaterBodies()
    if storage.WaterBodies == nil then
        storage.WaterBodies = {}
		storage.NextWaterBodyId = 1
		storage.ValidWaterBodies = {} -- waterBodyId -> true
    end
    if storage.ScanningWaterBodies == nil then
        storage.ScanningWaterBodies = {}
    end
end

function waterbodies.getValidWaterBodies()
    return storage.ValidWaterBodies
end

function waterbodies.initWaterTiles()
    if storage.WaterTiles == nil then
        storage.WaterTiles = {} -- surfaceId -> gridKey -> waterBodyId
    end
end

function waterbodies.initSurface(surfaceId)
    if storage.WaterTiles[surfaceId] == nil then
        storage.WaterTiles[surfaceId] = {} -- gridKey -> waterBodyId
    end
end

function waterbodies.initTileEventQueue()
    if storage.TileEventQueue == nil then
        storage.TileEventQueue = utils.Queue:new()
    end
end

function waterbodies.getTileEventQueue()
    return storage.TileEventQueue
end

function waterbodies.initTileEvent(eventType, position, surfaceId, tileData)
	return {
		type = eventType, -- "landfill" or "waterfill"
		position = position,
		surfaceId = surfaceId,
		tileData = tileData
	}
end


function waterbodies.getAdjacentWaterAndLandTiles(position, surfaceId, water_body_id)
	-- if water_body_id is given then only return adjacent water tiles that are part of the water body
	local adjacent_waterbody_tiles = {}
	local adjacent_land_tiles = {}
	for _, offset in pairs(utils.AdjacentOffsets) do
		local adj_pos = {x = position.x + offset.x, y = position.y + offset.y}
		local adj_gridKey = utils.PositionToString(adj_pos)
		local adj_waterBodyId = waterbodies.getWaterTile(adj_gridKey, surfaceId)
		local is_water_tile = utils.IsWaterTile(utils.GetTile(adj_pos, surfaceId).name)
		if (water_body_id == nil or adj_waterBodyId == water_body_id) and is_water_tile then
			adjacent_waterbody_tiles[#adjacent_waterbody_tiles + 1] = adj_pos
		elseif not is_water_tile then
			adjacent_land_tiles[#adjacent_land_tiles + 1] = adj_pos
		end
	end
	return adjacent_waterbody_tiles, adjacent_land_tiles
end

function waterbodies.recalculateEdgesAroundPosition(waterBody, position, surfaceId, updateBudget)
	local adjacent_waterbody_tiles, adjacent_land_tiles = waterbodies.getAdjacentWaterAndLandTiles(position, surfaceId, waterBody.waterBodyId)
    
	-- remove from edge grid - all adjacent land tiles
	for _, position in pairs(adjacent_land_tiles) do
		waterBody.gridsData.edgeGrid[utils.PositionToString(position)] = nil
	end

	-- rebuild edges using EdgePattern
	for _, position in pairs(adjacent_waterbody_tiles) do
		-- this has to be completed even if budget is 0
		if updateBudget then
			updateBudget.budget = updateBudget.budget - 1
		end
		waterbodies.EdgePattern(position, surfaceId, waterBody.searchData, true, true)
	end
end


function waterbodies.reduceTileFromWaterBody(waterBody, originalTileName, position, surfaceId, updateBudget)
	local gridKey = utils.PositionToString(position)
    local tileType = waterbodies.WaterTileToWaterBodyTileType[originalTileName]
    if not tileType then return end
    
    -- 1. Reduce tile count
    waterBody.waterBodyTileCountData[tileType] = 
        math.max(0, waterBody.waterBodyTileCountData[tileType] - 1)
    
    -- 2. Remove from waterGrid
    waterbodies.removeTileFromWaterGrid(waterBody, gridKey)
    
    -- 3. Mark tile as unassigned in global registry
    waterbodies.addNewWaterTile(gridKey, surfaceId, -1)
    
    -- 4. Recalculate edges around this position
    waterbodies.recalculateEdgesAroundPosition(waterBody, position, surfaceId, updateBudget)
    
    -- 5. Mark for water amount recalculation
    waterBody.waterAreaData.ToCalculate = true
    
    -- 6. Check if water body becomes empty
    if waterbodies.isWaterBodyEmpty(waterBody) then
        waterbodies.markWaterBodyForCleanup(waterBody)
    end
end

function waterbodies.isWaterBodyEmpty(waterBody)
    for _, count in pairs(waterBody.waterBodyTileCountData) do
        if count > 0 then
            return false
        end
    end
    return true
end


function waterbodies.addTileEvent(eventType, position, surfaceId, tileData)
    storage.TileEventQueue:enqueue(waterbodies.initTileEvent(eventType, position, surfaceId, tileData))
end

function waterbodies.getWaterBodyLimitedBoundingBox(waterBody, center_position, side_length)
	local minX = waterBody.shapeData.MinX
	local minY = waterBody.shapeData.MinY
	local maxX = waterBody.shapeData.MaxX
	local maxY = waterBody.shapeData.MaxY

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

function waterbodies.getWaterBodyConnectedTiles(waterBody, start_tile_pos, otherTiles_positions, surface, center_position, updateBudget)
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
		bbox, rect_area_ratio = waterbodies.getWaterBodyLimitedBoundingBox(waterBody, center_position, current_check_size)
		local all_connected_tiles = surface.get_connected_tiles(start_tile_pos, utils.GetWaterTileNamesArray(), true, bbox)
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

function waterbodies.checkIfAllTilesAreUsedAndUnique(all_tiles_positions, connected_tiles_sets_gridKeys)
	local temp_all_tiles_set = {}
	local temp_gridKey = nil
	for _, tile_pos in pairs(all_tiles_positions) do
		temp_gridKey = utils.PositionToString(tile_pos)
		temp_all_tiles_set[temp_gridKey] = true
	end
	for _, connected_tiles_set_gridKeys in pairs(connected_tiles_sets_gridKeys) do
		for _, grid_key in pairs(connected_tiles_set_gridKeys) do
			if not temp_all_tiles_set[grid_key] then
				return "duplicate"
			end
			temp_all_tiles_set[grid_key] = nil
		end
	end
	return next(temp_all_tiles_set) == nil and "ok" or "not_all_used"
end

function waterbodies.checkIfWaterBodyGotSplit(waterBodyId, split_position, surfaceId, updateBudget)
	-- water body got split if there is no path between 2 neigboring water tiles (to the landfilled tile)
	-- check all adjacent water tiles
	local adjacent_waterbody_tiles, _ = waterbodies.getAdjacentWaterAndLandTiles(split_position, surfaceId, waterBodyId)

	-- we need to check if there is a path between any of the adjacent water tiles
	-- we can use get_connected_tiles with increasing area (BoundingBox)
	local surface = utils.GetSurface(surfaceId)
	local waterBody = waterbodies.getWaterBody(waterBodyId)

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
		local connected_tiles, missing_tiles = waterbodies.getWaterBodyConnectedTiles(waterBody, start_tile_pos, missing_tiles_positions, surface, split_position, updateBudget)
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


	local check_result = waterbodies.checkIfAllTilesAreUsedAndUnique(adjacent_waterbody_tiles, connected_tile_sets)
	if check_result ~= "ok" then
		game.print("WARNING: Water body got split, validation of neighboring water tiles failed")
	end
	
	-- now we have separated water bodies represented by initial tile_sets in connected_tile_sets
	-- each tile_set represent a separate water body with a few tiles
	-- we need to actually split the water bodies now

	-- select one tile from each connected_tile_set andcreate new water bodies from them
	-- as well as from all the water pumps that are present in the water body
	-- handle the drained water so that none can exploit it for free water

	local got_split = #connected_tile_sets > 1
	

	if got_split then
		local new_water_body_ids = {}
		-- TODO should notify interested parties
		pumps = waterBody.entitiesData.pumps
		waterBody.entitiesData.pumps = {}
		waterbodies.markWaterBodyForCleanup(waterBody)
		local first_tile_pos = nil
		for _, tile_set in pairs(connected_tile_sets) do
			_, first_tile_pos = next(tile_set)
			local new_water_body_id = waterbodies.createNewWaterBody(surfaceId)
			new_water_body_ids[#new_water_body_ids + 1] = {waterBodyId = new_water_body_id, position = first_tile_pos}
		end

		for pump_unit_number, pump_data in pairs(pumps) do
			local pump_input_position = pump_data.input_position
			-- check if this is still water tile
			if utils.validate_tile_placement(pump_input_position, surface, utils.WaterTiles) then
				local new_water_body_id = waterbodies.createNewWaterBody(surfaceId)
				new_water_body_ids[#new_water_body_ids + 1] = {waterBodyId = new_water_body_id, position = pump_input_position}
				entities.movePumpToWaterBody(pump_unit_number, new_water_body_id, waterBodyId)
			else
				local new_entity = entities.replacePumpEntity(pump_data, entities.pump_entity_types.inactive)
				entities.removeTrackedEntity(new_entity.unit_number)
			end
		end

		for _, new_water_body_id in pairs(new_water_body_ids) do
			waterbodies.beginScanWaterArea(new_water_body_id.waterBodyId, new_water_body_id.position, 1, updateBudget)
		end

		for _, new_water_body_id in pairs(new_water_body_ids) do
			waterbodies.continueScanWaterArea(new_water_body_id.waterBodyId, math.ceil(waterbodies.getSplitScanAmount() / #new_water_body_ids))
		end
		
		if updateBudget then
			updateBudget.budget = updateBudget.budget - waterbodies.getSplitScanAmount()
		end

	end

end


function waterbodies.processLandfillEvent(tileEvent, updateBudget)
	local position = tileEvent.position
	local surfaceId = tileEvent.surfaceId
    local gridKey = utils.PositionToString(position)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
    
    if not waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId) then
        local waterBody = waterbodies.getWaterBody(waterBodyId)
		if waterBody and waterBody.valid then
			if updateBudget then
				updateBudget.budget = updateBudget.budget - 2
			end
            waterbodies.reduceTileFromWaterBody(waterBody, tileEvent.tileData.originalTileName, position, surfaceId, updateBudget)
        end
		if waterBody.valid then
			waterbodies.checkIfWaterBodyGotSplit(waterBodyId, position, surfaceId, updateBudget)
		end
    end
end

function waterbodies.processWaterfillEvent(tileEvent, updateBudget)
    local position = tileEvent.position
    local surfaceId = tileEvent.surfaceId
    local tileName = tileEvent.tileData.tileName
    
	if updateBudget then
		updateBudget.budget = updateBudget.budget - 1
	end

    -- Find adjacent water bodies
    local adjacentWaterBodies = waterbodies.findAdjacentWaterBodies(position, surfaceId)
    
    if #adjacentWaterBodies == 0 then
        -- Create new water body and start scanning
        local waterBody = waterbodies.createNewWaterBody(surfaceId)
        local new_water_body_id = waterbodies.beginScanWaterArea(waterBody.waterBodyId, position, 1, updateBudget)
		if new_water_body_id ~= waterBody.waterBodyId then
			waterBody = waterbodies.getWaterBody(new_water_body_id)
		end
        
    elseif #adjacentWaterBodies == 1 then
        -- Extend existing water body
        local waterBodyId = adjacentWaterBodies[1]
        local waterBody = waterbodies.getWaterBody(waterBodyId)
        
        if waterBody then
            waterBody.searchData.searchQueue:enqueue(position)
            waterBody.searchData.finished = false
            waterBody.waterAreaData.ToCalculate = true
			-- also remove the tile from edge grid
			waterBody.gridsData.edgeGrid[utils.PositionToString(position)] = nil
        end
        
		-- scan a bit 

    else
        -- Multiple water bodies - merge them
        local new_water_body_id = waterbodies.mergeMultipleWaterBodies(adjacentWaterBodies, position, surfaceId)
		if new_water_body_id ~= waterBody.waterBodyId then
			waterBody = waterbodies.getWaterBody(new_water_body_id)
		end
		if updateBudget then
			updateBudget.budget = updateBudget.budget - #adjacentWaterBodies
		end
    end
end

function waterbodies.findAdjacentWaterBodies(position, surfaceId)
    local waterBodyIds = {}
    local seen = {}
    
    for _, offset in pairs(utils.AdjacentOffsets) do
        local adj_pos = {x = position.x + offset.x, y = position.y + offset.y}
        local adj_gridKey = utils.PositionToString(adj_pos)
        local waterBodyId = waterbodies.getWaterTile(adj_gridKey, surfaceId)
        
        if not waterbodies.checkIfTileIsNotAssignedToWaterBody(adj_gridKey, surfaceId) and not seen[waterBodyId] then
            waterBodyIds[#waterBodyIds + 1] = waterBodyId
            seen[waterBodyId] = true
        end
    end
    
    return waterBodyIds
end

function waterbodies.mergeMultipleWaterBodies(waterBodyIds, triggerPosition, surfaceId)
    if #waterBodyIds < 2 then return end
    
    local targetWaterBody = waterbodies.getWaterBody(waterBodyIds[1])
    if not targetWaterBody then return end
    
    for i = 2, #waterBodyIds do
        local otherWaterBody = waterbodies.getWaterBody(waterBodyIds[i])
        if otherWaterBody and otherWaterBody.valid then
            waterbodies.mergeWaterBody(targetWaterBody, otherWaterBody)
        end
    end
    
    targetWaterBody.searchData.searchQueue:enqueue(triggerPosition)
    targetWaterBody.searchData.finished = false
	targetWaterBody.waterAreaData.ToCalculate = true
	-- also remove the tile from edge grid
	targetWaterBody.gridsData.edgeGrid[utils.PositionToString(triggerPosition)] = nil

	return targetWaterBody.waterBodyId
end

function waterbodies.processTileEventQueue(maxEvents, updateBudget)
	local queue = waterbodies.getTileEventQueue()
    local processedCount = 0
    
    while not queue:is_empty() and processedCount < maxEvents and updateBudget.budget > 0 do
        local event = queue:dequeue()
        
        if event.type == "landfill" then
            waterbodies.processLandfillEvent(event, updateBudget)
        elseif event.type == "waterfill" then
            waterbodies.processWaterfillEvent(event, updateBudget)
        end
        
        processedCount = processedCount + 1
    end
    
    return processedCount
end

function waterbodies.handleTileEventsInternal(tiles, surfaceIndex)
    if not tiles or not surfaceIndex then return end
    
    for _, tile_event in pairs(tiles) do
        local position = tile_event.position
        local old_name = tile_event.old_tile and tile_event.old_tile.name
        local new_name = tile_event.name
        
        if new_name == "landfill" and old_name and utils.IsWaterTile(old_name) then
            waterbodies.addTileEvent("landfill", position, surfaceIndex, {
                originalTileName = old_name,
				tileName = new_name,
            })
        elseif utils.IsWaterTile(new_name) and old_name and not utils.IsWaterTile(old_name) then
            waterbodies.addTileEvent("waterfill", position, surfaceIndex, {
				originalTileName = old_name,
                tileName = new_name,
            })
        end
    end
end

function waterbodies.handlePlayerTileEvents(event)
    if event.mod_name == "creative-mod" then return end
    
    waterbodies.handleTileEventsInternal(
        event.tiles,
        event.surface_index
    )
end

function waterbodies.handleScriptTileEvents(event)
    local tileTypes = {}
    for _, tile in pairs(event.tiles) do
        tileTypes[tile.name] = true
    end
    
    if #tileTypes > 1 then
        game.print("Warning: script_raised_set_tiles with multiple tile types - processing all")
    end
    
    waterbodies.handleTileEventsInternal(
        event.tiles,
        event.surface_index
    )
end


-- optional waterBodyId argument to link to a water body
-- if not present use as waterbodies.addNewWaterTile(position, surfaceId, -1)
function waterbodies.addNewWaterTile(gridKey, surfaceId, waterBodyId)
    waterbodies.initSurface(surfaceId)

    storage.WaterTiles[surfaceId][gridKey] = waterBodyId or -1
end

function waterbodies.getWaterTile(gridKey, surfaceId)
    waterbodies.initSurface(surfaceId)
    return storage.WaterTiles[surfaceId][gridKey]
end

function waterbodies.checkIfWaterTileExists(gridKey, surfaceId)
    return waterbodies.getWaterTile(gridKey, surfaceId) ~= nil
end

function waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
    if waterBodyId == nil or waterBodyId == -1 then
		return true
	end
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid then
		return false
	end
	return true
end

function waterbodies.getWaterTilePercentageWaterUsed(gridKey, surfaceId)
	local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
	if waterBodyId == nil or waterBodyId == -1 then
		return 0
	end
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid == false then
		return waterBody.PercentageWaterUsed
	end
	return 0
end

function waterbodies.getNextFreeWaterBodyId()
    local waterBodyId = storage.NextWaterBodyId
    while storage.WaterBodies[waterBodyId] ~= nil do
        waterBodyId = waterBodyId + 1
    end
	storage.NextWaterBodyId = waterBodyId + 1
    return waterBodyId
end

function waterbodies.addNewWaterBodyAndSetId(waterBody)
    local waterBodyId = waterbodies.getNextFreeWaterBodyId()
    storage.WaterBodies[waterBodyId] = waterBody
    waterBody.waterBodyId = waterBodyId
	storage.ValidWaterBodies[waterBodyId] = true
    return waterBodyId
end

function waterbodies.getWaterBody(waterBodyId)
    return storage.WaterBodies[waterBodyId]
end

function waterbodies.checkWaterBodyExists(waterBodyId)
    return storage.WaterBodies[waterBodyId] ~= nil
end


function waterbodies.InitSearchData()
	return {
		searchQueue = utils.Queue:new(),
		searchedPositions = {}, -- indicator table, position key
		totalArea = 0,
		finished = false,
	}
end

function waterbodies.merge_indicator_tables(table_result, table_other)
    for k in pairs(table_other) do
        table_result[k] = true
    end	
end

function waterbodies.mergeSearchData(searchData, other_searchData, overlapTileCountData)
	searchData.searchQueue:merge(other_searchData.searchQueue)
	waterbodies.merge_indicator_tables(searchData.searchedPositions, other_searchData.searchedPositions)
	
	local sum_overlap = 0
	for k, v in pairs(overlapTileCountData) do
		sum_overlap = sum_overlap + v
	end
	searchData.totalArea = searchData.totalArea + other_searchData.totalArea - sum_overlap
	searchData.finished = searchData.searchQueue:is_empty()
end


function waterbodies.initGridsData()
	return {
		waterGridWithData = {}, -- table with position, name, originalName for tiles, also used as indicator table, position key
		edgeGrid = {}, -- indicator table, position key
	}
end

function waterbodies.getWaterAreaArray(waterBody)
    local waterArea = {}
    for _, tileData in pairs(waterBody.gridsData.waterGridWithData) do
        waterArea[#waterArea + 1] = tileData
    end
    return waterArea
end

function waterbodies.addTileToWaterGrid(waterBody, position, tileName)
    local gridKey = utils.PositionToString(position)
    waterBody.gridsData.waterGridWithData[gridKey] = {
        name = tileName,
        position = position,
        originalName = tileName
    }
end

function waterbodies.removeTileFromWaterGrid(waterBody, gridKey)
    waterBody.gridsData.waterGridWithData[gridKey] = nil
end

function waterbodies.mergeGridsData(gridsData, other_gridsData, include_global_water_tiles, surfaceId)
	local overlapTileCountData = waterbodies.initWaterBodyTileCountData()

	for gridKey, tileData in pairs(other_gridsData.waterGridWithData) do

		-- check by the waterGrid if the tile is already in the current water body
		if gridsData.waterGridWithData[gridKey] == nil then
			-- this tile is not in the current water body - add it
			gridsData.waterGridWithData[gridKey] = tileData
		else
			local waterBodyTileType = waterbodies.WaterTileToWaterBodyTileType[tileData.name]
			overlapTileCountData[waterBodyTileType] = overlapTileCountData[waterBodyTileType] + 1

		end

		-- if include_global_water_tiles is true -> transfer ownership of the tile to the current water body
		if include_global_water_tiles then
			waterbodies.addNewWaterTile(gridKey, surfaceId, gridsData.waterBodyId)
		end
	end

	waterbodies.merge_indicator_tables(gridsData.edgeGrid, other_gridsData.edgeGrid)

	return overlapTileCountData
end


function waterbodies.initEntitiesData()
	return {
		pumps = {}, -- unit_number -> pump data (and entity)
		forces = {}, -- indicator table that stores force name -> true
	}
end

function waterbodies.mergeEntitiesData(entitiesData, other_entitiesData, waterBodyId, other_waterBodyId)
	for _, v in pairs(other_entitiesData.pumps) do
		entities.movePumpToWaterBody(v.entity.unit_number, waterBodyId, other_waterBodyId)
	end
	
	waterbodies.merge_indicator_tables(entitiesData.forces, other_entitiesData.forces)
end

function waterbodies.initShapeData()
    return {
        ["MinX"] = 0,
        ["MaxX"] = 0,
        ["MinY"] = 0,
        ["MaxY"] = 0,
        ["Hdif"] = 0,
        ["Vdif"] = 0,     ["Hyp"] = 0,
    }
end

function waterbodies.mergeShapeData(shapeData, other_shapeData)
	shapeData.MinX = math.min(shapeData.MinX, other_shapeData.MinX)
	shapeData.MaxX = math.max(shapeData.MaxX, other_shapeData.MaxX)
	shapeData.MinY = math.min(shapeData.MinY, other_shapeData.MinY)
	shapeData.MaxY = math.max(shapeData.MaxY, other_shapeData.MaxY)
	waterbodies.calculateDimensions(shapeData)
end

function waterbodies.initWaterBodyTileCountData()
    return {
        ["ShallowWater"] = 0,
        ["DeepWater"] = 0,
        ["ShallowWater-Shallow"] = 0,
        ["ShallowWater-Mud"] = 0,
    }   
end

function waterbodies.mergeWaterBodyTileCountData(tileCountData, other_tileCountData, overlapTileCountData)
	for k, v in pairs(tileCountData) do
		tileCountData[k] = v + (other_tileCountData[k] or 0) - (overlapTileCountData[k] or 0)
	end
end

function waterbodies.initWaterAreaData()
    return {
		["ToCalculate"] = true,
        ["WaterBodyType"] = 0,
        ["BonusValue"] = 0,
        ["AmountWtr"] = 0,
        ["RegenAmount"] = 0,
        ["TotalArea"] = 0,
    }
end

-- there is no merge for WaterAreaData - it will be re-calculated totally based on other merged data

function waterbodies.initWaterUsageTickStats()
	local waterUsageTickStats = {}
	local numTicks = storage.LoopNumTicks

	for i = 1, numTicks do
		waterUsageTickStats[i] = 0
	end

	return waterUsageTickStats
end

function waterbodies.mergeWaterUsageTickStats(waterUsageTickStats, other_waterUsageTickStats)
	for i = 1, #waterUsageTickStats do
		waterUsageTickStats[i] = waterUsageTickStats[i] + (other_waterUsageTickStats[i] or 0)
	end
end

function waterbodies.initWaterBodyStateData()
    return {
        ["WaterUsed"] = 0,
        ["WaterUsedPrev"] = 0,

		["WaterUsedPenalty"] = 0,

        ["Depleted"] = false,

		["Fired50"] = false,
		["Fired75"] = false,
		["Fired90"] = false,
		["Fired95"] = false,
		["Fired97"] = false,
		["Fired98"] = false,
		["Fired99"] = false,

		["BTF"] = 0,

		["LoopCount"] = 0,

		-- TODO: create class for map marker that will handle all the map marker logic
		-- and have .destroy() ethod
        ["MapMarker"] = {},
    }
end

function waterbodies.mergeWaterBodyStateData(waterBodyStateData, other_waterBodyStateData)
	waterBodyStateData.WaterUsed = waterBodyStateData.WaterUsed + other_waterBodyStateData.WaterUsed
	waterBodyStateData.WaterUsedPrev = waterBodyStateData.WaterUsedPrev + other_waterBodyStateData.WaterUsedPrev

	waterBodyStateData.Depleted = waterBodyStateData.Depleted or other_waterBodyStateData.Depleted

	waterBodyStateData.Fired50 = waterBodyStateData.Fired50 or other_waterBodyStateData.Fired50
	waterBodyStateData.Fired75 = waterBodyStateData.Fired75 or other_waterBodyStateData.Fired75
	waterBodyStateData.Fired90 = waterBodyStateData.Fired90 or other_waterBodyStateData.Fired90
	waterBodyStateData.Fired95 = waterBodyStateData.Fired95 or other_waterBodyStateData.Fired95
	waterBodyStateData.Fired97 = waterBodyStateData.Fired97 or other_waterBodyStateData.Fired97
	waterBodyStateData.Fired98 = waterBodyStateData.Fired98 or other_waterBodyStateData.Fired98
	waterBodyStateData.Fired99 = waterBodyStateData.Fired99 or other_waterBodyStateData.Fired99

	waterBodyStateData.BTF = waterBodyStateData.BTF + other_waterBodyStateData.BTF


	if waterBodyStateData.MapMarker and waterBodyStateData.MapMarker.valid then
		waterBodyStateData.MapMarker.destroy()
	end
	if other_waterBodyStateData.MapMarker and other_waterBodyStateData.MapMarker.valid then
		other_waterBodyStateData.MapMarker.destroy()
	end


end


-- TODO: port more params from above
-- IDEA: make them separate 'structures' such as SearchData, TileData, MapMarker, WaterBodyState (for changing values such as depleted), AlarmData, PositionData (minX, maxX, minY, maxY) etc.
function waterbodies.InitWaterBody(
    surfaceId,
	waterAreaData,
	gridsData,
	entitiesData,

    waterBodyShapeData,
    waterBodyTileCountData,
	searchData,
	waterBodyStateData,

    waterBodyId,
    waterBodyName

)
	return {
		valid = true, -- if false, the water body is not valid and should be deleted

        surfaceId = surfaceId or nil,
        waterBodyId = waterBodyId or nil,
        waterBodyName = waterBodyName or nil,

		waterAreaData = waterAreaData or waterbodies.initWaterAreaData(),
		gridsData = gridsData or waterbodies.initGridsData(),
		entitiesData = entitiesData or waterbodies.initEntitiesData(),
		waterBodyShapeData = waterBodyShapeData or waterbodies.initShapeData(),
		waterBodyTileCountData = waterBodyTileCountData or waterbodies.initWaterBodyTileCountData(),
		searchData = searchData or waterbodies.InitSearchData(),
		waterBodyStateData = waterBodyStateData or waterbodies.initWaterBodyStateData(),

		waterBodyTileCountPercentagePenalty = waterbodies.initWaterBodyTileCountData(),
		waterUsageTickStats = waterbodies.initWaterUsageTickStats(),


	}
end

function waterbodies.simpleInitWaterBody(surfaceId)
	return waterbodies.InitWaterBody(surfaceId, nil, nil, nil, nil, nil, nil, nil, nil)
end

function waterbodies.mergeWaterBody(waterBody1, waterBody2)
	-- returns the merged water body
	-- the other one has to be deleted from the storage

	-- bigger water body absorbs the smaller one
	if waterBody1.searchData.totalArea < waterBody2.searchData.totalArea then
		waterBody1, waterBody2 = waterBody2, waterBody1
	end

	-- waterBody2 is merged into waterBody1

	-- check if the water bodies are on the same surface
	if waterBody1.surfaceId ~= waterBody2.surfaceId then
		error("Water bodies are on different surfaces")
	end

	if not waterBody1.valid or not waterBody2.valid then
		error("Water bodies are not valid")
	end

	local overlapTileCountData = waterbodies.mergeGridsData(waterBody1.gridsData, waterBody2.gridsData, true, waterBody1.surfaceId)
	waterbodies.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountData, waterBody2.waterBodyTileCountData, overlapTileCountData)
	waterbodies.mergeSearchData(waterBody1.searchData, waterBody2.searchData, overlapTileCountData)
	waterbodies.mergeWaterBodyStateData(waterBody1.waterBodyStateData, waterBody2.waterBodyStateData)

	waterbodies.mergeShapeData(waterBody1.waterBodyShapeData, waterBody2.waterBodyShapeData)
	
	
	waterbodies.mergeEntitiesData(waterBody1.entitiesData, waterBody2.entitiesData, waterBody1.waterBodyId, waterBody2.waterBodyId)

	waterbodies.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountPercentagePenalty, waterBody2.waterBodyTileCountPercentagePenalty)
	waterbodies.mergeWaterUsageTickStats(waterBody1.waterUsageTickStats, waterBody2.waterUsageTickStats)

	waterBody1.waterAreaData.ToCalculate = true

	waterbodies.markWaterBodyForCleanup(waterBody2)

	return waterBody1.waterBodyId
end

waterbodies.Oceans = {"Arctic","Atlantic","Indian","Pacific","Southern"}
waterbodies.Lakes = {"Alakol","Albano","Albert","Alexandrina","Amadeus","Amatitlán","Apanás","Argyle","Assal","Athabasca","Atitlán","Baikal","Balaton","Balkhash","Bangweulu","Baringo","Biel","Big Stone ","Biwa","Bled","Bosumtwi","Bracciano","Bras d’Or ","Buir","Burragorang","Chad","Champlain","Chapala","Chelan","Chiemsee","Chilka ","Chilwa","Chiuta","Chott El-Chergui","Chott El-Hodna","Chott El-Jarid","Chott Melrhir","Chrissie","Chūzenji","Coeur d’Alene","Como","Constance","Crater","Cuitzeo","Derwent","Dhebar","Dian","Dongting","Earn","Edward","Elton","Er","Erie","Eucumbene","Eyasi","Eyre","Faguibine","Fingers","Flathead","Frome","Gairdner","Garda","Gatun","Geneva","George","Great ","Great Bear","Great Salt","Great Slave","Grevelingen","Guier","Ḥammār","Hawea","Hawr Al-Ḥabbāniyyah","Hongze","Hornindals","Hövsgöl","Hulun","Hume Reservoir","Huron","IJsselmeer","Iliamna","Ilmen","Ilopango","Inari","Iseo","Island","Izabal","Kainji","Kariba","Kawartha","Kentucky","Khanka","Kisale","Kivu","Koko Nor","Kolleru","Königssee","Kyoga","Lac Débo","Lac la Ronge","Lac Saint-Jean","Ladoga","Laguna de Bay","Lanao","Last Mountain","Lauricocha","Lesser Slave","Llanquihue","Loch Awe","Loch Katrine","Loch Leven","Loch Lomond","Loch Ness","Loch Shiel","Lough Allen","Lough Corrib","Lough Derg","Lough Erne","Lough Mask","Lough Neagh","Lough Ree","Lucerne","Lugano","Magadi","Maggiore","Mai-Ndombe","Mainit","Mälar","Malebo Pool","Malombe","Managua","Manapouri","Manitoba","Manyara","Mapam","Mar Chiquita","Mead","Melville","Memphremagog","Menindee","Michigan","Mistassini","Mjøsa","Montenegro","Moosehead","Muskoka","Mweru","Mývatn","Nahuel Huapí","Naivasha","Nakuru","Näsi","Nasser","Natron","Naujan","Nemi","Neuchâtel","Neusiedler","Ngami","Nicaragua","Nipigon","Nipissing","Nyasa","Ohrid","Okeechobee","Onega","Ontario","Orta","Päijänne","Peipus","Pend Oreille","Petén Itzá","Pielinen","Pontchartrain","Poopó","Poyang","Prespa","Pukaki","Pulicat","Pyramid","Rainy","Rangeley","Reelfoot","Reindeer","River Tummel","Rotorua","Rudolf","Rukwa","Saimaa","Saint Clair","Sambhar Salt","Saranac","Scutari","Sea of Galilee","Sevan","Sevier","Shala","Siljan","Simcoe","Soap","Soda","Štrbské Pleso","Superior","Taal","Tahoe","Tai","Tana","Tanganyika","Taupo","Te Anau","Tegernsee","Tekapo","Tengiz","Teshekpuk","Texcoco","Thingvalla","Titicaca","Toba","Todos los Santos","Tonle Sap","Torrens","Towada","Trasimeno","Tumba","Tuz","Tyers","Tyri","Tyrrell","Ullswater","Urmia","Utah","Valencia","Van","Väner","Vätter","Victoria","Volta","Võrtsjärv","Waikaremoana","Wakatipu","Wanaka","Windermere","Winnipeg","Winnipegosis","Winnipesaukee","Wissel","Wollaston","Wular","Yellowstone","Yojoa","Ysyk","Zaysan","Zürich"}
waterbodies.Seas = {"Adriatic","Aegean","Albemarle Sound","Alboran","Amundsen","Amundsen Gulf","Andaman","Arabian","Arafura","Archipelago","Arctic Ocean","Argentine","Argolic Gulf","Baffin Bay","Balearic","Bali","Baltic","Banda","Barents","Bass Strait","Bay of Bengal","Bay of Biscay","Bay of Campeche","Bay of Fundy","Beaufort","Bellingshausen","Bering","Bismarck","Black","Block Island Sound","Bohai","Bohol","Bothnian","Buzzards Bay","Camotes","Cantabrian","Cape Cod Bay","Caribbean","Celebes","Celtic","Central Baltic","Ceram","Chesapeake Bay","Chilean","Chukchi","Cilician","Cooperation","Coral","Cosmonauts","Davis","Davis Strait","Delaware Bay","Denmark Strait","Dering Harbor","Drake Passage","D'Urville","East China","East Siberian","English Channel","Fishers Island Sound","Flanders Bay","Flore","Florida Bay","Fort Pond Bay","Gardiners Bay","Golfo de los Mosquitos","Great Australian Bight","Greenland","Gulf of Aden","Gulf of Alaska","Gulf of Carpentaria","Gulf of Corinth","Gulf of Darién","Gulf of Genoa","Gulf of Gonâve","Gulf of Guinea","Gulf of Honduras","Gulf of Lion","Gulf of Maine","Gulf of Martaban","Gulf of Mexico","Gulf of Oman","Gulf of Paria","Gulf of Riga","Gulf of Sidra","Gulf of St. Lawrence","Gulf of Thailand","Gulf of Venezuela","Gulf St Vincent","Halmahera","Hudson Bay","Hudson Strait","Icarian","Inland","Investigator Strait","Ionian","Irish","Irminger","Jamaica Bay","James Bay","Java","Kara","King Haakon VII","Koro","Labrador","Laccadive","Laptev","Lazarev","Levantine","Libyan","Ligurian","Lincoln","Long Beach Bay","Long Island Sound","Lower New York Bay","Mar de Grau","Massachusetts Bay","Mawson","Mediterranean","Mobile Bay","Molucca","Mozambique Channel","Myrtoan","Nantucket Sound","Napeague Bay","Narragansett Bay","New York Bay","North","North  Harbor","North Euboean Gulf","Norwegian","Noyack Bay","Oresund Strait","Pamlico Sound","Pechora","Peconic Bay","Pensacola Bay","Persian Gulf","Philippine","Pipes Cove","Prince Gustav Adolf","Queen Victoria","Raritan Bay","Red","Rhode Island Sound","Riiser-Larsen","Ross","Sag Harbor Bay","Salish","Sandy Hook Bay","Saronic Gulf","Savu","Scotia","Seto Inland","Shelter Island Sound","Sibuyan","Solomon","Somov","South China","South Euboean Gulf","Southold Bay","Spencer Gulf","Sulu","Tampa Bay","Tasman","The Northwest Passages","Thermaic Gulf","Thracian","Three Mile Harbor","Timor","Tobaccolot Bay","Tyrrhenian","Upper New York Bay","Vermillion Bay","Vineyard Sound","Visayan","Wadden","Wandel","Weddell","White","Yellow"}

waterbodies.WaterBodyTypesToName = {
	[0] = "Puddle",
	[1] = "Well",
	[2] = "Pond",
	[3] = "Lake",
	[4] = "Great Lake",
	[5] = "Sea",
	[6] = "Ocean"
}

waterbodies.WaterBodyTypeToWaterBonusValue = {
	[0] = 0.01,
	[1] = 0.5,
	[2] = 1,
	[3] = 1.5,
	[4] = 2,
	[5] = 2.5,
	[6] = 3
}

-- max area of water body, has to strictly increase
waterbodies.WaterBodyTypeThresholdArea = {
	[0] = 3,
	[1] = 4,
	[2] = 200,
	[3] = 6000,
	[4] = 60000,
	[5] = 600000,
	[6] = math.huge
}

waterbodies.WaterBodyTypeToNamesCollection = {
	[3] = waterbodies.Lakes,
	[4] = waterbodies.Lakes,
	[5] = waterbodies.Seas,
	[6] = waterbodies.Oceans
}

--local WaterBodyType = storage.WaterGlobalArea[a]["WaterBodyType"]
function waterbodies.GenerateWaterBodyName(WaterBodyType) --Random Name Function

	local nameSuffix = waterbodies.WaterBodyTypesToName[WaterBodyType]
	--check whether we have name collection for this water body type
	if waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType] ~= nil then
		local randAmount = #waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType]
		local rand = math.random(1,randAmount)
		local name = waterbodies.WaterBodyTypeToNamesCollection[WaterBodyType][rand]
			.. nameSuffix
		return name
	end

	return nameSuffix

end


waterbodies.WaterBodyTileTypesToAmountWaterTypes = {
	["ShallowWater"] = "TileFluidAmount-Shallow",
	["DeepWater"] = "TileFluidAmount-Deep",
	["ShallowWater-Shallow"] = "TileFluidAmount-Shallow",
	["ShallowWater-Mud"] = "TileFluidAmount-Shallow"
}

waterbodies.WaterBodyTileTypesToAmountWaterMultiplier = {
	["ShallowWater"] = 1,
	["DeepWater"] = 1,
	["ShallowWater-Shallow"] = 0.5,
	["ShallowWater-Mud"] = 0.25
}

waterbodies.WaterTileToWaterBodyTileType = {
	["water"] = "ShallowWater",
	["water-green"] = "ShallowWater",
	["water-shallow"] = "ShallowWater-Shallow",
	["water-mud"] = "ShallowWater-Mud",
	["deepwater"] = "DeepWater",
	["deepwater-green"] = "DeepWater",
}

waterbodies.EdgeTileNameMap = {
	["water"] = "lake-shallow",
	["water-green"] = "lake-shallow",
	["water-shallow"] = "lake-shallow",
	["water-mud"] = "lake-shallow",
	["deepwater"] = "lake-deep",
	["deepwater-green"] = "lake-deep",
}

function waterbodies.GetAmountWaterForTileType(tileType)
	return settings.global[waterbodies.WaterBodyTileTypesToAmountWaterTypes[tileType]].value
end

function waterbodies.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local totalArea = 0
	local totalWater = 0
	local penaltyWaterUsed = 0
	for tileType, multiplier in pairs(waterbodies.WaterBodyTileTypesToAmountWaterMultiplier) do
		local amount = waterBody.waterBodyTileCountData[tileType]
		if amount ~= nil then
			totalArea = totalArea + amount
			local amountWater = amount * waterbodies.GetAmountWaterForTileType(tileType) * multiplier
			totalWater = totalWater + amountWater
		end
		local penalty_amount = waterBody.waterBodyTileCountPercentagePenalty[tileType]
		if penalty_amount ~= nil then
			local amountWaterPenalty = penalty_amount * waterbodies.GetAmountWaterForTileType(tileType) * multiplier
			penaltyWaterUsed = penaltyWaterUsed + amountWaterPenalty
		end
	end
	return totalArea, totalWater, penaltyWaterUsed
end

function waterbodies.GetWaterBodyType(totalArea)
	for waterBodyType, thresholdArea in pairs(waterbodies.WaterBodyTypeThresholdArea) do
		if totalArea < thresholdArea then
			return waterBodyType
		end
	end
end

function waterbodies.GetWaterBodyRegen(totalArea)
	local regenOff = settings.global["Disable-FluidArea-RegenRate"].value
	if regenOff == false then
		local regenRate = settings.global["FluidArea-RegenRate"].value / 10000
		return regenRate * totalArea
	else
		return 0
	end
end

function waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody)
	
	local totalArea, totalWater, penaltyWaterUsed = waterbodies.CalculateWaterBodyTotalAreaAndWater(waterBody)
	local waterBodyType = waterbodies.GetWaterBodyType(totalArea)
	local bonusValue = waterbodies.WaterBodyTypeToWaterBonusValue[waterBodyType]
	local amountWater = totalWater * bonusValue

	local regenAmount = waterbodies.GetWaterBodyRegen(totalArea)

	waterBody.waterAreaData.TotalArea = totalArea
    waterBody.waterAreaData.BonusValue = bonusValue
	waterBody.waterAreaData.AmountWtr = amountWater
	waterBody.waterAreaData.RegenAmount = regenAmount
	waterBody.waterAreaData.WaterBodyType = waterBodyType
	
	waterBody.waterBodyStateData.WaterUsedPenalty = penaltyWaterUsed

	waterBody.waterAreaData.ToCalculate = false

end


function waterbodies.EdgePattern(searchPosition, surfaceId, searchData, force_edge_pattern, skip_water_tiles)
    local edgeFound = false
    
    for _, offset in pairs(utils.AdjacentOffsets) do
        local position = {x = searchPosition.x + offset.x, y = searchPosition.y + offset.y}
        local gridKey = utils.PositionToString(position)
        
        if (not searchData.searchedPositions[gridKey]) or force_edge_pattern then
            local tile = utils.GetTile(position, surfaceId)
            if tile.valid then
                local tile_position = {x = tile.position.x, y = tile.position.y}
                if utils.IsWaterTile(tile.name) and not skip_water_tiles then
                    searchData.searchQueue:enqueue(tile_position)
                else
                    local edgeKey = utils.PositionToString(tile_position)
                    waterbodies.addNewWaterTile(edgeKey, surfaceId, -1)
                    searchData.edgeGrid[edgeKey] = true
                    edgeFound = true
                end
            end
        end
    end
    
    return edgeFound
end

function waterbodies.createNewWaterBody(surfaceId)
    local waterBody = waterbodies.simpleInitWaterBody(surfaceId)
    waterbodies.addNewWaterBodyAndSetId(waterBody)
    return waterBody
end


-- assign a tile to a water body
-- if the tile is already assigned to a different water body, we have to merge the two water bodies
function waterbodies.assignTileToWaterBody(gridKey, surfaceId, waterBodyId)
    local tile_waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
	local new_water_body_id = waterBodyId
    if waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId) then
        waterbodies.addNewWaterTile(gridKey, surfaceId, waterBodyId)
    elseif tile_waterBodyId ~= waterBodyId then
        -- tile is already assigned to a different water body
        -- we have to merge the two water bodies
		new_water_body_id = waterbodies.mergeWaterBody(waterbodies.getWaterBody(tile_waterBodyId), waterbodies.getWaterBody(waterBodyId))
    end
	return new_water_body_id
end

-- return waterBodyId of existing or new water body
function waterbodies.createWaterBodyFromTileIfNotExists(position, surfaceId)

    local gridKey = utils.PositionToString(position)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)

    if waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId) then
        local waterBody = waterbodies.createNewWaterBody(surfaceId)
		waterbodies.beginScanWaterArea(waterBody.waterBodyId, position)
        return waterBody.waterBodyId
    end

    return waterBodyId
end




-- Process a single water tile during scanning (internal helper)
function waterbodies.processWaterTile(water_body, position, tile_name, surface_id)
	local gridKey = utils.PositionToString(position)

	if not utils.IsWaterTile(tile_name) and not waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surface_id) then
		-- Non-water tile - mark as searched without adding to water body and skip
		waterbodies.addNewWaterTile(gridKey, surface_id, -1)
		return water_body
	end
	
    local waterBodyTileType = waterbodies.WaterTileToWaterBodyTileType[tile_name]
	if waterBodyTileType ~= nil then
		local new_water_body_id = waterbodies.assignTileToWaterBody(gridKey, surface_id, water_body.waterBodyId)
		if new_water_body_id ~= water_body.waterBodyId then
			water_body = waterbodies.getWaterBody(new_water_body_id)
		else
			local waterGridWithData = water_body.gridsData.waterGridWithData
			if waterGridWithData[gridKey] == nil then
				water_body.waterBodyTileCountData[waterBodyTileType] = water_body.waterBodyTileCountData[waterBodyTileType] + 1
				
				local tile_percentage_water_used = waterbodies.getWaterTilePercentageWaterUsed(gridKey, surface_id)
				water_body.waterBodyTileCountPercentagePenalty[waterBodyTileType] = water_body.waterBodyTileCountPercentagePenalty[waterBodyTileType] + tile_percentage_water_used
				
				water_body.searchData.totalArea = water_body.searchData.totalArea + 1
				waterbodies.addTileToWaterGrid(water_body, position, tile_name)
			end
		end
		-- Check for edge pattern and add adjacent tiles to search queue
		waterbodies.EdgePattern(position, surface_id, water_body.searchData)

		waterbodies.updateBoundingBox(water_body.waterBodyShapeData, position)

    end

	return water_body
	
end

function waterbodies.calculateDimensions(shape_data)
	shape_data["Hdif"] = shape_data["MaxX"] - shape_data["MinX"]
	shape_data["Vdif"] = shape_data["MaxY"] - shape_data["MinY"]
	shape_data["Hyp"] = math.sqrt((shape_data["Hdif"]^2) + (shape_data["Vdif"]^2))
end

-- Update water body bounding box (internal helper)
function waterbodies.updateBoundingBox(shape_data, position)
	if shape_data["MinX"] == 0 or position.x < shape_data["MinX"] then
		shape_data["MinX"] = position.x
	end
	if shape_data["MaxX"] == 0 or position.x > shape_data["MaxX"] then
		shape_data["MaxX"] = position.x
	end
	if shape_data["MinY"] == 0 or position.y < shape_data["MinY"] then
		shape_data["MinY"] = position.y
	end
	if shape_data["MaxY"] == 0 or position.y > shape_data["MaxY"] then
		shape_data["MaxY"] = position.y
	end
	waterbodies.calculateDimensions(shape_data)
end

function waterbodies.getInitialScanAmount()
    return settings.global["FluidArea-Start-Area"].value
end

function waterbodies.getAdditionalScanAmount()
    return settings.global["FluidArea-Additional-Tiles-Per-Second"].value
end

function waterbodies.getMaxWaterBodySize()
    return settings.global["FluidArea-MaxFluidAreaSize"].value
end

function waterbodies.getSplitScanAmount()
	return settings.global["FluidArea-Split-Scan-Amount"].value
end


function waterbodies.continueScanWaterArea(water_body_id, scan_amount)
	local water_body = waterbodies.getWaterBody(water_body_id)
	local finished, water_body = waterbodies.ScanWaterArea(water_body, scan_amount)
	return water_body.waterBodyId
end

function waterbodies.beginScanWaterArea(water_body_id, start_position, scan_amount, updateBudget)
	local scan_amount = scan_amount or waterbodies.getInitialScanAmount()
	local water_body = waterbodies.getWaterBody(water_body_id)
	local search_queue = water_body.searchData.searchQueue
	search_queue:enqueue(start_position)
	local finished, water_body = waterbodies.ScanWaterArea(water_body, scan_amount, updateBudget)
	return water_body.waterBodyId
end




-- Scan water area starting from a position and build tile data
-- Returns: true if scan is complete, false if it is continuing
function waterbodies.ScanWaterArea(water_body, search_amount, updateBudget)

	local surface_id = water_body.surfaceId
	local water_body_max_area = waterbodies.getMaxWaterBodySize()
	if updateBudget then
		search_amount = math.min(search_amount, updateBudget.budget)
	end

	water_body.waterAreaData.ToCalculate = true
	
	-- Process tiles from search queue
	while not water_body.searchData.searchQueue:is_empty() and search_amount > 0 do
		local search_position = water_body.searchData.searchQueue:dequeue()
		local gridKey = utils.PositionToString(search_position)
		if not water_body.searchData.searchedPositions[gridKey] then
			water_body.searchData.searchedPositions[gridKey] = true
			if water_body.searchData.totalArea <= water_body_max_area then
				local tile_name = utils.GetTile(search_position, surface_id).name
				water_body = waterbodies.processWaterTile(water_body, search_position, tile_name, surface_id)
			end
		end
		search_amount = search_amount - 1
	end
	if water_body.waterAreaData.ToCalculate then
		waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	end
	if updateBudget then
		updateBudget.budget = updateBudget.budget - search_amount
	end
	return waterbodies.checkIfScanningIsFinished(water_body), water_body
end

function waterbodies.getScanningAlarmEnabled(player_idx)
	return settings.get_player_settings(game.players[player_idx])["Alarms-Continuing-Search"].value
end

function waterbodies.signalScanningAlarmToPlayer(water_body, force, player_idx)
	if waterbodies.getScanningAlarmEnabled(player_idx) then
		force.players[player_idx].print(string.format("Still Scanning FluidArea %s", water_body.waterBodyId))
	end
end

function waterbodies.signalFinishedScanningToPlayer(water_body, force, player_idx)
	force.players[player_idx].print(string.format("%s created, with %sL of water with regen %sL.", water_body.waterBodyName, comma_value(water_body.waterAreaData.AmountWtr), water_body.waterAreaData.RegenAmount))
end

function waterbodies.signalPerPlayer(water_body, signal_func)
	local water_body_forces = water_body.entitiesData.forces
	for force_name, v in pairs(water_body_forces) do
		if v then
			for player_idx, _ in pairs(game.forces[force_name].players) do
				signal_func(water_body, game.forces[force_name], player_idx)
			end
		end
	end
end


function waterbodies.scanningLoopPeriodic(water_body)
	water_body.searchData.LoopCount = water_body.searchData.LoopCount + 1

	if water_body.searchData.LoopCount == 20 then
		waterbodies.signalPerPlayer(water_body, waterbodies.signalScanningAlarmToPlayer)
		water_body.searchData.LoopCount = 0
	end
end

function waterbodies.checkIfScanningIsFinished(water_body)
	return water_body.searchData.searchQueue:is_empty()
end

function waterbodies.duringScanning(water_body)
	if waterbodies.checkIfScanningIsFinished(water_body) then
		waterbodies.finishedScanning(water_body)
		return
	end
	waterbodies.scanningLoopPeriodic(water_body)
end

function waterbodies.scanningLoop(water_body_id, updateBudget)
	local water_body = waterbodies.getWaterBody(water_body_id)
	if water_body and water_body.valid then
		if not water_body.searchData.finished then
			local finished, water_body = waterbodies.ScanWaterArea(water_body, waterbodies.getAdditionalScanAmount(), updateBudget)
			water_body_id = water_body.waterBodyId
			waterbodies.duringScanning(water_body)
			if water_body.waterAreaData.ToCalculate then
				waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
			end
		elseif water_body.waterAreaData.ToCalculate then
			waterbodies.finishedScanning(water_body)
		end
	end
	return water_body_id
end

function waterbodies.finishedScanning(water_body)
	waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	water_body.searchData.finished = true
	waterbodies.signalPerPlayer(water_body, waterbodies.signalFinishedScanningToPlayer)

end

function waterbodies.initCleanedWaterBody(water_body)
	return {
		["PercentageWaterUsed"] = waterbodies.calculatePercentageWaterUsed(water_body),
		["valid"] = false,
		["waterBodyId"] = water_body.waterBodyId,
		["surfaceId"] = water_body.surfaceId,
	}
end

function waterbodies.markWaterBodyForCleanup(waterBody)
    waterBody.valid = false
    
    -- Clean up tile assignments to this water body
    -- waterbodies.cleanupWaterBodyTiles(waterBody)

	entities.deactivateWaterBodyPumps(waterBody.waterBodyId)

    -- Remove most data from water body (garbage collection)
    storage.WaterBodies[waterBody.waterBodyId] = waterbodies.initCleanedWaterBody(waterBody)
	storage.ValidWaterBodies[waterBody.waterBodyId] = nil
	forces.RemoveWaterbodyFromAllForces(waterBody.surfaceId, waterBody.waterBodyId)
end

function waterbodies.cleanupWaterBodyTiles(waterBody)
    local surfaceId = waterBody.surfaceId
    
    -- Remove tile assignments for this water body
    for gridKey, _ in pairs(waterBody.gridsData.waterGridWithData) do
        if waterbodies.getWaterTile(gridKey, surfaceId) == waterBody.waterBodyId then
            waterbodies.addNewWaterTile(gridKey, surfaceId, -1)
        end
    end
end

function waterbodies.getActivePumpCount(waterBody)
    local count = 0
    for _, pump_data in pairs(waterBody.entitiesData.pumps) do
        if pump_data.active == 1 and pump_data.entity.valid then
            count = count + 1
        end
    end
    return count
end

function waterbodies.calculateTotalWaterUsed(waterbody)
	local total_water_used = waterbody.waterBodyStateData.WaterUsed + waterbody.waterBodyStateData.WaterUsedPenalty
	return total_water_used
end

function waterbodies.calculatePercentageWaterUsed(waterbody)
	local total_water_used = waterbodies.calculateTotalWaterUsed(waterbody)
	local total_water_available = waterbody.waterAreaData.AmountWtr
	if total_water_available == 0 then return 100 end
	return (total_water_used / total_water_available) * 100
end

function waterbodies.calculateFocusPoint(waterBody)
    local shapeData = waterBody.waterBodyShapeData
    local centerX = (shapeData.MinX + shapeData.MaxX) / 2
    local centerY = (shapeData.MinY + shapeData.MaxY) / 2

    local pumpCount = 0
	local totalX, totalY = 0, 0
    for _, pump in pairs(waterBody.entitiesData.pumps) do
        totalX = totalX + pump.input_position.x
        totalY = totalY + pump.input_position.y
        pumpCount = pumpCount + 1
    end

    if pumpCount == 0 then
        return { x = centerX, y = centerY } -- Default to water body center if no pumps
    end

    local pumpCenterX = totalX / pumpCount
    local pumpCenterY = totalY / pumpCount

    local vectorX = centerX - pumpCenterX
    local vectorY = centerY - pumpCenterY

    -- The focus point is "opposite" the pump center relative to the water body center
    return { x = centerX + vectorX, y = centerY + vectorY }
end

function waterbodies.getCandidateTilesForVisualUpdate(waterBody, findDryTiles)
    local candidateTiles = {}
    local gridData = waterBody.gridsData.waterGridWithData

    if findDryTiles then
        for _, tileData in pairs(gridData) do
            if utils.DryWaterTiles[tileData.name] then
                candidateTiles[#candidateTiles + 1] = tileData
            end
        end
    else
        for _, tileData in pairs(gridData) do
            if utils.IsWaterTile(tileData.name) then
                candidateTiles[#candidateTiles + 1] = tileData
            end
        end
    end
    return candidateTiles
end

function waterbodies.sortTilesByDistance(tiles, focusPoint, sortAscending)
    table.sort(tiles, function(a, b)
        local distA = (a.position.x - focusPoint.x)^2 + (a.position.y - focusPoint.y)^2
        local distB = (b.position.x - focusPoint.x)^2 + (b.position.y - focusPoint.y)^2
        if sortAscending then
            return distA < distB
        else
            return distA > distB
        end
    end)
end

function waterbodies.restoreAllVisuals(waterBody, updateBudget)
    local state = waterBody.waterBodyStateData
    if not state or state.BTF == 0 then return end

    local dryTiles = waterbodies.getCandidateTilesForVisualUpdate(waterBody, true, updateBudget)
    if #dryTiles == 0 then
        state.BTF = 0
        return
    end

    local tilesToChange = {}
    for _, tileData in pairs(dryTiles) do
        tilesToChange[#tilesToChange + 1] = { name = tileData.originalName, position = tileData.position }
        tileData.name = tileData.originalName
    end

    if #tilesToChange > 0 then
        local surface = utils.GetSurface(waterBody.surfaceId)
        surface.set_tiles(tilesToChange, false)
    end

    state.BTF = 0
end


function waterbodies.updateGradualDepletionAppearance(waterBody, percentUsed, updateBudget)
    local state = waterBody.waterBodyStateData
    local totalTiles = waterBody.waterAreaData.TotalArea
    local targetChangedTiles = math.floor(totalTiles * ((percentUsed - 80) / 20))
    local tilesToProcessCount = targetChangedTiles - state.BTF

    if tilesToProcessCount == 0 then return end

    local isDepleting = tilesToProcessCount > 0
    local candidateTiles = waterbodies.getCandidateTilesForVisualUpdate(waterBody, not isDepleting, updateBudget)

    if #candidateTiles == 0 then return end

    local focusPoint = waterbodies.calculateFocusPoint(waterBody)
    waterbodies.sortTilesByDistance(candidateTiles, focusPoint, not isDepleting) -- Sort ascending for restoring, descending for depleting

    local tilesToChange = {}
    local numToProcess = math.min(math.abs(tilesToProcessCount), #candidateTiles)
	local processedCount = 0

    for i = 1, numToProcess do
        local tileData = candidateTiles[i]
        if isDepleting then
            local dryTileName = utils.getDryTileForWetTile(tileData.originalName)
            if dryTileName then
                tilesToChange[#tilesToChange + 1] = { name = dryTileName, position = tileData.position }
                tileData.name = dryTileName
            end
        else -- Restoring
            tilesToChange[#tilesToChange + 1] = { name = tileData.originalName, position = tileData.position }
            tileData.name = tileData.originalName
        end
		processedCount = processedCount + 1
    end

    if isDepleting then
        state.BTF = state.BTF + processedCount
    else
        state.BTF = state.BTF - processedCount
    end

    if #tilesToChange > 0 then
        local surface = utils.GetSurface(waterBody.surfaceId)
        surface.set_tiles(tilesToChange, false) -- Pass false to prevent script_raised_set_tiles event
    end
end

function waterbodies.updateDepletionAppearance(waterBody, updateBudget)
    local state = waterBody.waterBodyStateData
    local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)

    if percentUsed < 80 then
        if state.BTF > 0 then
            waterbodies.restoreAllVisuals(waterBody, updateBudget)
        end
    else
        waterbodies.updateGradualDepletionAppearance(waterBody, percentUsed, updateBudget)
    end
end

function waterbodies.handleDepletionAlarms(waterBody, percentUsed)
    local state = waterBody.waterBodyStateData

    -- Handle depletion state
    if percentUsed >= 100 and not state.Depleted then
        state.Depleted = true
        for forceName, _ in pairs(waterBody.entitiesData.forces) do
            game.forces[forceName].print(string.format("%s has been depleted.", waterBody.waterBodyName or "Water body"))
        end
    elseif percentUsed < 100 and state.Depleted then
        state.Depleted = false
    end

    -- Handle alarms
    if not state.Depleted then
        local alarms = {
            {50, "Fired50"}, {75, "Fired75"}, {90, "Fired90"}, 
            {95, "Fired95"}, {97, "Fired97"}, {98, "Fired98"}, {99, "Fired99"}
        }
        for _, alarm in ipairs(alarms) do
            local threshold, flag = table.unpack(alarm)
            if percentUsed >= threshold and not state[flag] then
                for forceName, _ in pairs(waterBody.entitiesData.forces) do
                    game.forces[forceName].print(string.format("%s has used %.0f%% of available water.", waterBody.waterBodyName or "Water body", percentUsed))
                end
                state[flag] = true
            elseif percentUsed < threshold and state[flag] then
                state[flag] = false -- Reset flag if level drops below threshold
            end
        end
    end
end

function waterbodies.updateWaterLevel(waterBody, waterUsedChange, regenAmount)
	local state = waterBody.waterBodyStateData
	state.WaterUsedPrev = state.WaterUsed
	-- Do not clamp water used to be within bounds - the bound violations should be still handled by depletion
	-- and they might be present to be made up for by the natural regeneration or drainage, etc.
	-- we will only limit natural regeneration not to occur if it would go below 0
	state.WaterUsed = state.WaterUsed + waterUsedChange
	local regen = regenAmount or 0
	regen = math.max(0, math.min(regen, state.WaterUsed)) -- this ensures that regen is not greater than the water used and positive
	state.WaterUsed = state.WaterUsed - regen


	local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)
    waterbodies.handleDepletionAlarms(waterBody, percentUsed)
end

function waterbodies.createMapMarker(waterBody)
	local mapMarker = waterBody.mapMarker
	if mapMarker then
		mapMarker.destroy()
	end
	-- TODO: Implement
end

function waterbodies.calculateWaterUsage(waterBody)
	-- Way1: implement estimation of the water usa on the tick stats
	-- Way2: get production stats from the pump prototypes appropriate for each force - impossible actually
	
	-- local forces = waterBody.entitiesData.forces

	-- for forceName, _ in pairs(forces) do
	-- 	local game_force = forces.getGameForce(forceName)
	-- 	local force_waterbody_id = forces.AddWaterbodyIfNotExists(forceName, waterBody.surfaceId, waterBody.waterBodyId).waterbody_force_id
	-- 	local prototype_name = entities.getActivePumpNameForForceWaterbodyId(force_waterbody_id)
	-- 	local fluid_production_statistics = game_force.get_fluid_production_statistics(waterBody.surfaceId)
	-- 	local water_production_stats = fluid_production_statistics.get_flow_count{name="water", category="input", precision_index=0, sample_index=300, count=true}
	-- end
	
	return 0
end

function waterbodies.calculateEffectiveRegenAmount(waterBody)
	-- Placeholder for regen calculation
	return waterBody.waterAreaData.RegenAmount or 0
end

function waterbodies.getWaterUsageStatsForPump(pump)
	-- TODO: Implement
	return 0
end

function waterbodies.collectWaterUsageStatsForWaterBody(waterBodyId)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if not waterBody or not waterBody.valid then return end
	local total_pumping_water = 0
	for _, pump in pairs(waterBody.entitiesData.pumps) do
		local pumpUsage = waterbodies.getWaterUsageStatsForPump(pump)
		total_pumping_water = total_pumping_water + pumpUsage
	end
	return total_pumping_water
end

function waterbodies.updateWaterUsageTickStats(waterbody, loop_tick, waterbody_total_pumping_water)
	if loop_tick == 0 then
		waterbody.waterUsageTickStats = waterbodies.initWaterUsageTickStats()
	end
	if not waterbody.waterUsageTickStats then
		waterbody.waterUsageTickStats = waterbodies.initWaterUsageTickStats()
	end
	waterbody.waterUsageTickStats[loop_tick + 1] = waterbody_total_pumping_water
end

function waterbodies.collectWaterUsageStats(loop_tick)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        local waterbody_total_pumping_water = waterbodies.collectWaterUsageStatsForWaterBody(id)
		local waterbody = waterbodies.getWaterBody(id)
		waterbodies.updateWaterUsageTickStats(waterbody, loop_tick, waterbody_total_pumping_water)
    end
end

function waterbodies.updateWaterBody(waterBodyId, updateBudget)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if not waterBody or not waterBody.valid then return end
	waterbodies.scanningLoop(waterBodyId, updateBudget)
	local waterUsedChange = waterbodies.calculateWaterUsage(waterBody) 
	local regen = waterbodies.calculateEffectiveRegenAmount(waterBody) --includes bonuses
	waterbodies.updateWaterLevel(waterBody, waterUsedChange, regen)
	waterbodies.updateDepletionAppearance(waterBody, updateBudget)
	waterbodies.createMapMarker(waterBody)
end

function waterbodies.updateWaterBodies(updateBudget)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        waterbodies.updateWaterBody(id, updateBudget)
    end
end
