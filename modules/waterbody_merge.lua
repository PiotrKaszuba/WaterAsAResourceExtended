require("modules.waterbodies")
require("modules.utils")
require("modules.hot_utils")
require("modules.entities")
require("modules.split_families")

waterbody_merge = {}



-- MERGE Functionality Below
function waterbody_merge.merge_tables(table_result, table_other)
    for k, v in pairs(table_other) do
        table_result[k] = v
    end	
end

function waterbody_merge.mergeSearchData(searchData, other_searchData)
	utils.LazyTables.on_merge(searchData.lazySearchQueue, other_searchData.searchQueue, other_searchData.lazySearchQueue)
	other_searchData.searchQueue = {}
	other_searchData.lazySearchQueue = {}

	searchData.totalArea = searchData.totalArea + other_searchData.totalArea
	searchData.finished = waterbodies.checkIfScanningIsFinished(searchData)

	searchData.ScanWeight = math.min(1.0, searchData.ScanWeight + other_searchData.ScanWeight)
end

function waterbody_merge.mergeGridsData(gridsData, other_gridsData, sourceWaterBodyId, targetWaterBodyId)
	utils.LazyTables.on_merge(gridsData.lazyWaterGridWithData, other_gridsData.waterGridWithData, other_gridsData.lazyWaterGridWithData)
	utils.LazyTables.on_merge(gridsData.lazyEdgeGrid, other_gridsData.edgeGrid, other_gridsData.lazyEdgeGrid)
	utils.LazyTables.on_merge(gridsData.lazyDriedTilesGridWithData, other_gridsData.driedTilesGridWithData, other_gridsData.lazyDriedTilesGridWithData)
	
	utils.LazyTables.on_merge(gridsData.lazyDriedStack, other_gridsData.driedStack, other_gridsData.lazyDriedStack)
	
	-- oldBinset, newBinset, pendingTiles stay the same - no need to merge them
	-- pendingTiles will be in callbacks of grids ..WithData lazy tables merging
	-- binsets will be slowly built up by the ongoing work loops
	
	-- dry tiles won't become orphaned because they are inherited by the target water body
	-- let's remove data from the other water body
	other_gridsData.waterGridWithData = {}
	other_gridsData.lazyWaterGridWithData = {}
	other_gridsData.edgeGrid = {}
	other_gridsData.lazyEdgeGrid = {}
	other_gridsData.driedTilesGridWithData = {}
	other_gridsData.lazyDriedTilesGridWithData = {}
	other_gridsData.driedStack = {}
	other_gridsData.lazyDriedStack = {}
	other_gridsData.oldBinset = {}
	other_gridsData.newBinset = {}
	other_gridsData.pendingTiles = {}

end

function waterbody_merge.mergeShapeData(shapeData, other_shapeData)
	waterbodies.updateGeometry(shapeData, other_shapeData)
end

function waterbody_merge.mergeWaterBodyTileCountData(tileCountData, other_tileCountData)
	for k, v in pairs(tileCountData) do
		tileCountData[k] = v + (other_tileCountData[k] or 0)
	end
end

