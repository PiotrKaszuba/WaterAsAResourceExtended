require("modules.utils")
require("modules.hot_utils")
require("modules.waterbodies")
require("modules.waterbody_merge")
require("modules.split_families")

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
    return utils.normalize_update_values_per_second(settings.global["FluidArea-Additional-Tiles-Per-Second"].value, true, storage.PeriodicTicksPerScanningUpdate)
end

-- not a hot path - not periodic - used in tile events (currently only in landfills)
-- could be treated as somewhat hot if we wanted to very quickly process tile events
-- but not a priority - looks fine as is
function waterbody_scan.getAdjacentWaterAndLandTiles(position, surface, water_body_id, skip_water_tiles_current_state)
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(position, surface)
	position = tile.position
	
	-- if water_body_id is given then only return adjacent water tiles that are part of the water body
	-- if skip_water_tiles_current_state is true then treat adjacent tiles that have id == water_body_id as water tiles
	local adjacent_waterbody_tiles = {}
	local adjacent_land_tiles = {}
	for _, offset in pairs(utils.AdjacentOffsets) do
		local adj_pos = {x = position.x + offset.x, y = position.y + offset.y}
		local adj_gridKey = hot_utils.GridKey(adj_pos)
		local adj_waterBodyId = waterbodies.getWaterTile(adj_gridKey, surface)
		local is_water_tile = utils.IsWaterOrDryTile(utils.GetTile(adj_pos, surface).name)
		if (water_body_id == nil or adj_waterBodyId == water_body_id) and (is_water_tile or (skip_water_tiles_current_state and adj_waterBodyId == water_body_id)) then
			adjacent_waterbody_tiles[#adjacent_waterbody_tiles + 1] = adj_pos
		elseif not is_water_tile then
			adjacent_land_tiles[#adjacent_land_tiles + 1] = adj_pos
		end
	end
	return adjacent_waterbody_tiles, adjacent_land_tiles
end

-- not a hot path: same as waterbody_scan.getAdjacentWaterAndLandTiles
function waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surface, updateBudget)
	local adjacent_waterbody_tiles, adjacent_land_tiles = waterbody_scan.getAdjacentWaterAndLandTiles(position, surface, waterBody.waterBodyId)
    
	-- remove from edge grid - all adjacent land tiles
	for _, pos in pairs(adjacent_land_tiles) do
		local gridsData = waterBody.gridsData
		utils.LazyTables.remove(hot_utils.GridKey(pos), gridsData.edgeGrid, gridsData.lazyEdgeGrid)
	end
	local surfaceName = surface.name
	-- rebuild edges using EdgePattern
	for _, pos in pairs(adjacent_waterbody_tiles) do
		-- this has to be completed even if budget is 0
		if updateBudget then
			updateBudget.budget = updateBudget.budget - 1
		end
		waterbody_scan.EdgePattern(pos, surface, surfaceName, waterBody, false, false)
	end
end

-- hot path - from waterbody_scan.processWaterTile
-- Hot-path: Expand the scan queue around a tile by discovering adjacent water/dry tiles and marking land edges.
-- Signature has a fast-path mode to avoid repeated table lookups in tight loops:
-- - If extra_args_passed == false:
--     The function will eagerly bind all hot references (IDs, queues, grids, helpers) from modules and tables.
--     This is convenient but does table indexing on every call.
-- - If extra_args_passed == true:
--     All aux arguments must be provided (pre-bound locals for: tile, waterBodyId, searchQueue, edgeGrid, lazyEdgeGrid,
--     GetTile, GridKey, getWaterTile, IsWaterOrDryTile, enqueue, addNewWaterTile).
--     This avoids repeated table indexing in inner loops and is faster.
-- In both modes:
-- - searchPositionFixed == true indicates searchPosition is already the tile's left-top corner.
function waterbody_scan.EdgePattern(
		searchPosition,
		surface,
		surfaceName,
		waterBody,
		searchPositionFixed,
		extra_args_passed, -- this is boolean - if false extra args have to be created

		tile,

		waterBodyId,
		searchQueue,
		edgeGrid,
		lazyEdgeGrid,

		GetTile,
		GridKey,
		getWaterTile,
		IsWaterOrDryTile,
		enqueue,
		addNewWaterTile,
		tileInvalidOrOutOfMap,
		out_of_map_tile_name

	)
	
	if not extra_args_passed then
		waterBodyId = waterBody.waterBodyId
		searchQueue = waterBody.searchData.searchQueue
		local gridsData = waterBody.gridsData
		edgeGrid = gridsData.edgeGrid
		lazyEdgeGrid = gridsData.lazyEdgeGrid

		GetTile = function(pos) return surface.get_tile(pos) end
		tile = GetTile(searchPosition)
		GridKey = hot_utils.GridKey
		getWaterTile = hot_utils.getWaterTile
		IsWaterOrDryTile = utils.IsWaterOrDryTile
		enqueue = utils.Queue.enqueue
		addNewWaterTile = hot_utils.addNewWaterTile
		tileInvalidOrOutOfMap = waterbody_scan.tileInvalidOrOutOfMap
		out_of_map_tile_name = "out-of-map"
	end

	if not searchPositionFixed then
	-- for profiling only - if code hits inner line then it requires left-top corner fix
		if not utils.checkIfPositionIsLeftTopCorner(searchPosition) then
			utils.profile_hits("waterbody_scan.EdgePattern", "checkIfPositionIsLeftTopCorner")
		end
		-- fix position to left-top corner in case it was not
		searchPosition = tile.position
	end

    for _, offset in pairs(utils.AdjacentOffsets) do
		-- this position must already be left-top corner
        local position = {x = searchPosition.x + offset.x, y = searchPosition.y + offset.y}
        
		-- is part of this waterbody or its edge
		local tile = GetTile(position)
		local gridKey = GridKey(position)
		local tileWaterBodyId = getWaterTile(gridKey, surfaceName)

        local already_searched = tileWaterBodyId == waterBodyId or utils.LazyTables.get(gridKey, edgeGrid, lazyEdgeGrid) ~= nil
        if (not already_searched) then
			if not tile.valid then
				tileInvalidOrOutOfMap(surface, position, true, searchQueue, enqueue, "waterbody_scan.EdgePattern")
				goto continue
			end
	
			-- tile.name is available only if tile is valid (otherwise an error is raised)
			local tile_name = tile.name
	
			if tile_name == out_of_map_tile_name then
				tileInvalidOrOutOfMap(surface, position, false, searchQueue, enqueue, "waterbody_scan.EdgePattern")
				goto continue
			end
			
			local is_water_or_dry_tile = IsWaterOrDryTile(tile.name)
			if is_water_or_dry_tile then
				enqueue(searchQueue, position)
			else
				if tileWaterBodyId == nil then
					addNewWaterTile(gridKey, surfaceName, -1)
				elseif tileWaterBodyId == waterBodyId then
					utils.profile_hits("waterbody_scan.EdgePattern", "got non water tile of the same waterbody!")
					game.print("Testing: EdgePattern got non water tile of the same waterbody!")
				elseif tileWaterBodyId ~= -1 then
					local tileWaterBody = waterbodies.getWaterBody(tileWaterBodyId)
					if tileWaterBody then
						if tileWaterBody.valid then
							utils.profile_hits("waterbody_scan.EdgePattern", "got non water tile of ANOTHER waterbody! IT IS VALID!")
							game.print("Testing: EdgePattern got non water tile of ANOTHER waterbody! IT IS VALID!")
						else
							utils.profile_hits("waterbody_scan.EdgePattern", "got non water tile of ANOTHER waterbody! IT IS INVALID!")
							game.print("Testing: EdgePattern got non water tile of ANOTHER waterbody! IT IS INVALID!")
						end
					else
						utils.profile_hits("waterbody_scan.EdgePattern", "got non water tile of ANOTHER waterbody! NO WATERBODY REFERENCE!")
						game.print("Testing: EdgePattern got non water tile of ANOTHER waterbody! NO WATERBODY REFERENCE!")
					end
					-- fix stale ref
					addNewWaterTile(gridKey, surfaceName, -1)
				end
				edgeGrid[gridKey] = true
			end
        end
		::continue::
    end   
end

-- hot path - from waterbody_scan.ScanWaterArea
-- Hot-path: Assign a single tile to a water body or merge bodies if conflict; enqueue neighbors via EdgePattern.
-- Two execution modes for performance:
-- - If extra_args_passed == false:
--     The function binds all needed tables/functions (queues, grids, helpers) from globals/water_body/surface.
-- - If extra_args_passed == true:
--     Callers must supply all pre-bound locals (IDs, grids, queue, helpers) to minimize table indexing.
-- Return values (always 5 to keep caller simple and branchless):
--   1) water_body            -- (possibly changed) water body reference
--   2) added_tile            -- boolean: true if a new tile was actually added to this body
--   3) total_area_increase   -- integer 0/1: amount to add to searchData.totalArea
--   4) dried_tiles_increase  -- integer 0/1: amount to add to state.DriedTiles
--   5) waterbody_changed     -- boolean: true if a merge occurred and the current water body reference changed
function waterbody_scan.processWaterTile(
		water_body,
		position,
		tile,
		tile_name,
		surface,
		surfaceName,
		extra_args_passed, -- this is boolean - if false extra args have to be created
		
		waterBodyId,
		gridsData,
		waterGridWithData,
		lazyWaterGridWithData,
		driedTilesGridWithData,
		lazyDriedTilesGridWithData,
		searchQueue,
		edgeGrid,
		lazyEdgeGrid,
		driedStack,
		pendingTiles,

		GridKey,
		waterBodyTileCountData,
		waterBodyTileCountPercentagePenalty,

		IsDryTile,
		IsWaterTile,
		getWaterTile,
		addNewWaterTile,
		mergeWaterBody,
		ValidWaterBodies,
		OrphanedDryTilesOriginalName,
		lazyOrphanedDryTilesOriginalName,
		WaterTileToWaterBodyTileType,
		getWaterTilePercentageWaterUsed,
		getWaterBody,
		addTileToWaterGrid,
		EdgePattern,
		GetTile,
		IsWaterOrDryTile,
		enqueue,
		deduplicate_enqueue,
		tileInvalidOrOutOfMap,

		gridKey,
		tile_waterBodyId,
		out_of_map_tile_name

	)

	if not extra_args_passed then
		
		waterBodyId = water_body.waterBodyId
		gridsData = water_body.gridsData
		waterGridWithData = gridsData.waterGridWithData
		lazyWaterGridWithData = gridsData.lazyWaterGridWithData
		driedTilesGridWithData = gridsData.driedTilesGridWithData
		lazyDriedTilesGridWithData = gridsData.lazyDriedTilesGridWithData
		searchQueue = water_body.searchData.searchQueue
		edgeGrid = gridsData.edgeGrid
		lazyEdgeGrid = gridsData.lazyEdgeGrid
		driedStack = gridsData.driedStack
		pendingTiles = gridsData.pendingTiles

		waterBodyTileCountData = water_body.waterBodyTileCountData
		waterBodyTileCountPercentagePenalty = water_body.waterBodyTileCountPercentagePenalty

		GridKey = hot_utils.GridKey
		IsDryTile = utils.IsDryTile
		IsWaterTile = utils.IsWaterTile
		getWaterTile = hot_utils.getWaterTile
		addNewWaterTile = hot_utils.addNewWaterTile
		mergeWaterBody = waterbody_merge.mergeWaterBody
		ValidWaterBodies = storage.ValidWaterBodies
		OrphanedDryTilesOriginalName = storage.OrphanedDryTilesOriginalName
		lazyOrphanedDryTilesOriginalName = storage.lazyOrphanedDryTilesOriginalName
		WaterTileToWaterBodyTileType = waterbodies.WaterTileToWaterBodyTileType
		getWaterTilePercentageWaterUsed = hot_utils.getWaterTilePercentageWaterUsed
		getWaterBody = waterbodies.getWaterBody
		addTileToWaterGrid = waterbodies.addTileToWaterGrid
		EdgePattern = waterbody_scan.EdgePattern
		GetTile = function(pos) return surface.get_tile(pos) end
		IsWaterOrDryTile = utils.IsWaterOrDryTile
		enqueue = utils.Queue.enqueue
		deduplicate_enqueue = utils.Queue.deduplicate_enqueue
		tileInvalidOrOutOfMap = waterbody_scan.tileInvalidOrOutOfMap
		gridKey = GridKey(position)
		tile_waterBodyId = getWaterTile(gridKey, surfaceName)
		out_of_map_tile_name = "out-of-map"
	end

	local original_tile_name = tile_name
	local is_dry_tile = IsDryTile(tile_name)
	local is_water_tile = IsWaterTile(tile_name)
    local added_tile = false
	local total_area_increase, dried_tiles_increase, waterbody_changed = 0, 0, false
	local is_tile_assigned_to_water_body = ValidWaterBodies[tile_waterBodyId] ~= nil

	if not (is_water_tile or is_dry_tile) then
		-- not a water (or dry) tile - it could have been added to search queue
		-- when a tile wasn't generated yet through EdgePattern
		if is_tile_assigned_to_water_body then
			utils.profile_hits("processWaterTile", "non water or dry tile that is assigned to a water body")
			game.print("Warning: processWaterTile got non water or dry tile that is assigned to a water body!")
		end
		-- Non-water tile - mark as searched without adding to water body and skip
		addNewWaterTile(gridKey, surfaceName, -1)
		-- no tile was added to the processed water body
		return water_body, false, 0, 0, false
	end
	
	if is_dry_tile then
		original_tile_name = utils.LazyTables.get(gridKey, OrphanedDryTilesOriginalName[surfaceName], lazyOrphanedDryTilesOriginalName[surfaceName])
		if original_tile_name == nil then
			utils.profile_hits("processWaterTile", "Orphaned dry tile is not in the table!")
			game.print("Testing: Orphaned dry tile is not in the table!")
		end
	end
	
    local waterBodyTileType = WaterTileToWaterBodyTileType[original_tile_name]
	if waterBodyTileType ~= nil then
		-- inherit depletion level from the original waterbody (if any) BEFORE assignment as it will remove possibility to read it
		local tile_percentage_water_used = getWaterTilePercentageWaterUsed(gridKey, surfaceName)
		local new_water_body_id = waterBodyId
		-- assignTileToWaterBody
		if not is_tile_assigned_to_water_body then
			addNewWaterTile(gridKey, surfaceName, waterBodyId)
		elseif tile_waterBodyId ~= waterBodyId then
			-- tile is already assigned to a different water body
			-- we have to merge the two water bodies
			-- it will return the new water body id from the merge
			new_water_body_id = mergeWaterBody(getWaterBody(tile_waterBodyId), water_body)

		end
		-- end of assignTileToWaterBody

		if new_water_body_id ~= waterBodyId then
			water_body = getWaterBody(new_water_body_id)
			waterbody_changed = true
		else
			-- add tile to the water body internal data structures
			-- it is an else block after merge check
			-- because if merge happened this tile was already in the other water body
			-- and is now incorporated into the current water body by merge
			if not hot_utils.isTileInGrid(waterGridWithData, lazyWaterGridWithData, driedTilesGridWithData, lazyDriedTilesGridWithData, gridKey) then
				waterBodyTileCountData[waterBodyTileType] = waterBodyTileCountData[waterBodyTileType] + 1
				waterBodyTileCountPercentagePenalty[waterBodyTileType] = waterBodyTileCountPercentagePenalty[waterBodyTileType] + tile_percentage_water_used
			
				total_area_increase = 1
				added_tile = true
				
				if is_dry_tile then
					addTileToWaterGrid(driedTilesGridWithData, gridKey, tile_name, position, original_tile_name)
					dried_tiles_increase = 1
					utils.LazyTables.remove(gridKey, OrphanedDryTilesOriginalName[surfaceName], lazyOrphanedDryTilesOriginalName[surfaceName])
					deduplicate_enqueue(driedStack, gridKey)
				else
					addTileToWaterGrid(waterGridWithData, gridKey, tile_name, position, original_tile_name)
					deduplicate_enqueue(pendingTiles, gridKey)
				end
			end
		end
		-- Check for edge pattern and add adjacent tiles to search queue
		EdgePattern(position, surface, surfaceName, water_body, false,
			true, -- extra_args_passed
			tile,
			waterBodyId, searchQueue, edgeGrid, lazyEdgeGrid,
			GetTile, GridKey, getWaterTile, IsWaterOrDryTile, enqueue, addNewWaterTile, tileInvalidOrOutOfMap, out_of_map_tile_name
			
		)
    end

	return water_body, added_tile, total_area_increase, dried_tiles_increase, waterbody_changed
