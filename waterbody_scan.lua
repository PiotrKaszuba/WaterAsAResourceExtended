require("utils")
require("waterbodies")
require("waterbody_logic")

waterbody_scan = {}

function waterbody_scan.getInitialScanAmount()
    return settings.global["FluidArea-Start-Area"].value
end

function waterbody_scan.getAdditionalScanAmount()
    return settings.global["FluidArea-Additional-Tiles-Per-Second"].value
end

function waterbody_scan.getSplitScanAmount()
	return settings.global["FluidArea-Split-Scan-Amount"].value
end

function waterbody_scan.getAdjacentWaterAndLandTiles(position, surfaceId, water_body_id)
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

function waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surfaceId, updateBudget)
	local adjacent_waterbody_tiles, adjacent_land_tiles = waterbody_scan.getAdjacentWaterAndLandTiles(position, surfaceId, waterBody.waterBodyId)
    
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
		waterbody_scan.EdgePattern(position, surfaceId, waterBody.searchData, true, true)
	end
end

function waterbody_scan.EdgePattern(searchPosition, surfaceId, searchData, force_edge_pattern, skip_water_tiles)
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

-- Process a single water tile during scanning (internal helper)
function waterbody_scan.processWaterTile(water_body, position, tile_name, surface_id)
	local gridKey = utils.PositionToString(position)

	if not utils.IsWaterTile(tile_name) and not waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surface_id) then
		-- Non-water tile - mark as searched without adding to water body and skip
		waterbodies.addNewWaterTile(gridKey, surface_id, -1)
		return water_body
	end
	
    local waterBodyTileType = waterbodies.WaterTileToWaterBodyTileType[tile_name]
	if waterBodyTileType ~= nil then
		local new_water_body_id = waterbody_logic.assignTileToWaterBody(gridKey, surface_id, water_body.waterBodyId)
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
		waterbody_scan.EdgePattern(position, surface_id, water_body.searchData)

		waterbodies.updateBoundingBox(water_body.waterBodyShapeData, position)

    end

	return water_body
end

function waterbody_scan.continueScanWaterArea(water_body_id, scan_amount)
	local water_body = waterbodies.getWaterBody(water_body_id)
	local finished, water_body = waterbodies.ScanWaterArea(water_body, scan_amount)
	return water_body.waterBodyId
end

function waterbody_scan.beginScanWaterArea(water_body_id, start_position, scan_amount, updateBudget)
	local scan_amount = scan_amount or waterbody_scan.getInitialScanAmount()
	local water_body = waterbodies.getWaterBody(water_body_id)
	if not (water_body and water_body.valid) then
		game.print("Error: Water body nil or invalid in beginScanWaterArea")
		return nil
	end
	local search_queue = water_body.searchData.searchQueue
	search_queue:enqueue(start_position)
	local finished, water_body = waterbodies.ScanWaterArea(water_body, scan_amount, updateBudget)
	return water_body.waterBodyId
end

-- Scan water area starting from a position and build tile data
-- Returns: true if scan is complete, false if it is continuing
function waterbody_scan.ScanWaterArea(water_body, search_amount, updateBudget)

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
				water_body = waterbody_scan.processWaterTile(water_body, search_position, tile_name, surface_id)
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
	return waterbody_scan.checkIfScanningIsFinished(water_body), water_body
end

function waterbody_scan.getScanningAlarmEnabled(player_idx)
	return settings.get_player_settings(game.players[player_idx])["Alarms-Continuing-Search"].value
end

function waterbody_scan.signalScanningAlarmToPlayer(water_body, force, player_idx)
	if waterbody_scan.getScanningAlarmEnabled(player_idx) then
		force.players[player_idx].print(string.format("Still Scanning FluidArea %s", water_body.waterBodyId))
	end
end

function waterbody_scan.signalFinishedScanningToPlayer(water_body, force, player_idx)
	force.players[player_idx].print(string.format("%s created, with %sL of water with regen %sL.", water_body.waterBodyName, comma_value(water_body.waterAreaData.AmountWtr), water_body.waterAreaData.RegenAmount))
end

function waterbody_scan.scanningLoopPeriodic(water_body)
	water_body.searchData.LoopCount = water_body.searchData.LoopCount + 1

	if water_body.searchData.LoopCount == 20 then
		waterbodies.signalPerPlayer(water_body, waterbody_scan.signalScanningAlarmToPlayer)
		water_body.searchData.LoopCount = 0
	end
end

function waterbody_scan.checkIfScanningIsFinished(water_body)
	return water_body.searchData.searchQueue:is_empty()
end

function waterbody_scan.duringScanning(water_body)
	if waterbody_scan.checkIfScanningIsFinished(water_body) then
		waterbody_scan.finishedScanning(water_body)
		return
	end
	waterbody_scan.scanningLoopPeriodic(water_body)
end

function waterbody_scan.scanningLoop(water_body_id, updateBudget)
	local water_body = waterbodies.getWaterBody(water_body_id)
	if water_body and water_body.valid then
		if not water_body.searchData.finished then
			local finished, water_body = waterbody_scan.ScanWaterArea(water_body, waterbody_scan.getAdditionalScanAmount(), updateBudget)
			water_body_id = water_body.waterBodyId
			waterbody_scan.duringScanning(water_body)
			if water_body.waterAreaData.ToCalculate then
				waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
			end
		elseif water_body.waterAreaData.ToCalculate then
			waterbody_scan.finishedScanning(water_body)
		end
	end
	return water_body_id
end

function waterbody_scan.finishedScanning(water_body)
	waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	water_body.searchData.finished = true
	waterbodies.signalPerPlayer(water_body, waterbody_scan.signalFinishedScanningToPlayer)

end