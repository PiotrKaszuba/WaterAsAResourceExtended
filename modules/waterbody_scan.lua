require("modules.utils")
require("modules.hot_utils")
require("modules.waterbodies")
require("modules.waterbody_merge")

waterbody_scan = {}

-- no need for hot_utils here -this is used rarely:
-- only on building pumps (for now - might have changed - double check if needed)
-- 
-- returns waterBodyId of existing or new water body
function waterbody_scan.createWaterBodyFromTileIfNotExists(position, surface)
	local surfaceName = surface.name
	waterbodies.initSurface(surfaceName)

	-- fix position to left-top corner - tested in profiler case
	local tile = utils.GetTile(position, surface)
	position = tile.position

    local gridKey = hot_utils.GridKey(position)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surface)

    if not waterbodies.checkIfWaterBodyIdBelongsToValid(waterBodyId) then
        local _, waterBodyId = waterbodies.createNewWaterBody(surface)
		-- scan can change waterBodyId if merge happened
		waterBodyId = waterbody_scan.beginScanWaterArea(waterBodyId, position)
        return waterBodyId, true
    end

    return waterBodyId, false
end

function waterbody_scan.getInitialScanAmount()
    return settings.global["FluidArea-Start-Area"].value
end

function waterbody_scan.getAdditionalScanAmount()
    return utils.normalize_values_per_second(settings.global["FluidArea-Additional-Tiles-Per-Second"].value, true)
end

-- not a hot path - not periodic - used in tile events (currently only in landfills)
-- could be treated as somewhat hot if we wanted to very quickly process tile events
-- but not a priority - looks fine as is
function waterbody_scan.getAdjacentWaterAndLandTiles(position, surface, water_body_id)
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(position, surface)
	position = tile.position
	
	-- if water_body_id is given then only return adjacent water tiles that are part of the water body
	local adjacent_waterbody_tiles = {}
	local adjacent_land_tiles = {}
	for _, offset in pairs(utils.AdjacentOffsets) do
		local adj_pos = {x = position.x + offset.x, y = position.y + offset.y}
		local adj_gridKey = hot_utils.GridKey(adj_pos)
		local adj_waterBodyId = waterbodies.getWaterTile(adj_gridKey, surface)
		local is_water_tile = utils.IsWaterOrDryTile(utils.GetTile(adj_pos, surface).name)
		if (water_body_id == nil or adj_waterBodyId == water_body_id) and is_water_tile then
			adjacent_waterbody_tiles[#adjacent_waterbody_tiles + 1] = adj_pos
		elseif not is_water_tile then
			adjacent_land_tiles[#adjacent_land_tiles + 1] = adj_pos
		end
	end
	return adjacent_waterbody_tiles, adjacent_land_tiles
end

-- not a hot path: same as waterbody_scan.getAdjacentWaterAndLandTiles()
function waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surface, updateBudget)
	local adjacent_waterbody_tiles, adjacent_land_tiles = waterbody_scan.getAdjacentWaterAndLandTiles(position, surface, waterBody.waterBodyId)
    
	-- remove from edge grid - all adjacent land tiles
	for _, pos in pairs(adjacent_land_tiles) do
		waterBody.gridsData.edgeGrid[hot_utils.GridKey(pos)] = nil
	end
	local surfaceName = surface.name
	-- rebuild edges using EdgePattern
	for _, pos in pairs(adjacent_waterbody_tiles) do
		-- this has to be completed even if budget is 0
		if updateBudget then
			updateBudget.budget = updateBudget.budget - 1
		end
		waterbody_scan.EdgePattern(pos, surface, surfaceName, waterBody)
	end
end

-- hot path - from waterbody_scan.processWaterTile()
function waterbody_scan.EdgePattern(searchPosition, surface, surfaceName, waterBody)
	-- for profiling only - if code hits inner line then it requires left-top corner fix
	if not utils.checkIfPositionIsLeftTopCorner(searchPosition) then
		utils.profile_hits("waterbody_scan.EdgePattern", "checkIfPositionIsLeftTopCorner")
	end

	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(searchPosition, surface)
	searchPosition = tile.position

	local edgeFound = false
    local searchData = waterBody.searchData
	local waterBodyId = waterBody.waterBodyId
	local edgeGrid = waterBody.gridsData.edgeGrid

    for _, offset in pairs(utils.AdjacentOffsets) do
		-- this position must already be left-top corner
        local position = {x = searchPosition.x + offset.x, y = searchPosition.y + offset.y}
        
		-- is part of this waterbody or its edge
		local tile = utils.GetTile(position, surface)
		local gridKey = hot_utils.GridKey(position)
		local tileWaterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)

        local already_searched = tileWaterBodyId == waterBodyId or edgeGrid[gridKey] ~= nil
        if (not already_searched) then
			local is_water_or_dry_tile = utils.IsWaterOrDryTile(tile.name)
			if is_water_or_dry_tile then
				utils.Queue.enqueue(searchData.searchQueue, position)
			else
				if tileWaterBodyId == nil then
					hot_utils.addNewWaterTile(gridKey, surfaceName, -1)
				elseif tileWaterBodyId == waterBodyId then
					game.print("Testing: EdgePattern got non water tile of the same waterbody!")
				elseif tileWaterBodyId ~= -1 then
					game.print("Testing: EdgePattern got non water tile of ANOTHER waterbody! IT shouldn't happen - investigate or fix the conditions around here.")

				end
				edgeGrid[gridKey] = true
				edgeFound = true
			end
        end
    end
    
    return edgeFound
