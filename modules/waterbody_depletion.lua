require("modules.waterbodies")
require("modules.utils")

waterbody_depletion = {}

-- return number of tiles moved
function waterbody_depletion.requestNewBinsetUpdate(gridsData, max_to_move, include_old_binsets, ratio_from_old_binsets)
    local oldBinsets = gridsData.oldBinsets
    local newBinset = gridsData.newBinset
    local pendingTiles = gridsData.pendingTiles

    local _, pending_tiles_dequeue = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(false)

    local waterGridWithData = gridsData.waterGridWithData
    local lazyWaterGridWithData = gridsData.lazyWaterGridWithData

    local lazy_tables_get = utils.LazyTables.get
    local dynamic_bins_push = dynamic_bins.push
    local dynamic_bins_batch_pop = dynamic_bins.batch_pop

    local moved = 0

    -- consume old binsets
    if include_old_binsets and #oldBinsets > 0 then
        -- copy 50% of max_to_move from old binsets
        -- it won't go through (deduplication in) pending tiles
        local amount_copy = math.ceil(max_to_move * (ratio_from_old_binsets or 0.5))

        local oldBinset = oldBinsets[1]
        while moved < amount_copy and #oldBinsets > 0 do
            if oldBinset.total <= 0 then
                -- binset is empty - remove it and try next one
                table.remove(oldBinsets, 1)
                oldBinset = oldBinsets[1]
                if oldBinset == nil then
                    -- no more old binsets - break
                    break
                end
            end
            local item_datas, _, num_popped = dynamic_bins_batch_pop(oldBinset, amount_copy)
            moved = moved + num_popped
            amount_copy = amount_copy - num_popped
            for i = 1, num_popped do
                local gridKey = item_datas[i]
                local tileData = lazy_tables_get(gridKey, waterGridWithData, lazyWaterGridWithData)
                if tileData ~= nil then
                    local pos = tileData.position
                    dynamic_bins_push(newBinset, gridKey, pos.x, pos.y)
                end
            end
        end
    end

    local pending_tiles_size = pendingTiles.size
    -- consume pending tiles
    while moved < max_to_move and pending_tiles_size > 0 do
        local gridKey = pending_tiles_dequeue(pendingTiles)
        if gridKey == nil then break end
        pending_tiles_size = pending_tiles_size - 1

        -- Validate the tile still belongs to this waterbody as water
        local tileData = lazy_tables_get(gridKey, waterGridWithData, lazyWaterGridWithData)
        moved = moved + 1
        if tileData ~= nil then
            local pos = tileData.position
            dynamic_bins_push(newBinset, gridKey, pos.x, pos.y)
        end
        -- If tileData is missing, it might have dried or moved; drop it silently
    end

    return moved
end

function waterbody_depletion.getMinBinsetCountAndExtraCountRatio()
    -- minimum amount of tiles to be present in the binset
    -- and an extra amount ratio times
    -- the amount of tiles that are being requested to be dried right now
    -- if not enough tiles are present in the binset
    -- they will be immediately added (if possible) from pending tiles (and maybe old binsets)
    -- minimum value is 1.0
    return 100, 2.0
end

