require("utils")
require("waterbodies")
require("waterbody_scan")
require("waterbody_split")
require("waterbody_logic")

tiles = {}

function tiles.initTileEventQueue()
    if storage.TileEventQueue == nil then
        storage.TileEventQueue = utils.Queue:new()
    end
end

function tiles.getTileEventQueue()
    return storage.TileEventQueue
end

tiles.waterfill_placer_to_water_tile = {
    ["waterfill-placer"] = "water-shallow",
    ["waterfill-placer-deep"] = "deepwater"
}



function tiles.placerWater(placed)

    local replacement = tiles.waterfill_placer_to_water_tile[placed.name]

    local pos     = placed.position
    local surface = placed.surface

    placed.destroy()
    local tileArray = {}
    local i = 1
	tileArray[i] = {
		name = replacement,
		position = {pos.x, pos.y}
	}
   
    surface.set_tiles(tileArray, true, true, true, true)
end


function tiles.initTileEvent(eventType, position, surfaceId, tileData)
	return {
		type = eventType, -- "landfill" or "waterfill"
		position = position,
		surfaceId = surfaceId,
		tileData = tileData
	}
end

function tiles.addTileEvent(eventType, position, surfaceId, tileData)
    storage.TileEventQueue:enqueue(tiles.initTileEvent(eventType, position, surfaceId, tileData))
end

function tiles.processTileEventQueue(maxEvents, updateBudget)
	local queue = tiles.getTileEventQueue()
    local processedCount = 0
    
    while not queue:is_empty() and processedCount < maxEvents and updateBudget.budget > 0 do
        local event = queue:dequeue()
        
        if event.type == "landfill" then
            tiles.processLandfillEvent(event, updateBudget)
        elseif event.type == "waterfill" then
            tiles.processWaterfillEvent(event, updateBudget)
        end
        
        processedCount = processedCount + 1
    end
    
    return processedCount
end

function tiles.handleTileEventsInternal(tiles, surfaceIndex)
    if not tiles or not surfaceIndex then return end
    
    for _, tile_event in pairs(tiles) do
        local position = tile_event.position
        local old_name = tile_event.old_tile and tile_event.old_tile.name
        local new_name = tile_event.name
        
        if new_name == "landfill" and old_name and utils.IsWaterTile(old_name) then
            tiles.addTileEvent("landfill", position, surfaceIndex, {
                originalTileName = old_name,
				tileName = new_name,
            })
        elseif utils.IsWaterTile(new_name) and old_name and not utils.IsWaterTile(old_name) then
            tiles.addTileEvent("waterfill", position, surfaceIndex, {
				originalTileName = old_name,
                tileName = new_name,
            })
        end
    end
end

function tiles.processWaterfillEvent(tileEvent, updateBudget)
    local position = tileEvent.position
    local surfaceId = tileEvent.surfaceId
    local tileName = tileEvent.tileData.tileName
    
	if updateBudget then
		updateBudget.budget = updateBudget.budget - 1
	end

    -- Find adjacent water bodies
    local adjacentWaterBodies = tiles.findAdjacentWaterBodies(position, surfaceId)
    
    if #adjacentWaterBodies == 0 then
        -- Create new water body and start scanning
        local waterBody = waterbodies.createNewWaterBody(surfaceId)
        local new_water_body_id = waterbody_scan.beginScanWaterArea(waterBody.waterBodyId, position, 1, updateBudget)
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

    else
        -- Multiple water bodies - merge them
        local new_water_body_id = waterbody_logic.mergeMultipleWaterBodies(adjacentWaterBodies, position, surfaceId)
		if new_water_body_id ~= waterBody.waterBodyId then
			waterBody = waterbodies.getWaterBody(new_water_body_id)
		end
		if updateBudget then
			updateBudget.budget = updateBudget.budget - #adjacentWaterBodies
		end
    end
end

function tiles.findAdjacentWaterBodies(position, surfaceId)
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


function tiles.reduceTileFromWaterBody(waterBody, originalTileName, position, surfaceId, updateBudget)
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
    waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surfaceId, updateBudget)
    
    -- 5. Mark for water amount recalculation
    waterBody.waterAreaData.ToCalculate = true
    
    -- 6. Check if water body becomes empty
    if waterbodies.isWaterBodyEmpty(waterBody) then
        waterbody_logic.disablePumpsAndRemoveWaterBody(waterBody)
    end
end


function tiles.processLandfillEvent(tileEvent, updateBudget)
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
            tiles.reduceTileFromWaterBody(waterBody, tileEvent.tileData.originalTileName, position, surfaceId, updateBudget)
        end
		if waterBody.valid then
			waterbody_split.checkIfWaterBodyGotSplit(waterBodyId, position, surfaceId, updateBudget)
		end
    end
end