end

-- not a hot path - only called from events currently (landfills - waterbody split - new wb creation + scan)
function waterbody_scan.continueScanWaterArea(water_body_id, scan_amount, updateBudget)
	local water_body = waterbodies.getWaterBody(water_body_id)
	if not (water_body and water_body.valid) then
		utils.profile_hits("waterbody_scan.continueScanWaterArea", "water_body invalid before scan")
		-- game.print("Error: Water body invalid in continueScanWaterArea (before scan)")
		return nil
	end
    local finished, water_body = waterbody_scan.ScanWaterArea(water_body, scan_amount, updateBudget)
	if not (water_body and water_body.valid) then
		utils.profile_hits("waterbody_scan.continueScanWaterArea", "water_body invalid after scan")
		game.print("Error: Water body invalid in continueScanWaterArea (after scan)")
		return nil
	end
	return water_body.waterBodyId
end

-- not a hot path - same as waterbody_scan.continueScanWaterArea() and also on Pump built event
function waterbody_scan.beginScanWaterArea(water_body_id, start_position, scan_amount, updateBudget)
	local scan_amount = scan_amount or waterbody_scan.getInitialScanAmount()
	local water_body = waterbodies.getWaterBody(water_body_id)
	if not (water_body and water_body.valid) then
		utils.profile_hits("waterbody_scan.beginScanWaterArea", "water_body nil or invalid before scan")
		-- game.print("Error: Water body nil or invalid in beginScanWaterArea (before scan)")
		return nil
	end
	local search_queue = water_body.searchData.searchQueue
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(start_position, water_body.surface)
	start_position = tile.position
	utils.Queue.enqueue(search_queue, start_position)
	local finished, water_body = waterbody_scan.ScanWaterArea(water_body, scan_amount, updateBudget)
    if not (water_body and water_body.valid) then
		utils.profile_hits("waterbody_scan.beginScanWaterArea", "water_body invalid after scan")
		game.print("Error: Water body invalid in beginScanWaterArea (after scan)")
		return nil
	end
	return water_body.waterBodyId