end

-- hot path - from waterbody_scan.processWaterTile()
--
-- assign a tile to a water body
-- if the tile is already assigned to a different water body, we have to merge the two water bodies
function waterbody_scan.assignTileToWaterBody(gridKey, surfaceName, waterBodyId)
    local tile_waterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)
    if hot_utils.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceName) then
        hot_utils.addNewWaterTile(gridKey, surfaceName, waterBodyId)
    elseif tile_waterBodyId ~= waterBodyId then
        -- tile is already assigned to a different water body
        -- we have to merge the two water bodies
		-- it will return the new water body id from the merge
		return waterbody_merge.mergeWaterBody(waterbodies.getWaterBody(tile_waterBodyId), waterbodies.getWaterBody(waterBodyId))
    end
	return waterBodyId
end

-- hot path - from waterbody_scan.ScanWaterArea()
--
-- Process a single water tile during scanning (internal helper)
function waterbody_scan.processWaterTile(water_body, position, tile, surface, surfaceName)
	local gridKey = hot_utils.GridKey(position)
	local tile_name = tile.name
	local original_tile_name = tile_name
	local is_dry_tile = utils.IsDryTile(tile_name)
	local is_water_tile = utils.IsWaterTile(tile_name)
	if not (is_water_tile or is_dry_tile) and not hot_utils.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceName) then
		
		-- is this code alive?
		utils.profile_hits("processWaterTile", "does it happen?")
		game.print("Testing: IT DOES HAPPEN: processWaterTile got non water or dry tile that is not assigned to a water body!.")

		-- Non-water tile - mark as searched without adding to water body and skip
		hot_utils.addNewWaterTile(gridKey, surfaceName, -1)
		return water_body
	end
	
	if is_dry_tile then
		original_tile_name = storage.OrphanedDryTilesOriginalName[surfaceName][gridKey]
		if original_tile_name == nil then
			utils.profile_hits("processWaterTile", "Orphaned dry tile is not in the table!")
			game.print("Testing: Orphaned dry tile is not in the table!")
		end
	end
	
    local waterBodyTileType = waterbodies.WaterTileToWaterBodyTileType[original_tile_name]
	if waterBodyTileType ~= nil then
		local waterBodyId = water_body.waterBodyId
		-- inherit depletion level from the original waterbody (if any) BEFORE assignment as it will remove possibility to read it
		local tile_percentage_water_used = hot_utils.getWaterTilePercentageWaterUsed(gridKey, surfaceName)
		local new_water_body_id = waterbody_scan.assignTileToWaterBody(gridKey, surfaceName, waterBodyId)
		if new_water_body_id ~= water_body.waterBodyId then
			water_body = waterbodies.getWaterBody(new_water_body_id)
		else
			-- add tile to the water body internal data structures
			-- it is an else block after merge check
			-- because if merge happened this tile was already in the other water body
			-- and is now incorporated into the current water body by merge
			local waterGridWithData = water_body.gridsData.waterGridWithData
			if waterGridWithData[gridKey] == nil then
				local waterBodyTileCountData = water_body.waterBodyTileCountData
				waterBodyTileCountData[waterBodyTileType] = waterBodyTileCountData[waterBodyTileType] + 1
				
				local waterBodyTileCountPercentagePenalty = water_body.waterBodyTileCountPercentagePenalty
				waterBodyTileCountPercentagePenalty[waterBodyTileType] = waterBodyTileCountPercentagePenalty[waterBodyTileType] + tile_percentage_water_used
				
				local searchData = water_body.searchData
				searchData.totalArea = searchData.totalArea + 1
				waterbodies.addTileToWaterGrid(waterGridWithData, gridKey, tile_name, position, original_tile_name)
				
				if is_dry_tile then
					local state = water_body.waterBodyStateData
					state.DriedTiles = state.DriedTiles + 1
					storage.OrphanedDryTilesOriginalName[surfaceName][gridKey] = nil
				end
			end
		end
		-- Check for edge pattern and add adjacent tiles to search queue
		waterbody_scan.EdgePattern(position, surface, surfaceName, water_body)

		-- for now let it be unoptimized in hot path - this is not that bad as it looks
		waterbodies.updateBoundingBox(water_body.waterBodyShapeData, position)

    end

	return water_body
