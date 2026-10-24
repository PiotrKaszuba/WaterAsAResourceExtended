require("modules.utils")
require("modules.hot_utils")
require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.waterbody_split")
require("modules.split_families")
require("modules.entities")
require("modules.waterbody_merge")
local pending_tile_events = require("modules.pending_tile_events")

tiles = {}

function tiles.initTileEventQueue()
    if storage.TileEventQueue == nil then
        storage.TileEventQueue = utils.Queue.new()
    end
    pending_tile_events.ensure(storage.TileEventQueue)
end

function tiles.rebuildPendingTileChanges()
    pending_tile_events.rebuild(storage.TileEventQueue)
end

function tiles.getTileEventQueue()
    return storage.TileEventQueue
end

tiles.waterfill_placer_to_water_tile = {
    ["waterfill-placer"] = "water-shallow",
    ["waterfill-placer-deep"] = "deepwater"
}



function tiles.placerWater(placed)
    local pos_center = placed.position
    local surface = placed.surface

    local old_tile = utils.GetTile(pos_center, surface)
    local old_tile_name = old_tile.name
    local pos = old_tile.position

    if utils.DryWaterTiles[old_tile_name] then
        utils.rejectEntityPlacement(placed, "Cannot place waterfill on dry (depleted) tile")
        return
    end

    local replacement = tiles.waterfill_placer_to_water_tile[placed.name]
    placed.destroy()

    local tileArray = {}
    tileArray[1] = {
        name = replacement,
        position = { x = pos.x, y = pos.y },
        old_tile = { name = old_tile_name }
    }

    -- 5th argument is false to prevent script_raised_set_tiles event
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
    pending_tile_events.ensure(storage.TileEventQueue)
    local event = tiles.initTileEvent(eventType, position, surface, tileData)
    if utils.Queue.enqueue(storage.TileEventQueue, event) then pending_tile_events.add(event) end
end

function tiles.processTileEventQueue(maxEvents, updateBudget)
    local queue = tiles.getTileEventQueue()
    pending_tile_events.ensure(queue)
    local processedCount = 0

    while not utils.Queue.is_empty(queue) and processedCount < maxEvents and updateBudget.budget > 0 do
        local event = utils.Queue.dequeue(queue)
        if event then
            if event.type == "landfill" then
                tiles.processLandfillEvent(event, updateBudget)
            elseif event.type == "waterfill" then
                tiles.processWaterfillEvent(event, updateBudget)
            elseif event.type == "restore" then
                tiles.processRestorationEvent(event, updateBudget)
            end
            pending_tile_events.finish(event)
        end
        processedCount = processedCount + 1
    end

    return processedCount
end

-- Old saves used two ambiguous dry names. Resolve their wet identity before
-- reclaiming removes the grid/orphan data; typed dry names resolve directly.
function tiles.getOriginalWaterTileName(tileName, position, surface)
    if utils.IsWaterTile(tileName) then return tileName end
    local original = utils.DryToWetTileMap[tileName]
    if original then return original end
    waterbodies.initSurface(surface.name)
    local key = hot_utils.GridKey(position)
    local body = waterbodies.getWaterBody(waterbodies.getWaterTile(key, surface))
    if body and body.valid then
        local grids = body.gridsData
        local tile = utils.LazyTables.get(key, grids.driedTilesGridWithData, grids.lazyDriedTilesGridWithData)
            or utils.LazyTables.get(key, grids.waterGridWithData, grids.lazyWaterGridWithData)
        if tile then original = tile.originalName end
    end
    if not original then
        original = utils.LazyTables.get(key, storage.OrphanedDryTilesOriginalName[surface.name],
            storage.lazyOrphanedDryTilesOriginalName[surface.name])
        if type(original) == "table" then original = original.originalName end
    end
    return original
end