end

-- returns true if the tile needs to be dropped, false if if not (was re-enqueued)
function waterbody_scan.tileInvalidOrOutOfMap(surface, search_position, invalid, search_queue, enqueue, caller_name)
	local case_name = invalid and "tile invalid" or "tile out of map"
	utils.profile_hits(caller_name, case_name)
	
	local chunk_position = {x=search_position.x/32, y=search_position.y/32}
	local is_chunk_generated = surface.is_chunk_generated(chunk_position)

	if not is_chunk_generated then
		if invalid then surface.request_to_generate_chunks(search_position, 1) end
		-- do not block waiting for the chunk to be generated, instead:
		-- re-enqueue the position to be processed again
		enqueue(search_queue, search_position)
		return false
	else
		case_name = invalid and "tile invalid but chunk is generated" or "tile out of map but chunk is generated"
		utils.profile_hits(caller_name, case_name)
	end
	return true
end
-- hot path begins in while loop inside
-- 
-- Scan water area starting from a position and build tile data
-- Returns: true if scan is complete, false if it is continuing
function waterbody_scan.ScanWaterArea(water_body, search_amount, updateBudget)
	local surface = water_body.surface
	local surfaceName = surface.name
	local max_water_body_size = waterbodies.getMaxWaterBodySize()
	
	local original_search_amount = search_amount
	if updateBudget then
		search_amount = math.min(search_amount, updateBudget.budget)
		original_search_amount = search_amount
	end

	-- function
	local is_empty = utils.Queue.is_empty
	local dequeue_with_lazy_arrays = utils.Queue.dequeue_with_lazy_arrays
	local enqueue = utils.Queue.enqueue
	local deduplicate_enqueue = utils.Queue.deduplicate_enqueue
	local GridKey = hot_utils.GridKey
	local getWaterTile = hot_utils.getWaterTile
	local processWaterTile = waterbody_scan.processWaterTile
	local checkIfPositionIsLeftTopCorner = utils.checkIfPositionIsLeftTopCorner
	local GetTile = function(pos) return surface.get_tile(pos) end
	local IsDryTile = utils.IsDryTile
	local IsWaterTile = utils.IsWaterTile
	local addNewWaterTile = hot_utils.addNewWaterTile
	local mergeWaterBody = waterbody_merge.mergeWaterBody
	local ValidWaterBodies = storage.ValidWaterBodies
	local OrphanedDryTilesOriginalName = storage.OrphanedDryTilesOriginalName
	local lazyOrphanedDryTilesOriginalName = storage.lazyOrphanedDryTilesOriginalName
	local WaterTileToWaterBodyTileType = waterbodies.WaterTileToWaterBodyTileType
	local getWaterTilePercentageWaterUsed = hot_utils.getWaterTilePercentageWaterUsed
	local getWaterBody = waterbodies.getWaterBody
	local addTileToWaterGrid = waterbodies.addTileToWaterGrid
	local EdgePattern = waterbody_scan.EdgePattern
	local IsWaterOrDryTile = utils.IsWaterOrDryTile
	local fixPositionToLeftTopCorner = utils.fixPositionToLeftTopCorner
	local lazy_tables_get = utils.LazyTables.get
	local tileInvalidOrOutOfMap = waterbody_scan.tileInvalidOrOutOfMap

	-- local variables
	local search_position, tile, gridKey, tile_waterBodyId, already_searched, added_tile, waterbody_changed, total_area_increase, dried_tiles_increase = nil, nil, nil, nil, false, false, false, 0, 0
	-- waterbody data - have to be updated in case of waterbody change
	local waterbody_id = water_body.waterBodyId
	local gridsData = water_body.gridsData
	local edgeGrid = gridsData.edgeGrid
	local lazyEdgeGrid = gridsData.lazyEdgeGrid
	local waterGridWithData = gridsData.waterGridWithData
	local lazyWaterGridWithData = gridsData.lazyWaterGridWithData
	local driedTilesGridWithData = gridsData.driedTilesGridWithData
	local lazyDriedTilesGridWithData = gridsData.lazyDriedTilesGridWithData
	local driedStack = gridsData.driedStack
	local pendingTiles = gridsData.pendingTiles
	local searchData = water_body.searchData
	local totalArea = searchData.totalArea
	
	local search_queue = searchData.searchQueue
	local lazy_search_queue = searchData.lazySearchQueue
	local state = water_body.waterBodyStateData
	local dried_tiles = state.DriedTiles
	local waterBodyTileCountData = water_body.waterBodyTileCountData
	local waterBodyTileCountPercentagePenalty = water_body.waterBodyTileCountPercentagePenalty
	--
	local huge_val = math.huge
    local batchMinX, batchMaxX, batchMinY, batchMaxY, batchSumX, batchSumY, batchTileCount = huge_val, -huge_val, huge_val, -huge_val, 0, 0, 0
	
	local out_of_map_tile_name = "out-of-map"

	state.ToCalculate = true

	while not is_empty(search_queue) and search_amount > 0 do
		search_amount = search_amount - 1
		search_position = dequeue_with_lazy_arrays(search_queue, lazy_search_queue)
		-- check if position is left-top corner
		if not checkIfPositionIsLeftTopCorner(search_position) then
			utils.profile_hits("waterbody_scan.ScanWaterArea", "checkIfPositionIsLeftTopCorner")
		end
		-- fix position to left-top corner in case it was not
		search_position = fixPositionToLeftTopCorner(search_position)

		tile = GetTile(search_position)

		if not tile.valid then
			local dropped_tile = tileInvalidOrOutOfMap(surface, search_position, true, search_queue, enqueue, "waterbody_scan.ScanWaterArea")
			if dropped_tile then goto continue end
			break
		end

		-- tile.name is available only if tile is valid (otherwise an error is raised)
		local tile_name = tile.name

		if tile_name == out_of_map_tile_name then
			local dropped_tile = tileInvalidOrOutOfMap(surface, search_position, false, search_queue, enqueue, "waterbody_scan.ScanWaterArea")
			if dropped_tile then goto continue end
			break
		end
		
		gridKey = GridKey(search_position)

		tile_waterBodyId = getWaterTile(gridKey, surfaceName)
		-- already searched means that the tile is part of this waterbody or its edge
		already_searched = tile_waterBodyId == waterbody_id or lazy_tables_get(gridKey, edgeGrid, lazyEdgeGrid) ~= nil
        
		if not already_searched then
            if totalArea <= max_water_body_size then
                water_body, added_tile, total_area_increase, dried_tiles_increase, waterbody_changed = processWaterTile(
					water_body, search_position, tile, tile_name, surface, surfaceName, true,
					waterbody_id, gridsData, waterGridWithData, lazyWaterGridWithData, driedTilesGridWithData, lazyDriedTilesGridWithData,
					search_queue, edgeGrid, lazyEdgeGrid, driedStack, pendingTiles,
					
					GridKey, waterBodyTileCountData, waterBodyTileCountPercentagePenalty,
					IsDryTile, IsWaterTile, getWaterTile, addNewWaterTile, mergeWaterBody,
					ValidWaterBodies, OrphanedDryTilesOriginalName, lazyOrphanedDryTilesOriginalName, WaterTileToWaterBodyTileType,
					getWaterTilePercentageWaterUsed,
					getWaterBody, addTileToWaterGrid, EdgePattern,
					GetTile, IsWaterOrDryTile, enqueue, deduplicate_enqueue, tileInvalidOrOutOfMap,

					gridKey, tile_waterBodyId, out_of_map_tile_name
					)
				if waterbody_changed then
					waterbody_id = water_body.waterBodyId
					gridsData = water_body.gridsData
					edgeGrid = gridsData.edgeGrid
					lazyEdgeGrid = gridsData.lazyEdgeGrid
					waterGridWithData = gridsData.waterGridWithData
					lazyWaterGridWithData = gridsData.lazyWaterGridWithData
					driedTilesGridWithData = gridsData.driedTilesGridWithData
					lazyDriedTilesGridWithData = gridsData.lazyDriedTilesGridWithData
					driedStack = gridsData.driedStack
					pendingTiles = gridsData.pendingTiles
					searchData = water_body.searchData
					totalArea = searchData.totalArea
					search_queue = searchData.searchQueue
					lazy_search_queue = searchData.lazySearchQueue
					state = water_body.waterBodyStateData
					dried_tiles = state.DriedTiles
					waterBodyTileCountData = water_body.waterBodyTileCountData
					waterBodyTileCountPercentagePenalty = water_body.waterBodyTileCountPercentagePenalty
				end
				totalArea = totalArea + total_area_increase
				dried_tiles = dried_tiles + dried_tiles_increase
				-- TODO - should we reset batch values if waterbody changed?
				-- the question is how merge will behave under the hood
                if added_tile then
					-- this is hardcoded in place for performance
                    local x, y = search_position.x, search_position.y
                    batchMinX = math.min(batchMinX, x)
                    batchMaxX = math.max(batchMaxX, x)
                    batchMinY = math.min(batchMinY, y)
                    batchMaxY = math.max(batchMaxY, y)
                    batchSumX = batchSumX + x
                    batchSumY = batchSumY + y
                    batchTileCount = batchTileCount + 1
                end
            end
        end
		::continue::
	end
	
	if updateBudget then
        updateBudget.budget = updateBudget.budget - original_search_amount + search_amount
	end
	-- final updates
	if batchTileCount > 0 then
		waterbodies.updateGeometry(water_body.waterBodyShapeData, nil,
			batchMinX, batchMaxX,
			batchMinY, batchMaxY,
			batchSumX, batchSumY, batchTileCount)
	end
    searchData.totalArea = totalArea
	state.DriedTiles = dried_tiles
	
	return waterbodies.checkIfScanningIsFinished(searchData), water_body