function waterbody_merge.mergeWaterBodyStateData(waterBodyStateData, other_waterBodyStateData, waterBodyId)
	for _, pump_data in ipairs(other_waterBodyStateData.Pumps) do
		entities.addPumpToWaterBody(waterBodyId, pump_data)
	end
	
	waterbody_merge.merge_tables(waterBodyStateData.Forces, other_waterBodyStateData.Forces)

	other_waterBodyStateData.Pumps = {}
	other_waterBodyStateData.Forces = {}

	waterBodyStateData.WaterUsed = waterBodyStateData.WaterUsed + other_waterBodyStateData.WaterUsed
	waterBodyStateData.WaterUsedPrev = waterBodyStateData.WaterUsedPrev + other_waterBodyStateData.WaterUsedPrev

	waterBodyStateData.TempAvailableWater = waterBodyStateData.TempAvailableWater + other_waterBodyStateData.TempAvailableWater
	waterBodyStateData.TempUsedWater = waterBodyStateData.TempUsedWater + other_waterBodyStateData.TempUsedWater

	waterBodyStateData.WaterUsedPenalty = waterBodyStateData.WaterUsedPenalty + other_waterBodyStateData.WaterUsedPenalty
	waterBodyStateData.WaterUsedPenaltyRestored = waterBodyStateData.WaterUsedPenaltyRestored + other_waterBodyStateData.WaterUsedPenaltyRestored

	waterBodyStateData.TempInactive = waterBodyStateData.TempInactive and other_waterBodyStateData.TempInactive
	waterBodyStateData.Depleted = waterBodyStateData.Depleted and other_waterBodyStateData.Depleted

	-- only take flags of messages from the target water body
	waterBodyStateData.Fired50 = waterBodyStateData.Fired50
	waterBodyStateData.Fired75 = waterBodyStateData.Fired75
	waterBodyStateData.Fired90 = waterBodyStateData.Fired90
	waterBodyStateData.Fired95 = waterBodyStateData.Fired95
	waterBodyStateData.Fired97 = waterBodyStateData.Fired97
	waterBodyStateData.Fired98 = waterBodyStateData.Fired98
	waterBodyStateData.Fired99 = waterBodyStateData.Fired99

	waterBodyStateData.FiredCreated = waterBodyStateData.FiredCreated

	waterBodyStateData.DriedTiles = waterBodyStateData.DriedTiles + other_waterBodyStateData.DriedTiles
	-- let's remove dry tiles count from the other water body - so orphaned dry tiles won't trigger on waterbody removal
	other_waterBodyStateData.DriedTiles = 0
	
	waterBodyStateData.ScanLoopCount = waterBodyStateData.ScanLoopCount
	waterBodyStateData.OrphanedSecondsCount = waterBodyStateData.OrphanedSecondsCount + other_waterBodyStateData.OrphanedSecondsCount

    waterbodies.destroyMapMarkers(waterBodyStateData)
    waterbodies.destroyMapMarkers(other_waterBodyStateData)
	
    waterBodyStateData.MapMarkers = {}

end

function waterbody_merge.signalWaterBodyMergedToPlayer(waterBody, force, other_waterBody)
	return string.format("%s merged %s. Merged water body has %sL of water with regen %sL and total area of %s tiles.", waterbodies.getFullNameForWaterBody(waterBody), waterbodies.getFullNameForWaterBody(other_waterBody), utils.comma_value(waterBody.waterAreaData.AmountWtr), waterBody.waterAreaData.RegenAmount, waterBody.waterAreaData.TotalArea)
end

