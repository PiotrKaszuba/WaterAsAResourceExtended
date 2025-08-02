require("modules.waterbodies")
require("modules.utils")
require("modules.entities")

waterbody_merge = {}



-- MERGE Functionality Below
function waterbody_merge.merge_indicator_tables(table_result, table_other)
    for k in pairs(table_other) do
        table_result[k] = true
    end	
end

function waterbody_merge.mergeSearchData(searchData, other_searchData, overlapTileCountData)
	searchData.searchQueue:merge(other_searchData.searchQueue)
	
	local sum_overlap = 0
	for k, v in pairs(overlapTileCountData) do
		sum_overlap = sum_overlap + v
	end
	searchData.totalArea = searchData.totalArea + other_searchData.totalArea - sum_overlap
	searchData.finished = searchData.searchQueue:is_empty()
end

function waterbody_merge.mergeGridsData(gridsData, other_gridsData, include_global_water_tiles, surfaceId)
	local overlapTileCountData = waterbodies.initWaterBodyTileCountData()

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
			waterbodies.addNewWaterTile(gridKey, surfaceId, gridsData.waterBodyId)
		end
	end

	waterbody_merge.merge_indicator_tables(gridsData.edgeGrid, other_gridsData.edgeGrid)

	return overlapTileCountData
end

function waterbody_merge.mergeEntitiesData(entitiesData, other_entitiesData, waterBodyId, other_waterBodyId)
	other_pumps_unit_numbers = {}

	for unit_number, _ in pairs(other_entitiesData.pumps) do
		other_pumps_unit_numbers[#other_pumps_unit_numbers + 1] = unit_number
	end

	for _, unit_number in pairs(other_pumps_unit_numbers) do
		entities.movePumpToWaterBody(unit_number, waterBodyId, other_waterBodyId)
	end
	
	waterbody_merge.merge_indicator_tables(entitiesData.forces, other_entitiesData.forces)
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

function waterbody_merge.mergeWaterBodyStateData(waterBodyStateData, other_waterBodyStateData)
	waterBodyStateData.WaterUsed = waterBodyStateData.WaterUsed + other_waterBodyStateData.WaterUsed
	waterBodyStateData.WaterUsedPrev = waterBodyStateData.WaterUsedPrev + other_waterBodyStateData.WaterUsedPrev

	waterBodyStateData.TempAvailableWater = waterBodyStateData.TempAvailableWater + other_waterBodyStateData.TempAvailableWater
	waterBodyStateData.TempUsedWater = waterBodyStateData.TempUsedWater + other_waterBodyStateData.TempUsedWater

	waterBodyStateData.WaterUsedPenalty = waterBodyStateData.WaterUsedPenalty + other_waterBodyStateData.WaterUsedPenalty
	waterBodyStateData.WaterUsedPenaltyRestored = waterBodyStateData.WaterUsedPenaltyRestored + other_waterBodyStateData.WaterUsedPenaltyRestored

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

	local overlapTileCountData = waterbody_merge.mergeGridsData(waterBody1.gridsData, waterBody2.gridsData, true, waterBody1.surfaceId)
	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountData, waterBody2.waterBodyTileCountData, overlapTileCountData)
	waterbody_merge.mergeSearchData(waterBody1.searchData, waterBody2.searchData, overlapTileCountData)
	waterbody_merge.mergeWaterBodyStateData(waterBody1.waterBodyStateData, waterBody2.waterBodyStateData)

	waterbody_merge.mergeShapeData(waterBody1.waterBodyShapeData, waterBody2.waterBodyShapeData)
	
	
	waterbody_merge.mergeEntitiesData(waterBody1.entitiesData, waterBody2.entitiesData, waterBody1.waterBodyId, waterBody2.waterBodyId)

	waterbody_merge.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountPercentagePenalty, waterBody2.waterBodyTileCountPercentagePenalty, {})

    -- there is no merge for WaterAreaData - it will be re-calculated totally based on other merged data
	waterBody1.waterAreaData.ToCalculate = true
	waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody1)
	waterbodies.signalPerForce(waterBody1, waterbody_merge.signalWaterBodyMergedToPlayer, waterBody2)

	waterbodies.removeWaterBody(waterBody2)

	return waterBody1.waterBodyId
end

function waterbody_merge.mergeMultipleWaterBodies(waterBodyIds, triggerPosition, surfaceId)
	-- fix position to left-top corner in case it was not
	local tile = utils.GetTile(triggerPosition, surfaceId)
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

    targetWaterBody.searchData.searchQueue:enqueue(triggerPosition)
    targetWaterBody.searchData.finished = false
	targetWaterBody.waterAreaData.ToCalculate = true
	-- also remove the tile from edge grid
	targetWaterBody.gridsData.edgeGrid[utils.PositionToString(triggerPosition)] = nil

	return targetWaterBody.waterBodyId
end