end

function waterbody_scan.signalScanningAlarmToPlayer(water_body)
	return string.format("Still Scanning FluidArea %s", water_body.waterBodyId)
end

function waterbody_scan.signalFinishedScanningToPlayer(water_body)
	local msg_type = water_body.waterBodyStateData.FiredCreated and "updated" or "created"
	return string.format("%s %s, with %sL of water with regen %sL and total area of %s tiles.", waterbodies.getFullNameForWaterBody(water_body), msg_type, utils.comma_value(water_body.waterAreaData.AmountWtr), water_body.waterAreaData.RegenAmount, water_body.waterAreaData.TotalArea)
end


function waterbody_scan.getScanningLoopPeriod()
        return settings.global["FluidArea-Scanning-Loop-Period"].value
end

function waterbody_scan.scanningLoopPeriodic(water_body)
	water_body.waterBodyStateData.ScanLoopCount = water_body.waterBodyStateData.ScanLoopCount + utils.normalize_update_values_per_second(1, false, storage.PeriodicTicksPerScanningUpdate)

	if water_body.waterBodyStateData.ScanLoopCount >= waterbody_scan.getScanningLoopPeriod() then
		waterbodies.signalPerForce(water_body, waterbody_scan.signalScanningAlarmToPlayer)
		water_body.waterBodyStateData.ScanLoopCount = 0
	end
