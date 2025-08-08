require("modules.waterbodies")
require("modules.utils")
require("modules.hot_utils")
require("modules.entities")

waterbody_merge = {}



-- MERGE Functionality Below
function waterbody_merge.merge_tables(table_result, table_other)
    for k, v in pairs(table_other) do
        table_result[k] = v
    end	
end

function waterbody_merge.mergeSearchData(searchData, other_searchData, overlapTileCountData)
	utils.Queue.merge(searchData.searchQueue, other_searchData.searchQueue)
	
	local sum_overlap = 0
	for k, v in pairs(overlapTileCountData) do
		sum_overlap = sum_overlap + v
	end
	searchData.totalArea = searchData.totalArea + other_searchData.totalArea - sum_overlap
	searchData.finished = utils.Queue.is_empty(searchData.searchQueue)
end

function waterbody_merge.mergeGridsData(gridsData, other_gridsData, include_global_water_tiles, surface, targetWaterBodyId)
	local overlapTileCountData = waterbodies.initWaterBodyTileCountData()
	local surfaceName = surface.name
	for gridKey, tileData in pairs(other_gridsData.waterGridWithData) do

		-- check by the waterGrid if the tile is already in the current water body
		if gridsData.waterGridWithData[gridKey] == nil then
			-- this tile is not in the current water body - add it
			gridsData.waterGridWithData[gridKey] = tileData
		else
			local waterBodyTileType = waterbodies.WaterTileToWaterBodyTileType[tileData.originalName] -- uses originalName to avoid issue with partially dried waterbodies
			overlapTileCountData[waterBodyTileType] = overlapTileCountData[waterBodyTileType] + 1

		end

		-- if include_global_water_tiles is true -> transfer ownership of the tile to the current water body
		if include_global_water_tiles then
			hot_utils.addNewWaterTile(gridKey, surfaceName, targetWaterBodyId)
		end
	end

	-- dry tiles won't become orphaned because they are inherited by the target water body
	-- let's remove waterGridWithData from the other water body
	other_gridsData.waterGridWithData = {}

	waterbody_merge.merge_tables(gridsData.edgeGrid, other_gridsData.edgeGrid)

	return overlapTileCountData
end


function waterbody_merge.mergeShapeData(shapeData, other_shapeData)
	shapeData.MinX = math.min(shapeData.MinX, other_shapeData.MinX)
	shapeData.MaxX = math.max(shapeData.MaxX, other_shapeData.MaxX)
	shapeData.MinY = math.min(shapeData.MinY, other_shapeData.MinY)
	shapeData.MaxY = math.max(shapeData.MaxY, other_shapeData.MaxY)
	waterbodies.calculateDimensions(shapeData)
end

function waterbody_merge.mergeWaterBodyTileCountData(tileCountData, other_tileCountData, overlapTileCountData)
	for k, v in pairs(tileCountData) do
		tileCountData[k] = v + (other_tileCountData[k] or 0) - (overlapTileCountData[k] or 0)
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

	local overlapTileCountData = waterbody_merge.mergeGridsData(waterBody1.gridsData, waterBody2.gridsData, true, waterBody1.surface, waterBody1.waterBodyId)
	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountData, waterBody2.waterBodyTileCountData, overlapTileCountData)
	waterbody_merge.mergeSearchData(waterBody1.searchData, waterBody2.searchData, overlapTileCountData)
	waterbody_merge.mergeWaterBodyStateData(waterBody1.waterBodyStateData, waterBody2.waterBodyStateData, waterBody1.waterBodyId)

	waterbody_merge.mergeShapeData(waterBody1.waterBodyShapeData, waterBody2.waterBodyShapeData)
	
	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountPercentagePenalty, waterBody2.waterBodyTileCountPercentagePenalty, {})

    -- there is no merge for WaterAreaData - it will be re-calculated totally based on other merged data
	waterBody1.waterAreaData.ToCalculate = true
	waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody1)
	waterbodies.signalPerForce(waterBody1, waterbody_merge.signalWaterBodyMergedToPlayer, waterBody2)

	waterbodies.removeWaterBody(waterBody2)

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

    utils.Queue.enqueue(targetWaterBody.searchData.searchQueue, triggerPosition)
    targetWaterBody.searchData.finished = false
	targetWaterBody.waterAreaData.ToCalculate = true
	-- also remove the tile from edge grid
	targetWaterBody.gridsData.edgeGrid[hot_utils.GridKey(triggerPosition)] = nil

	return targetWaterBody.waterBodyId
end
