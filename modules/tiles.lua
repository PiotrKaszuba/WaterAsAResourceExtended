require("modules.utils")
require("modules.hot_utils")
require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.waterbody_split")
require("modules.entities")
require("modules.waterbody_merge")

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
    local pos_center     = placed.position
    local surface = placed.surface

    local old_tile = utils.GetTile(pos_center, surface)
    local old_tile_name = old_tile.name
    local pos = old_tile.position

    if utils.DryWaterTiles[old_tile_name] then
        utils.rejectEntityPlacement(placed, "Cannot place waterfill on dry (depleted) tile", "waterfill")
        return
    end

    local replacement = tiles.waterfill_placer_to_water_tile[placed.name]
    
    placed.destroy()
    local tileArray = {}
    local i = 1
	tileArray[i] = {
		name = replacement,
		position = {x=pos.x, y=pos.y},
        old_tile = {name = old_tile_name}
	}
   
    surface.set_tiles(tileArray, true, true, true, false)
    tiles.handleTileEventsInternal(
        tileArray,
        surface
    )

end


function tiles.initTileEvent(eventType, position, surface, tileData)
	return {
		type = eventType, -- "landfill" or "waterfill"
		position = position,
		surface = surface,
		tileData = tileData
	}
end

function tiles.addTileEvent(eventType, position, surface, tileData)
    -- assume position is left-top corner already
    storage.TileEventQueue:enqueue(tiles.initTileEvent(eventType, position, surface, tileData))
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

function tiles.handleTileEventsInternal(tileArray, surface, placed_name)
    if not tileArray or not surface then return end

    for _, tile_event in pairs(tileArray) do
        local position = tile_event.position
        -- try to fix the position to left-top corner just in case
        local current_tile = utils.GetTile(position, surface)
        position = current_tile.position

        local old_name = tile_event.old_tile and tile_event.old_tile.name
        local new_name = tile_event.name or placed_name
        
        if old_name == nil then
            game.print("Warning: script_raised_set_tiles with no old tile name. Problems may arise if landfill was placed not on water or waterfill was placed on water or dry (depleted) tile.")
        end

        if new_name == "landfill" and (old_name and utils.IsWaterTile(old_name)) or (not old_name) then
            tiles.addTileEvent("landfill", position, surface, {
                originalTileName = old_name,
				tileName = new_name,
            })
        elseif utils.IsWaterTile(new_name) and (old_name and not utils.IsWaterTile(old_name)) or (not old_name) then
            tiles.addTileEvent("waterfill", position, surface, {
				originalTileName = old_name,
                tileName = new_name,
            })
        end
    end
end

function tiles.processWaterfillEvent(tileEvent, updateBudget)
    local position = tileEvent.position
    local surface = tileEvent.surface
    
	if updateBudget then
		updateBudget.budget = updateBudget.budget - 1
	end

    -- Find adjacent water bodies
    local adjacentWaterBodies = tiles.findAdjacentWaterBodies(position, surface)
    
    -- if there are no adjacent water bodies - dont do anything

    if #adjacentWaterBodies == 1 then
        -- Extend existing water body
        local waterBodyId = adjacentWaterBodies[1]
        local waterBody = waterbodies.getWaterBody(waterBodyId)
        
        if waterBody then
            waterBody.searchData.searchQueue:enqueue(position)
            waterBody.searchData.finished = false
            waterBody.waterAreaData.ToCalculate = true
			-- also remove the tile from edge grid
			waterBody.gridsData.edgeGrid[hot_utils.GridKey(position)] = nil
        end

    elseif #adjacentWaterBodies > 1 then
        -- Multiple water bodies - merge them
        waterbody_merge.mergeMultipleWaterBodies(adjacentWaterBodies, position, surface)
		if updateBudget then
			updateBudget.budget = updateBudget.budget - #adjacentWaterBodies
		end
    end
end

function tiles.findAdjacentWaterBodies(position, surface)
    local waterBodyIds = {}
    local seen = {}
    
    for _, offset in pairs(utils.AdjacentOffsets) do
        local adj_pos = {x = position.x + offset.x, y = position.y + offset.y}
        local adj_gridKey = hot_utils.GridKey(adj_pos)
        local waterBodyId = waterbodies.getWaterTile(adj_gridKey, surface)
        
        if not waterbodies.checkIfTileIsNotAssignedToWaterBody(adj_gridKey, surface) and not seen[waterBodyId] then
            waterBodyIds[#waterBodyIds + 1] = waterBodyId
            seen[waterBodyId] = true
        end
    end
    
    return waterBodyIds
end


function tiles.reduceTileFromWaterBody(waterBody, originalTileName, position, surface, updateBudget)
    local tileType = waterbodies.WaterTileToWaterBodyTileType[originalTileName]
    if not tileType then return end

    local gridKey = hot_utils.GridKey(position)
    local surfaceName = surface.name

    -- 1. Reduce tile count that will be used for water amount calculation
    waterBody.waterBodyTileCountData[tileType] = 
        math.max(0, waterBody.waterBodyTileCountData[tileType] - 1)
    
    -- 2. Regenerate some water used based on current percentage use
    -- reverse penalty (overall it will decrease amount of reamining water due to AmountWtr decreasing more than water used)
    local currentPercentageUsed = waterbodies.calculatePercentageWaterUsed(waterBody)
    local toRegen = waterbodies.GetAmountWaterForWaterBodyTileType(tileType, true) * currentPercentageUsed / 100
    waterbody_update.updateWaterLevel(waterBody, 0, toRegen)

    -- 3. Remove from waterGrid
    waterbodies.removeTileFromWaterGrid(waterBody, gridKey)
    
    -- 4. Mark tile as unassigned in global registry
    hot_utils.addNewWaterTile(gridKey, surfaceName, -1)
    
    -- 5. Recalculate edges around this position
    waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surface, updateBudget)
    
    -- 6. Mark for water amount recalculation
    waterBody.waterAreaData.ToCalculate = true
    
    -- 7. Check if water body becomes empty
    if waterbodies.isWaterBodyEmpty(waterBody) then
        entities.disablePumpsAndRemoveWaterBody(waterBody)
    end
end


function tiles.processLandfillEvent(tileEvent, updateBudget)
    -- assume position is left-top corner already
	local position = tileEvent.position
	local surface = tileEvent.surface
    local gridKey = hot_utils.GridKey(position)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surface)
    
    if not waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surface) then
        local waterBody = waterbodies.getWaterBody(waterBodyId)
		if waterBody and waterBody.valid then
			if updateBudget then
				updateBudget.budget = updateBudget.budget - 2
			end
            tiles.reduceTileFromWaterBody(waterBody, tileEvent.tileData.originalTileName, position, surface, updateBudget)
        end
		if waterBody.valid then
			waterbody_split.checkIfWaterBodyGotSplit(waterBodyId, position, surface, updateBudget)
		end
    end
end