function waterbody_depletion.getTilesDepleting(waterBody, isDepleting, num_tiles)
    local gridsData = waterBody.gridsData
    local driedTilesGridWithData = gridsData.driedTilesGridWithData
    local waterGridWithData = gridsData.waterGridWithData
    
    local driedStack = gridsData.driedStack
    local driedStackEnqueue, driedStackDequeue = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(true)

    local lazy_tables_get = utils.LazyTables.get
    local lazy_tables_remove = utils.LazyTables.remove
    local lazy_tables_next = utils.LazyTables.next
    

    local tiles = {}
    local num_tiles_processed = 0

    if isDepleting then
        local lazyWaterGridWithData = gridsData.lazyWaterGridWithData
        local getDryTileForWetTile = utils.getDryTileForWetTile
        -- prepare binsets to have enough tiles
        local dynamic_bins = gridsData.newBinset
        local dynamic_bins_total = dynamic_bins.total

        local min_count, extra_count_ratio = waterbody_depletion.getMinBinsetCountAndExtraCountRatio()

        local quality_count = min_count + math.ceil(num_tiles * extra_count_ratio)
        
        local quality_missing_count = quality_count - dynamic_bins_total
        local missing_count = num_tiles - dynamic_bins_total

        if quality_missing_count > 0 then
            -- request new binset update - but it might not grant all tiles we would like
            -- try twice then get tiles from source
            
            local added_tiles = waterbody_depletion.requestNewBinsetUpdate(gridsData, quality_missing_count, true, 0.5)
            quality_missing_count, missing_count = quality_missing_count - added_tiles, missing_count - added_tiles
            if quality_missing_count > 0 then
                added_tiles = waterbody_depletion.requestNewBinsetUpdate(gridsData, quality_missing_count, true, 1.0)
                quality_missing_count, missing_count = quality_missing_count - added_tiles, missing_count - added_tiles
            end
        end

        dynamic_bins_total = dynamic_bins.total
        local to_pop_tiles = math.min(num_tiles, dynamic_bins_total)

        local item_datas, _, num_available_tiles = dynamic_bins.batch_pop(dynamic_bins, to_pop_tiles)
        
        local dryTileName = nil
        local gridKey, tile_data, cur_table = nil, nil, nil
        local next_gridKey, next_tile_data, next_table = nil, nil, nil
        local just_exhausted_num_available_tiles = true
        while num_tiles_processed < num_tiles do
            -- check if we can continue
            -- when depleting we get the tile from the binset
            -- if not possible then we default to grabbing tiles from water grid
            if num_available_tiles <= 0 then
                -- just entered the num_available_tiles == 0 case
                -- should never return to the other case (else)
                if just_exhausted_num_available_tiles then
                    just_exhausted_num_available_tiles = false
                    -- first time grabbing - grab first as current
                    gridKey, tile_data, cur_table = lazy_tables_next(waterGridWithData, lazyWaterGridWithData)
                else
                    -- not first time grabbing - just update currents
                    gridKey, tile_data, cur_table = next_gridKey, next_tile_data, next_table
                end

                if gridKey == nil then
                    break -- no more tiles to process
                end
                -- grab next key if something is found (so removing doesn't mess iterator)
                next_gridKey, next_tile_data, next_table = lazy_tables_next(waterGridWithData, lazyWaterGridWithData, gridKey, cur_table)
            else
                gridKey = item_datas[num_available_tiles]
                num_available_tiles = num_available_tiles - 1
                if gridKey == nil then
                    goto continue_depleting
                end
                -- when depleting we get the tile from the water grid
                -- also validating that it is present there
                tile_data = lazy_tables_get(gridKey, waterGridWithData, lazyWaterGridWithData)
            end

            if tile_data then
                num_tiles_processed = num_tiles_processed + 1
                dryTileName = getDryTileForWetTile(tile_data.name)
                -- when depleting we change the current name to the dry name
                -- we also move the tile to the dried tiles grid from water grid
                -- and enqueue the gridKey to the dried stack
                if dryTileName then
                    tile_data.name = dryTileName
                    tiles[num_tiles_processed] = { name = dryTileName, position = tile_data.position }
                else
                    utils.profile_hits("waterbody_depletion.getTilesDepleting", "getDryTileForWetTile returned nil for " .. tile_data.name)
                    game.print("Warning: getDryTileForWetTile returned nil for " .. tile_data.name)
                end
                lazy_tables_remove(gridKey, waterGridWithData, lazyWaterGridWithData)
                driedTilesGridWithData[gridKey] = tile_data
                driedStackEnqueue(driedStack, gridKey)
            end
            ::continue_depleting::
        end
    else
        local lazyDriedTilesGridWithData = gridsData.lazyDriedTilesGridWithData
        local lazyDriedStack = gridsData.lazyDriedStack

        local driedStack_joint_size = utils.LazyTables.joint_queue_size(driedStack, lazyDriedStack)
        local pendingTiles = gridsData.pendingTiles
        local pendingTilesEnqueue, _ = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(false)

        local gridKey, tile_data, cur_table = nil, nil, nil
        local next_gridKey, next_tile_data, next_table = nil, nil, nil
        local just_exhausted_driedStack_joint_size = true
        while num_tiles_processed < num_tiles do
            -- check if we can continue
            -- when restoring we get the tile from the dried stack
            -- if not possible then we default to grabbing tiles from dried tiles grid
            if driedStack_joint_size == 0 then
                -- just entered the driedStack_joint_size == 0 case
                -- should never return to the other case (else)
                if just_exhausted_driedStack_joint_size then
                    just_exhausted_driedStack_joint_size = false
                    -- first time grabbing - grab first as current
                    gridKey, tile_data, cur_table = lazy_tables_next(driedTilesGridWithData, lazyDriedTilesGridWithData)
                else
                    -- not first time grabbing - just update currents
                    gridKey, tile_data, cur_table = next_gridKey, next_tile_data, next_table
                end

                if gridKey == nil then
                    break -- no more tiles to process
                end
                -- grab next key if something is found (so removing doesn't mess iterator)
                next_gridKey, next_tile_data, next_table = lazy_tables_next(driedTilesGridWithData, lazyDriedTilesGridWithData, gridKey, cur_table)
            else
                gridKey = driedStackDequeue(driedStack, lazyDriedStack)
                driedStack_joint_size = driedStack_joint_size - 1
                if gridKey == nil then
                    goto continue_restoring
                end
                -- when restoring we get the tile from the dried stack
                -- also validating that it is present there
                tile_data = lazy_tables_get(gridKey, driedTilesGridWithData, lazyDriedTilesGridWithData)
            end

            if tile_data then
                num_tiles_processed = num_tiles_processed + 1
                tile_data.name = tile_data.originalName
                tiles[num_tiles_processed] = { name = tile_data.name, position = tile_data.position }
                lazy_tables_remove(gridKey, driedTilesGridWithData, lazyDriedTilesGridWithData)
                pendingTilesEnqueue(pendingTiles, gridKey)
                waterGridWithData[gridKey] = tile_data
                
            end
            ::continue_restoring::
        end
    end

    if num_tiles_processed > 0 then
        local surface = waterBody.surface
        surface.set_tiles(tiles, nil, nil, nil, false) -- Pass false to prevent script_raised_set_tiles event
    end

    local state = waterBody.waterBodyStateData
    if isDepleting then
        state.DriedTiles = state.DriedTiles + num_tiles_processed
    else
        state.DriedTiles = state.DriedTiles - num_tiles_processed
    end
    return num_tiles_processed
end

function waterbody_depletion.getVisualDepletionStartPercentage()
    return settings.global["Visual-Depletion-Start-Percentage"].value
end

function waterbody_depletion.updateDepletionAppearanceCount(waterBody)
    -- this function updates the requested value of tiles to dry or restore: ToDryTiles
    -- also monitors the state and possibly fixes value of DriedTiles to 0 if needed 
    -- actual visual update is deferred to work loop
    -- BUT the assumption is that all ToDryTiles have to processed before the next big update
    -- so that entering this function value of ToDryTiles is 0

    local state = waterBody.waterBodyStateData
    local gridsData = waterBody.gridsData

    local driedTilesGridEmpty = utils.LazyTables.all_empty(gridsData.driedTilesGridWithData, gridsData.lazyDriedTilesGridWithData)

    local toDryTiles = state.ToDryTiles
    local driedTiles = state.DriedTiles

    if toDryTiles ~= 0 then
        -- entering depletion update should have toDryTiles at 0
        utils.profile_hits("waterbody_depletion.updateDepletionAppearance", "when entering depletion update toDryTiles is not 0")
        game.print("Warning: when entering depletion update toDryTiles is not 0")
        return
    end
    
    if driedTiles == 0 then
        -- previously there was no depletion
        -- double check that the table reflects that   
        if not driedTilesGridEmpty then
            local message = string.format("driedTiles is 0 but there are tiles in driedTilesGridWithData from %s", waterBody.waterBodyName)
            utils.profile_hits("waterbody_depletion.updateDepletionAppearance", message)
            game.print("Warning: " .. message)
            return
        end
    elseif driedTilesGridEmpty then
        -- driedTilesGrid is supposed to be source of truth so add a warning
        local message = string.format("driedTilesGridWithData is empty but driedTiles is not 0 (setting driedTiles to 0 from %s) for %s", driedTiles, waterBody.waterBodyName)
        utils.profile_hits("waterbody_depletion.updateDepletionAppearance", message)
        game.print("Warning: " .. message)

        -- and set driedTiles to 0
        driedTiles = 0
        state.DriedTiles = driedTiles
    end
    
    local startPercentage = waterbody_depletion.getVisualDepletionStartPercentage()
    local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)

    if percentUsed < startPercentage then
        -- we need to restore all tiles so set toDryTiles to -driedTiles
        toDryTiles = -driedTiles
    else
        -- we are in the depletion values area so we need to calculate how many tiles should be dried
        local totalTiles = waterBody.waterAreaData.TotalArea
        local targetChangedTiles = math.floor(totalTiles * ((percentUsed - startPercentage) / (100 - startPercentage)))
        toDryTiles = targetChangedTiles - driedTiles
    end

    state.ToDryTiles = toDryTiles
end