end


function waterbody_scan.signalCreatedOrUpdated(water_body)
	local state = water_body.waterBodyStateData
	if (not state.FiredCreated) or (state.ToUpdate and settings.global["Alarms-Tile-Message"].value) then
		waterbodies.signalPerForce(water_body, waterbody_scan.signalFinishedScanningToPlayer)
		state.FiredCreated = true
		state.ToUpdate = false
	end
end

function waterbody_scan.finishedScanning(water_body)
	waterbodies.CalculateAndUpdateWaterBodyAreaData(water_body)
	local search_data = water_body.searchData
	search_data.finished = true
	search_data.ScanWeight = 1.0 -- reset to default value
	if (not water_body.waterBodyStateData.FiredCreated) then
		waterbodies.GenerateWaterBodyName(water_body)
	end
	waterbody_scan.signalCreatedOrUpdated(water_body)
	
    split_families.on_scan_finished(water_body.waterBodyId)
end

function waterbody_scan.prepareDistributedBudgetUpdateForValidWaterBodies(total_work_amount, updateBudget, condition_func, initial_work_weight)
	if updateBudget and updateBudget.budget <= 0 then
		return nil, nil
	end
    local validWaterBodies = waterbodies.getValidWaterBodies()
	local sum_work_weights = initial_work_weight or 0 -- some waterbodies could have priority to be worked on more
    -- Copy to an array because scanning can invalidate water bodies during iteration
    local working_waterbodies_array = {}
    for _, waterBody in pairs(validWaterBodies) do
		if condition_func(waterBody) then
			working_waterbodies_array[#working_waterbodies_array + 1] = waterBody
			sum_work_weights = sum_work_weights + waterBody.searchData.ScanWeight
		end
    end
	-- distribute computation load over scanned waterbodies
	if sum_work_weights <= 0 then
		return nil, nil
	end
	local work_amount_per_waterbody_weight = math.min(total_work_amount, updateBudget.budget) / sum_work_weights
	return working_waterbodies_array, work_amount_per_waterbody_weight
end

function waterbody_scan.prepareUpdateConditionFunc(waterBody)
	local search_data = waterBody.searchData
	return not search_data.finished
end

-- Iterate scanning over all valid water bodies. This is intended to be called
-- by a separate periodic scanning loop, independent from the big update.
function waterbody_scan.scanningUpdateAll(updateBudget)
	local working_waterbodies_array, work_amount_per_waterbody_weight = waterbody_scan.prepareDistributedBudgetUpdateForValidWaterBodies(waterbody_scan.getAdditionalScanAmount(), updateBudget, waterbody_scan.prepareUpdateConditionFunc)
	
	if working_waterbodies_array == nil or work_amount_per_waterbody_weight == nil then
		return
	end
	
    for _, waterBody in ipairs(working_waterbodies_array) do
		local search_data = waterBody.searchData
		-- repeat checks in case it changed during iteration
        if waterBody.valid and not search_data.finished then
			local scan_amount = math.ceil(search_data.ScanWeight * work_amount_per_waterbody_weight)
			local finished, waterBody = waterbody_scan.ScanWaterArea(waterBody, scan_amount, updateBudget)
			if finished then
				waterbody_scan.finishedScanning(waterBody)
			else
				waterbody_scan.scanningLoopPeriodic(waterBody)
			end
        end
        if updateBudget and updateBudget.budget <= 0 then
            break
        end
    end
end