end

-- not a hot path - only called from events currently (landfills - waterbody split - new wb creation + scan)
function waterbody_scan.continueScanWaterArea(water_body_id, scan_amount)
	local water_body = waterbodies.getWaterBody(water_body_id)
	local finished, water_body = waterbody_scan.ScanWaterArea(water_body, scan_amount)
	return water_body.waterBodyId
end

-- not a hot path - same as waterbody_scan.continueScanWaterArea() and also on Pump built event
function waterbody_scan.beginScanWaterArea(water_body_id, start_position, scan_amount, updateBudget)
	local scan_amount = scan_amount or waterbody_scan.getInitialScanAmount()
	local water_body = waterbodies.getWaterBody(water_body_id)
	if not (water_body and water_body.valid) then
		game.print("Error: Water body nil or invalid in beginScanWaterArea")
		return nil
	end
	local search_queue = water_body.searchData.searchQueue
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(start_position, water_body.surface)
	start_position = tile.position
	utils.Queue.enqueue(search_queue, start_position)
	local finished, water_body = waterbody_scan.ScanWaterArea(water_body, scan_amount, updateBudget)
	return water_body.waterBodyId
end

-- hot path begins in while loop inside
-- 
-- Scan water area starting from a position and build tile data
-- Returns: true if scan is complete, false if it is continuing
function waterbody_scan.ScanWaterArea(water_body, search_amount, updateBudget)
	local surface = water_body.surface
	local water_body_max_area = waterbodies.getMaxWaterBodySize()
	
	local original_search_amount = search_amount
	if updateBudget then
		search_amount = math.min(search_amount, updateBudget.budget)
		original_search_amount = search_amount
	end

	water_body.waterAreaData.ToCalculate = true
	
	-- Process tiles from search queue
	-- hot path

	local surfaceName = water_body.surface.name
	local search_queue = water_body.searchData.searchQueue
	while not utils.Queue.is_empty(search_queue) and search_amount > 0 do
		local search_position = utils.Queue.dequeue(search_queue)
		-- check if position is left-top corner
		if not utils.checkIfPositionIsLeftTopCorner(search_position) then
			utils.profile_hits("waterbody_scan.ScanWaterArea", "checkIfPositionIsLeftTopCorner")
		end
		-- fix position to left-top corner in case it was not
		local tile = utils.GetTile(search_position, surface)
		search_position = tile.position
		local gridKey = hot_utils.GridKey(search_position)

		local tile_waterBodyId = hot_utils.getWaterTile(gridKey, surfaceName)
		-- already searched means that the tile is part of this waterbody or its edge
		local already_searched = tile_waterBodyId == water_body.waterBodyId or water_body.gridsData.edgeGrid[gridKey] ~= nil
		if not already_searched then
			if water_body.searchData.totalArea <= water_body_max_area then
				water_body = waterbody_scan.processWaterTile(water_body, search_position, tile, surface, surfaceName)
			end
		end
		search_amount = search_amount - 1
	end
	if water_body.waterAreaData.ToCalculate then
		waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	end
	if updateBudget then
		updateBudget.budget = updateBudget.budget - original_search_amount + search_amount
	end
	return waterbody_scan.checkIfScanningIsFinished(water_body), water_body
