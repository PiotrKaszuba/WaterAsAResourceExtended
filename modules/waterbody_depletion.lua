require("modules.waterbodies")
require("modules.entities")
require("modules.utils")

waterbody_depletion = {}

function waterbody_depletion.calculateFocusPoint(waterBody)
    local shapeData = waterBody.waterBodyShapeData
    local centerX = (shapeData.MinX + shapeData.MaxX) / 2
    local centerY = (shapeData.MinY + shapeData.MaxY) / 2

    local pumpCount = 0
	local totalX, totalY = 0, 0
    for _, pump_data in ipairs(waterBody.waterBodyStateData.Pumps) do
        totalX = totalX + pump_data.input_position.x
        totalY = totalY + pump_data.input_position.y
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
    local focusPoint = { x = centerX + vectorX, y = centerY + vectorY }
    -- fix position to left-top corner
    local tile = utils.GetTile(focusPoint, waterBody.surface)
    focusPoint = tile.position
    return focusPoint
end

function waterbody_depletion.getCandidateTilesForVisualUpdate(waterBody, findDryTiles)
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

function waterbody_depletion.sortTilesByDistance(tiles, focusPoint, sortAscending)
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

function waterbody_depletion.restoreAllVisuals(waterBody)
    local state = waterBody.waterBodyStateData
    if not state or state.DriedTiles == 0 then return end

    local dryTiles = waterbody_depletion.getCandidateTilesForVisualUpdate(waterBody, true)
    if #dryTiles == 0 then
        state.DriedTiles = 0
        return
    end

    local tilesToChange = {}
    for _, tileData in pairs(dryTiles) do
        tilesToChange[#tilesToChange + 1] = { name = tileData.originalName, position = tileData.position }
        tileData.name = tileData.originalName
    end

    if #tilesToChange > 0 then
        waterBody.surface.set_tiles(tilesToChange, nil, nil, nil, false) -- Pass false to prevent script_raised_set_tiles event
    end

    state.DriedTiles = 0
end

function waterbody_depletion.getVisualDepletionStartPercentage()
    return settings.global["Visual-Depletion-Start-Percentage"].value
end

function waterbody_depletion.updateGradualDepletionAppearance(waterBody, percentUsed)
    local state = waterBody.waterBodyStateData
    local totalTiles = waterBody.waterAreaData.TotalArea
    local startPercentage = waterbody_depletion.getVisualDepletionStartPercentage()
    local targetChangedTiles = math.floor(totalTiles * ((percentUsed - startPercentage) / (100 - startPercentage)))
    local tilesToProcessCount = targetChangedTiles - state.DriedTiles

    if tilesToProcessCount == 0 then return end

    local isDepleting = tilesToProcessCount > 0
    local candidateTiles = waterbody_depletion.getCandidateTilesForVisualUpdate(waterBody, not isDepleting)

    if #candidateTiles == 0 then return end

    local focusPoint = waterbody_depletion.calculateFocusPoint(waterBody)
    waterbody_depletion.sortTilesByDistance(candidateTiles, focusPoint, not isDepleting) -- Sort ascending for restoring, descending for depleting

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
        state.DriedTiles = state.DriedTiles + processedCount
    else
        state.DriedTiles = state.DriedTiles - processedCount
    end

    if #tilesToChange > 0 then
        waterBody.surface.set_tiles(tilesToChange, nil, nil, nil, false) -- Pass false to prevent script_raised_set_tiles event
    end
end

function waterbody_depletion.updateDepletionAppearance(waterBody)
    local state = waterBody.waterBodyStateData
    local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)

    if percentUsed < waterbody_depletion.getVisualDepletionStartPercentage() then
        if state.DriedTiles > 0 then
            waterbody_depletion.restoreAllVisuals(waterBody)
        end
    else
        waterbody_depletion.updateGradualDepletionAppearance(waterBody, percentUsed)
    end
end