function waterbody_merge.mergeWaterBody(waterBody1, waterBody2)
	-- returns the merged water body
	-- the other one has to be deleted from the storage

	
	if not waterBody1.valid or not waterBody2.valid then
		utils.profile_hits("waterbody_merge.mergeWaterBody", "invalid waterbody")
		game.print("Error: Water bodies are not valid")
		
		return waterBody1
	end

	-- check if the water bodies are on the same surface
	if waterBody1.surface.name ~= waterBody2.surface.name then
		utils.profile_hits("waterbody_merge.mergeWaterBody", "different surfaces")
		game.print("Error: Water bodies are on different surfaces")
		return waterBody1
	end
	

	-- bigger water body absorbs the smaller one
    if waterBody1.searchData.totalArea < waterBody2.searchData.totalArea then
		waterBody1, waterBody2 = waterBody2, waterBody1
	end

	-- waterBody2 is merged into waterBody1

    -- Decide name to keep based on merge_priority first
    local name_to_keep = waterBody1.waterBodyName
    if waterBody2.merge_priority > waterBody1.merge_priority and waterBody2.waterBodyName ~= nil then
        name_to_keep = waterBody2.waterBodyName
    end

    waterbody_merge.mergeGridsData(waterBody1.gridsData, waterBody2.gridsData, waterBody1.waterBodyId, waterBody2.waterBodyId)
	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountData, waterBody2.waterBodyTileCountData)
	waterbody_merge.mergeSearchData(waterBody1.searchData, waterBody2.searchData)
	waterbody_merge.mergeWaterBodyStateData(waterBody1.waterBodyStateData, waterBody2.waterBodyStateData, waterBody1.waterBodyId)

	waterbody_merge.mergeShapeData(waterBody1.waterBodyShapeData, waterBody2.waterBodyShapeData)
	
	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountPercentagePenalty, waterBody2.waterBodyTileCountPercentagePenalty)

    -- there is no merge for WaterAreaData - it will be re-calculated totally based on other merged data
	
	waterBody1.waterBodyStateData.ToCalculate = true
	waterBody1.waterBodyStateData.ToUpdate = false -- no need to update after merge - there is dedicated signal for that
    -- preserve name and merge_priority
    if name_to_keep ~= nil then
        waterBody1.waterBodyName = name_to_keep
    end
    waterBody1.merge_priority = math.max(waterBody1.merge_priority, waterBody2.merge_priority)
    waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody1)
	waterbodies.signalPerForce(waterBody1, waterbody_merge.signalWaterBodyMergedToPlayer, waterBody2)

    local removedId = waterBody2.waterBodyId
	local keepId = waterBody1.waterBodyId
	local removeRef = storage.WaterBodyRef[removedId]
	local keepRef = storage.WaterBodyRef[keepId]
	removeRef[1] = keepId  -- flip loser ref to winner id - instantly give ownership of WaterTiles to the winner
	-- record backlink, in case we need to change ownership of WaterTiles before all refs are updated
	keepRef[2][removedId] = removeRef
	-- propagate any refs that pointed to the loser to now point to the winner - these are the refs that pointed to the loser
	for id, ref in pairs(removeRef[2]) do
		ref[1] = keepId  -- these are the refs that pointed to the loser - take them with the loser
		keepRef[2][id] = ref  -- these are the backlinks loser had - take them with the loser
	end
	removeRef[2] = {}  -- loser has no backlinks anymore
	
	-- sum up tile counts and remove loser from the table as it hits '0'
	local waterBodyToNumTiles = storage.WaterBodyToNumTiles
	waterBodyToNumTiles[keepId] = (waterBodyToNumTiles[keepId] or 0) + (waterBodyToNumTiles[removedId] or 0)
	waterBodyToNumTiles[removedId] = nil

	
    waterbodies.removeWaterBody(waterBody2)
    if removedId then
        split_families.on_merged(waterBody1.waterBodyId, removedId, waterBody1.waterBodyId)
    end

	table.insert(storage.RecycledWaterBodyIds, removedId)
	
	return waterBody1.waterBodyId
end

function waterbody_merge.mergeMultipleWaterBodies(waterBodyIds, triggerPosition, surface)
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(triggerPosition, surface)
	triggerPosition = tile.position

    if #waterBodyIds < 2 then return end
    
	-- assume all water bodies are present and valid
    local targetWaterBody = nil
    local targetWaterBodyId = nil
    for i = 1, #waterBodyIds do
		-- if all is OK first iteration should set targetWaterBodyId
		-- and the rest will do merge
		if targetWaterBodyId == nil then
			targetWaterBody = waterbodies.getWaterBody(waterBodyIds[i])
			if targetWaterBody and targetWaterBody.valid then
				targetWaterBodyId = targetWaterBody.waterBodyId
			end
		else
			local otherWaterBody = waterbodies.getWaterBody(waterBodyIds[i])
			if otherWaterBody and otherWaterBody.valid then
				-- Merge currentBody into target, or vice versa; result is the surviving water body ID
				targetWaterBodyId = waterbody_merge.mergeWaterBody(targetWaterBody, otherWaterBody)
				targetWaterBody = waterbodies.getWaterBody(targetWaterBodyId)
			end
		end
    end
	-- assuming target waterBody shuold be valid
    utils.Queue.enqueue(targetWaterBody.searchData.searchQueue, triggerPosition)
    targetWaterBody.searchData.finished = false
	targetWaterBody.waterBodyStateData.ToCalculate = true
	targetWaterBody.waterBodyStateData.ToUpdate = true
	-- also remove the tile from edge grid
	local gridsData = targetWaterBody.gridsData
	utils.LazyTables.remove(hot_utils.GridKey(triggerPosition), gridsData.edgeGrid, gridsData.lazyEdgeGrid)

	return targetWaterBody.waterBodyId
end