end

function waterbody_scan.signalScanningAlarmToPlayer(water_body)
	return string.format("Still Scanning FluidArea %s", water_body.waterBodyId)
end

function waterbody_scan.signalFinishedScanningToPlayer(water_body)
	local msg_type = water_body.waterBodyStateData.FiredCreated and "updated" or "created"
	return string.format("%s %s, with %sL of water with regen %sL and total area of %s tiles.", waterbodies.getFullNameForWaterBody(water_body), msg_type, utils.comma_value(water_body.waterAreaData.AmountWtr), water_body.waterAreaData.RegenAmount, water_body.waterAreaData.TotalArea)
end


function waterbody_scan.getScanningLoopPeriod()
	-- return settings.global["FluidArea-Scanning-Loop-Period"].value
	return 20
end

function waterbody_scan.scanningLoopPeriodic(water_body)
	water_body.waterBodyStateData.ScanLoopCount = water_body.waterBodyStateData.ScanLoopCount + utils.normalize_values_per_second(1)

	if water_body.waterBodyStateData.ScanLoopCount >= waterbody_scan.getScanningLoopPeriod() then
		waterbodies.signalPerForce(water_body, waterbody_scan.signalScanningAlarmToPlayer)
		water_body.waterBodyStateData.ScanLoopCount = 0
	end
end

function waterbody_scan.checkIfScanningIsFinished(water_body)
	return utils.Queue.is_empty(water_body.searchData.searchQueue)
end

function waterbody_scan.duringScanning(water_body)
	if waterbody_scan.checkIfScanningIsFinished(water_body) then
		waterbody_scan.finishedScanning(water_body)
		return
	end
	waterbody_scan.scanningLoopPeriodic(water_body)
end

function waterbody_scan.scanningLoop(water_body, updateBudget)
	if water_body and water_body.valid then
		if not water_body.searchData.finished then
			local finished, water_body = waterbody_scan.ScanWaterArea(water_body, waterbody_scan.getAdditionalScanAmount(), updateBudget)
			waterbody_scan.duringScanning(water_body)
			if water_body.waterAreaData.ToCalculate then
				waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
			end
		elseif water_body.waterAreaData.ToCalculate then
			waterbody_scan.finishedScanning(water_body)
		end
	end
	return water_body
end

function waterbody_scan.finishedScanning(water_body)
	waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	water_body.searchData.finished = true
	if (not water_body.waterBodyStateData.FiredCreated) then
		waterbodies.GenerateWaterBodyName(water_body)
	end
	if (not water_body.waterBodyStateData.FiredCreated) or settings.global["Alarms-Tile-Message"].value then
		waterbodies.signalPerForce(water_body, waterbody_scan.signalFinishedScanningToPlayer)
		water_body.waterBodyStateData.FiredCreated = true
	end
end