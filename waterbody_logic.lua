require("waterbodies")
require("entities")
require("utils")

waterbody_logic = {}

function waterbody_logic.disableWaterBodyPumps(waterBodyId)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if waterBody and waterBody.valid then
        for unit_number, _ in pairs(waterBody.entitiesData.pumps) do
            entities.disablePump(entities.getTrackedEntity(unit_number))
        end
    end
end

function waterbody_logic.disablePumpsAndRemoveWaterBody(waterBody)
	waterbody_logic.disableWaterBodyPumps(waterBody.waterBodyId)
    waterbodies.removeWaterBody(waterBody)
end

function waterbody_logic.getActivePumpCount(waterBody)
    local count = 0
    for unit_number, _ in pairs(waterBody.entitiesData.pumps) do
        local pump_data = entities.getTrackedEntity(unit_number)
        if not pump_data.disabled and pump_data.entity.valid and pump_data.entity.active == 1 then
            count = count + 1
        end
    end
    return count
end

-- assign a tile to a water body
-- if the tile is already assigned to a different water body, we have to merge the two water bodies
function waterbody_logic.assignTileToWaterBody(gridKey, surfaceId, waterBodyId)
    local tile_waterBodyId = waterbodies.getWaterTile(gridKey, surfaceId)
	local new_water_body_id = waterBodyId
    if waterbodies.checkIfTileIsNotAssignedToWaterBody(gridKey, surfaceId) then
        waterbodies.addNewWaterTile(gridKey, surfaceId, waterBodyId)
    elseif tile_waterBodyId ~= waterBodyId then
        -- tile is already assigned to a different water body
        -- we have to merge the two water bodies
		new_water_body_id = waterbody_logic.mergeWaterBody(waterbodies.getWaterBody(tile_waterBodyId), waterbodies.getWaterBody(waterBodyId))
    end
	return new_water_body_id
end

-- MERGE Functionality Below
function waterbody_logic.merge_indicator_tables(table_result, table_other)
    for k in pairs(table_other) do
        table_result[k] = true
    end	
end

function waterbody_logic.mergeSearchData(searchData, other_searchData, overlapTileCountData)
	searchData.searchQueue:merge(other_searchData.searchQueue)
	waterbody_logic.merge_indicator_tables(searchData.searchedPositions, other_searchData.searchedPositions)
	
	local sum_overlap = 0
	for k, v in pairs(overlapTileCountData) do
		sum_overlap = sum_overlap + v
	end
	searchData.totalArea = searchData.totalArea + other_searchData.totalArea - sum_overlap
	searchData.finished = searchData.searchQueue:is_empty()
end

function waterbody_logic.mergeGridsData(gridsData, other_gridsData, include_global_water_tiles, surfaceId)
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

	waterbody_logic.merge_indicator_tables(gridsData.edgeGrid, other_gridsData.edgeGrid)

	return overlapTileCountData
end

function waterbody_logic.mergeEntitiesData(entitiesData, other_entitiesData, waterBodyId, other_waterBodyId)
	other_pumps_unit_numbers = {}

	for unit_number, _ in pairs(other_entitiesData.pumps) do
		other_pumps_unit_numbers[#other_pumps_unit_numbers + 1] = unit_number
	end

	for _, unit_number in pairs(other_pumps_unit_numbers) do
		entities.movePumpToWaterBody(unit_number, waterBodyId, other_waterBodyId)
	end
	
	waterbody_logic.merge_indicator_tables(entitiesData.forces, other_entitiesData.forces)
end

function waterbody_logic.mergeShapeData(shapeData, other_shapeData)
	shapeData.MinX = math.min(shapeData.MinX, other_shapeData.MinX)
	shapeData.MaxX = math.max(shapeData.MaxX, other_shapeData.MaxX)
	shapeData.MinY = math.min(shapeData.MinY, other_shapeData.MinY)
	shapeData.MaxY = math.max(shapeData.MaxY, other_shapeData.MaxY)
	waterbodies.calculateDimensions(shapeData)
end

function waterbody_logic.mergeWaterBodyTileCountData(tileCountData, other_tileCountData, overlapTileCountData)
	for k, v in pairs(tileCountData) do
		tileCountData[k] = v + (other_tileCountData[k] or 0) - (overlapTileCountData[k] or 0)
	end
end

function waterbody_logic.mergeWaterUsageTickStats(waterUsageTickStats, other_waterUsageTickStats)
	for i = 1, #waterUsageTickStats do
		waterUsageTickStats[i] = waterUsageTickStats[i] + (other_waterUsageTickStats[i] or 0)
	end
end

function waterbody_logic.mergeWaterBodyStateData(waterBodyStateData, other_waterBodyStateData)
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

function waterbody_logic.mergeWaterBody(waterBody1, waterBody2)
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

	local overlapTileCountData = waterbody_logic.mergeGridsData(waterBody1.gridsData, waterBody2.gridsData, true, waterBody1.surfaceId)
	waterbody_logic.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountData, waterBody2.waterBodyTileCountData, overlapTileCountData)
	waterbody_logic.mergeSearchData(waterBody1.searchData, waterBody2.searchData, overlapTileCountData)
	waterbody_logic.mergeWaterBodyStateData(waterBody1.waterBodyStateData, waterBody2.waterBodyStateData)

	waterbody_logic.mergeShapeData(waterBody1.waterBodyShapeData, waterBody2.waterBodyShapeData)
	
	
	waterbody_logic.mergeEntitiesData(waterBody1.entitiesData, waterBody2.entitiesData, waterBody1.waterBodyId, waterBody2.waterBodyId)

	waterbody_logic.mergeWaterBodyTileCountData(waterBody1.waterBodyTileCountPercentagePenalty, waterBody2.waterBodyTileCountPercentagePenalty)
	waterbody_logic.mergeWaterUsageTickStats(waterBody1.waterUsageTickStats, waterBody2.waterUsageTickStats)

    -- there is no merge for WaterAreaData - it will be re-calculated totally based on other merged data
	waterBody1.waterAreaData.ToCalculate = true

	waterbodies.removeWaterBody(waterBody2)

	return waterBody1.waterBodyId
end

function waterbody_logic.mergeMultipleWaterBodies(waterBodyIds, triggerPosition, surfaceId)
    if #waterBodyIds < 2 then return end
    
    local targetWaterBody = waterbodies.getWaterBody(waterBodyIds[1])
    if not targetWaterBody then return end
    
    for i = 2, #waterBodyIds do
        local otherWaterBody = waterbodies.getWaterBody(waterBodyIds[i])
        if otherWaterBody and otherWaterBody.valid then
            waterbody_logic.mergeWaterBody(targetWaterBody, otherWaterBody)
        end
    end
    
    targetWaterBody.searchData.searchQueue:enqueue(triggerPosition)
    targetWaterBody.searchData.finished = false
	targetWaterBody.waterAreaData.ToCalculate = true
	-- also remove the tile from edge grid
	targetWaterBody.gridsData.edgeGrid[utils.PositionToString(triggerPosition)] = nil

	return targetWaterBody.waterBodyId
end