-- Mining is not paid waterfill. Exposed terrain is empty capacity, represented
-- by a self-describing dry tile even when no waterbody survives to remember it.
function tiles.handleMinedTiles(tileArray, surface)
    if not tileArray or not surface or not utils.isManagedSurface(surface) then return end
    local dryChanges = {}
    for _, event in ipairs(tileArray) do
        if event.old_tile and event.old_tile.name == "landfill" then
            local position = utils.fixPositionToLeftTopCorner(event.position)
            local name = surface.get_tile(position).name
            if utils.IsWaterOrDryTile(name) then
                local original = tiles.getOriginalWaterTileName(name, position, surface)
                local dry = original and utils.WetToDryTileMap[original]
                if dry then
                    if dry ~= name then
                        dryChanges[#dryChanges + 1] = { name = dry, position = position }
                    end
                    tiles.addTileEvent("restore", position, surface, { tileName = dry })
                end
            end
        end
    end
    if #dryChanges > 0 then
        -- Do not change ownership here: a preceding landfill event can still be
        -- queued. FIFO accounting removes the old tile before adding empty area.
        surface.set_tiles(dryChanges, false, false, false, false)
    end
end

function tiles.handleTileEventsInternal(tileArray, surface, placed_name)
    if not tileArray or not surface then return end
    if not utils.isManagedSurface(surface) then return end

    local surfaceName = surface.name
    waterbodies.initSurface(surfaceName)

    for _, tile_event in pairs(tileArray) do
        local position = tile_event.position

        -- try to fix the position to left-top corner just in case
        position = utils.fixPositionToLeftTopCorner(position)
        local old_tile = tile_event.old_tile
        local old_name = old_tile and old_tile.name
        local new_name = placed_name or tile_event.name

        if old_name == nil then
            utils.profile_hits("handleTileEventsInternal", "no old tile name")
            game.print(
            "Warning: script_raised_set_tiles with no old tile name. Problems may arise if landfill was placed not on water or waterfill was placed on water or dry (depleted) tile.")
        end

        local originalWaterName = old_name
        if utils.IsDryTile(old_name) then
            originalWaterName = tiles.getOriginalWaterTileName(old_name, position, surface)
            if new_name == "landfill" and originalWaterName then
                -- The engine stores the dry bed beneath landfill. Give legacy
                -- beds an exact identity without retaining covered-tile history.
                surface.set_hidden_tile(position, utils.WetToDryTileMap[originalWaterName])
            end
            -- if something else than dry tile is placed on dry tile:
            -- we can for sure remove it from OrphanedDryTilesOriginalName
            local gridKey = hot_utils.GridKey(position)
            utils.LazyTables.remove(gridKey, storage.OrphanedDryTilesOriginalName[surfaceName],
                storage.lazyOrphanedDryTilesOriginalName[surfaceName])
        end

        if new_name == "landfill" and ((old_name and utils.IsWaterOrDryTile(old_name)) or (not old_name)) then
            tiles.addTileEvent("landfill", position, surface, {
                originalTileName = originalWaterName,
                tileName = new_name,
            })
        elseif utils.IsWaterTile(new_name) and ((old_name and not utils.IsWaterTile(old_name)) or (not old_name)) then
            tiles.addTileEvent("waterfill", position, surface, {
                originalTileName = old_name,
                tileName = new_name,
            })
        end
    end
end

function tiles.processRestorationEvent(tileEvent, updateBudget)
    -- A later placement may already have covered this position again.
    if not utils.IsDryTile(tileEvent.surface.get_tile(tileEvent.position).name) then return end
    tiles.processWaterfillEvent(tileEvent, updateBudget)
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

        if waterBody and waterBody.valid then
            local search_queue_enqueue, _ = waterbodies.getSearchQueueEnqueueAndDequeue(waterBody.searchData.searchQueue)
            search_queue_enqueue(waterBody.searchData.searchQueue, position)
            waterBody.searchData.finished = false
            waterBody.waterBodyStateData.ToCalculate = true
            waterBody.waterBodyStateData.ToUpdate = true
            -- also remove the tile from edge grid
            local gridsData = waterBody.gridsData
            utils.LazyTables.remove(hot_utils.GridKey(position), gridsData.edgeGrid, gridsData.lazyEdgeGrid)
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
        local adj_pos = { x = position.x + offset.x, y = position.y + offset.y }
        local adj_gridKey = hot_utils.GridKey(adj_pos)
        local waterBodyId = waterbodies.getWaterTile(adj_gridKey, surface)

        if not waterbodies.checkIfTileIsNotAssignedToValidWaterBody(adj_gridKey, surface) and not seen[waterBodyId] then
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
    -- 3a. Update centroid geometry on removal
    waterbodies.updateGeometryOnRemove(waterBody.waterBodyShapeData, -position.x, -position.y, -1)

    -- 4. Mark tile as unassigned in global registry
    hot_utils.addNewWaterTile(gridKey, surfaceName, -1)

    -- 5. Recalculate edges around this position
    waterbody_scan.recalculateEdgesAroundPosition(waterBody, position, surface, updateBudget)

    -- 6. Mark for water amount recalculation
    waterBody.waterBodyStateData.ToCalculate = true
    waterBody.waterBodyStateData.ToUpdate = true
    -- Splitting can snapshot this body's depletion immediately. Its capacity
    -- must already reflect this removal, including within a multi-tile brush.
    waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody)

    -- 7. Check if water body becomes empty
    if waterbodies.isWaterBodyEmpty(waterBody) then
        waterbodies.signalPerForce(waterBody, waterbodies.signalEmptyToPlayer)
        entities.disablePumpsAndRemoveWaterBody(waterBody)
    end
end

function tiles.processLandfillEvent(tileEvent, updateBudget)
    -- assume position is left-top corner already
    local position = tileEvent.position
    local surface = tileEvent.surface
    local gridKey = hot_utils.GridKey(position)
    local waterBodyId = waterbodies.getWaterTile(gridKey, surface)

    -- check if tile is assigned (to valid or invalid) water body
    if waterbodies.checkIfWaterBodyIdIsOfAssignedValue(waterBodyId) then
        local waterBody = waterbodies.getWaterBody(waterBodyId)
        local budget_cost = 0

        -- if valid - reduce tile from water body
        if waterBody and waterBody.valid then
            budget_cost = budget_cost + 2
            tiles.reduceTileFromWaterBody(waterBody, tileEvent.tileData.originalTileName, position, surface, updateBudget)

            -- if still valid - check if water body got split
            if waterBody and waterBody.valid then
                budget_cost = budget_cost + 2
                waterbody_split.checkIfWaterBodyGotSplit(waterBodyId, position, surface, updateBudget)
            end
            if updateBudget then
                updateBudget.budget = updateBudget.budget - budget_cost
            end
        else
            -- if invalid - unassign it
            local surfaceName = surface.name
            hot_utils.addNewWaterTile(gridKey, surfaceName, -1)

            -- need to check for split family of invalid waterbody
            split_families.attempt_assign_landfill(waterBodyId, position, gridKey)
        end
    end
end
