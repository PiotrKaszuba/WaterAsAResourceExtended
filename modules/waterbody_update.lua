require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.waterbody_depletion")
require("modules.entities")
require("modules.utils")
require("modules.dynamic_bins")

waterbody_update = {}

function waterbody_update.getMapMarkerEnabled()
    return settings.global["Map-EnableMarkers"].value
end

function waterbody_update.createMapMarker(waterBody)
    if not waterbody_update.getMapMarkerEnabled() then
        waterbodies.destroyMapMarkers(waterBody.waterBodyStateData)
        return
    end

    local force_to_pump = entities.getFirstPumpPerForce(waterBody)

    local icon = { type = "fluid", name = "water" }
    local percent = waterbodies.calculatePercentageWaterUsed(waterBody)
    local depleted = waterBody.waterBodyStateData.Depleted

    local surface = waterBody.surface
    local remaining = math.ceil(waterBody.waterAreaData.AmountWtr * (100 - percent) / 100)

    local text = string.format("%s - %s - %.2f %%", waterbodies.getFullNameForWaterBody(waterBody),
        utils.comma_value(remaining), 100 - percent)
    if not waterBody.searchData.finished then
        text = "Pending... - " .. text
    elseif depleted then
        text = "Depleted! - " .. text
    end

    for force_name, player_force in pairs(waterBody.waterBodyStateData.Forces) do
        local marker = waterBody.waterBodyStateData.MapMarkers[force_name]
        local position = nil
        if force_to_pump[force_name] then
            position = force_to_pump[force_name].input_position
            position = utils.fixPositionToLeftTopCorner(position) -- not needed, but let's use left-top as much as possible
        end

        if position and (not marker or not utils.MapMarker.valid(marker)) then
            marker = utils.MapMarker.new(player_force.force, surface, position, text, icon)
            waterBody.waterBodyStateData.MapMarkers[force_name] = marker
        else
            if position then
                utils.MapMarker.update(marker, position, text, icon)
            elseif marker then
                utils.MapMarker.destroy(marker)
                waterBody.waterBodyStateData.MapMarkers[force_name] = nil
            end
        end
    end
end

function waterbody_update.getLowLevelAlarms()
    if settings.global["Alarms-Low-Level"].value then
        return {
            { 50, "Fired50" }, { 75, "Fired75" }, { 90, "Fired90" }
        }
    end
    return {}
end

function waterbody_update.getHighLevelAlarms()
    if settings.global["Alarms-High-Level"].value then
        return {
            { 95, "Fired95" }, { 97, "Fired97" }, { 98, "Fired98" }, { 99, "Fired99" }
        }
    end
    return {}
end

function waterbody_update.signalDepletionToPlayer(waterBody)
    return string.format("%s has been depleted.", waterbodies.getFullNameForWaterBody(waterBody))
end

function waterbody_update.signalAlarmToPlayer(waterBody, force, percentUsed)
    return string.format("%s has used %.0f%% of available water.", waterbodies.getFullNameForWaterBody(waterBody),
        percentUsed)
end

function waterbody_update.handleDepletionAlarms(waterBody, percentUsed)
    local state = waterBody.waterBodyStateData

    -- Handle alarms
    if not state.Depleted then
        local alarms = utils.merge_arrays(waterbody_update.getLowLevelAlarms(), waterbody_update.getHighLevelAlarms())
        local do_alarm = false
        for _, alarm in ipairs(alarms) do
            local threshold, flag = table.unpack(alarm)
            if percentUsed >= threshold and not state[flag] then
                do_alarm = true
                state[flag] = true
            elseif percentUsed < (threshold - 1) and state[flag] then -- -1 is a hysteresis to avoid flickering
                state[flag] = false                                   -- Reset flag if level drops below threshold
            end
        end
        if do_alarm then
            waterbodies.signalPerForce(waterBody, waterbody_update.signalAlarmToPlayer, percentUsed)
        end
    end
end

function waterbody_update.bigUpdateWaterLevel(waterBody)
    local state = waterBody.waterBodyStateData
    state.WaterUsedPrev = state.WaterUsed
    local waterUsedChange = state.TempUsedWater
    local regenAmount = waterbody_update.calculateEffectiveRegenAmount(waterBody)
    waterbody_update.updateWaterLevel(waterBody, waterUsedChange, regenAmount)
    state.TempAvailableWater = waterbodies.calculateRemainingWater(waterBody)
    state.TempUsedWater = 0
    -- we don't set pumps to active here - it will be handled by pumps update
    state.TempInactive = not waterbodies.canPumpWaterNow(state)
end

function waterbody_update.updateWaterLevel(waterBody, waterUsedChange, regenAmount)
    local state = waterBody.waterBodyStateData
    -- Do not clamp water used to be within bounds - the bound violations should be still handled by depletion
    -- and they might be present to be made up for by the natural regeneration or drainage, etc.
    -- we will only limit natural regeneration not to occur if it would go below 0
    state.WaterUsed = state.WaterUsed + waterUsedChange
    local totalWaterUsed = waterbodies.calculateTotalWaterUsed(waterBody)

    local regen = math.max(0, math.min(regenAmount or 0, totalWaterUsed)) -- this ensures that regen is not greater than the water used and positive

    local remainingWaterUsedPenalty = math.max(0, state.WaterUsedPenalty - state.WaterUsedPenaltyRestored)
    local regen1 = math.min(state.WaterUsed, regen)
    local regen2 = math.max(0, math.min(regen - regen1, remainingWaterUsedPenalty)) -- this ensures that regen is not greater than the water used penalty and positive

    state.WaterUsed = state.WaterUsed - regen1
    state.WaterUsedPenaltyRestored = state.WaterUsedPenaltyRestored + regen2

    state.TempAvailableWater = state.TempAvailableWater - waterUsedChange + (regen1 + regen2)
end

function waterbody_update.calculateEffectiveRegenAmount(waterBody)
    -- Placeholder for regen calculation
    local regen_base = utils.normalize_update_values_per_second(waterBody.waterAreaData.RegenAmount)
    local missing_water_percentage = waterbodies.calculatePercentageWaterUsed(waterBody) / 100
    -- best regen is at 75% missing water -> 150%
    -- at 100% missing water, regen is at 50% and at 0% missing water, regen is at 75%
    local multiplier = 0.75
    if missing_water_percentage > 0.75 then
        multiplier = math.max(math.min(1.5 - (missing_water_percentage - 0.75) * 4, 1.5), 0.5)
    else
        multiplier = math.max(math.min(1.5 + (missing_water_percentage - 0.75) * 1, 1.5), 0.5)
    end
    local regen_with_bonus = regen_base * multiplier
    return regen_with_bonus
end

function waterbody_update.waterBodyRestored(waterBody)
    local state = waterBody.waterBodyStateData
    state.Depleted = false
end

function waterbody_update.getPumpsReactivationLevelPerThousand()
    return settings.global["Pumps-Reactivation-LevelPerThousand"].value
end

function waterbody_update.handleDepletion(waterBody)
    local state = waterBody.waterBodyStateData
    local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)

    -- Handle depletion state
    -- we only deplete if the waterbody is finished scanning - otherwise we will just keep TempInactive
    if percentUsed >= 100 and not state.Depleted and waterBody.searchData.finished then
        waterbody_update.waterBodyDepleted(waterBody)
    elseif percentUsed < waterbody_update.getPumpsReactivationLevelPerThousand() / 10 and state.Depleted then
        waterbody_update.waterBodyRestored(waterBody)
    end

    waterbody_update.handleDepletionAlarms(waterBody, percentUsed)
    waterbody_depletion.updateDepletionAppearanceCount(waterBody)
end

function waterbody_update.waterBodyDepleted(waterBody)
    local state = waterBody.waterBodyStateData
    -- only call once per depletion
    if not state.Depleted then
        waterbodies.signalPerForce(waterBody, waterbody_update.signalDepletionToPlayer)
    end
    state.Depleted = true
    entities.deactivateWaterBodyPumps(waterBody.waterBodyId)
end

function waterbody_update.collectWaterUsageStats()
    -- every tick call -> optimized for performance not code maintenance - reduced function calls - just plain code
    -- comments show otherwise would be called functions

    -- initialize all variables once for performance?
    local total_pumping_water, water_usage, state, is_temp_inactive, temp_used_water, entity
    local periodic_every_x_ticks = storage.PeriodicEveryXTicks
    for _, waterBody in pairs(storage.ValidWaterBodies) do -- pairs(waterbodies.getValidWaterBodies())
        state = waterBody.waterBodyStateData
        total_pumping_water = 0
        -- waterbody_update.collectWaterUsageStatsForWaterBody(waterBody)
        for _, pump_data in ipairs(state.Pumps) do
            -- waterbody_update.getWaterUsageStatsForPump(pump_data)
            entity = pump_data.entity
            water_usage = 0
            if entity.valid and entity.active then
                water_usage = entity.pumped_last_tick

                -- multiplication by storage.PeriodicEveryXTicks:
                -- estimation of the water usage between ticks
                -- i.e. if we sample pumped value every 10 ticks we assume
                -- that it was the average usage
                water_usage = water_usage * pump_data.playerForce.water_usage_multiplier * periodic_every_x_ticks
                -- end of waterbody_update.getWaterUsageStatsForPump(pump_data)

                total_pumping_water = total_pumping_water + water_usage
            end
        end
        -- end of waterbody_update.collectWaterUsageStatsForWaterBody(waterBody)

        -- waterbody_update.smallUpdateRemainingWaterDepletion(waterBody, total_pumping_water)

        temp_used_water = state.TempUsedWater + total_pumping_water -- get + update in one go
        state.TempUsedWater = temp_used_water                       -- update the state variable now

        -- this block will later be removed (it has duplicated is_temp_inactive - but it will be gone after comprehensive testing)
        if total_pumping_water > 0 then
            is_temp_inactive = state.TempInactive
            if is_temp_inactive then
                utils.profile_hits("waterbody_update.collectWaterUsageStats", "inactive and pumping")
                game.print(string.format("Warning: waterbody %s is inactive but total pumping water is %s - how?",
                    waterbodies.getFullNameForWaterBody(waterBody), total_pumping_water))
            end
        end
        if temp_used_water >= state.TempAvailableWater then
            is_temp_inactive = state.TempInactive -- grab this only after condition - this should happen not that often

            -- we call to deactivate if state is not inactive or if there is still some water being pumped
            -- the remaining pumps will be deactivated
            if not is_temp_inactive or total_pumping_water > 0 then
                state.TempInactive = true
                entities.deactivateWaterBodyPumps(waterBody.waterBodyId)
            end
        end
        -- end of waterbody_update.smallUpdateRemainingWaterDepletion(waterBody, total_pumping_water)
    end
end

function waterbody_update.signalOrphanedToPlayer(waterBody)
    local is_depleted = waterBody.waterBodyStateData.Depleted
    local depleted_msg = is_depleted and " depleted and " or " "
    return string.format("%s has been%sorphaned and is removed.", waterbodies.getFullNameForWaterBody(waterBody),
        depleted_msg)
end

function waterbody_update.getRemoveDepletedOrphaned()
    return settings.global["FluidArea-RemoveDepletedOrphaned"].value
end

function waterbody_update.waterBodyCleanup(waterBody)
    local to_remove = false
    local searchData = waterBody.searchData
    local finished = searchData.finished
    if waterbodies.isWaterBodyEmpty(waterBody) and finished then
        waterbodies.signalPerForce(waterBody, waterbodies.signalEmptyToPlayer)
        to_remove = true
    end

    local isOrphaned = waterbodies.isWaterBodyOrphaned(waterBody)

    local state = waterBody.waterBodyStateData

    if isOrphaned then
        state.OrphanedSecondsCount = state.OrphanedSecondsCount + utils.normalize_update_values_per_second(1)
        -- remove only unnamed waterbody types and after bigUpdates higher than their area
        -- also remove orphaned depleted waterbodies
        -- remove only if search is finished to account that we might not have the total area right yet
        local waterAreaData = waterBody.waterAreaData
        if (((waterbodies.WaterBodyTypeToNamesCollection[waterAreaData.WaterBodyType] == nil) and state.OrphanedSecondsCount > waterAreaData.TotalArea)
                or (waterbody_update.getRemoveDepletedOrphaned() and state.Depleted)) and finished then
            waterbodies.signalPerForce(waterBody, waterbody_update.signalOrphanedToPlayer)
            to_remove = true
        end
    else
        state.OrphanedSecondsCount = 0
    end
    if to_remove then
        entities.disablePumpsAndRemoveWaterBody(waterBody)
    end
end

function waterbody_update.updateWaterBody(waterBody, updateBudget)
    local state_data = waterBody.waterBodyStateData
    if state_data.ToCalculate then
        waterbodies.CalculateAndUpdateWaterBodyAreaData(waterBody)
    end
    if state_data.ToUpdate and waterBody.searchData.finished then
        waterbody_scan.signalCreatedOrUpdated(waterBody)
    end

    waterbody_update.bigUpdateWaterLevel(waterBody)
    waterbody_update.handleDepletion(waterBody)
    waterbody_update.createMapMarker(waterBody)

    -- cleanup - similarly to scanning loop can remove/invalidate this waterbody
    -- but not other waterbodies
    -- since this is the last function we dont need to check validity after it
    waterbody_update.waterBodyCleanup(waterBody)
end

function waterbody_update.updateWaterBodies(updateBudget)
    local validWaterBodies = waterbodies.getValidWaterBodies()
    local validWaterBodiesArray = {}
    -- need to iterate over copy of validWaterBodies as current waterbody may be removed during update
    for _, waterBody in pairs(validWaterBodies) do
        validWaterBodiesArray[#validWaterBodiesArray + 1] = waterBody
    end

    for _, waterBody in ipairs(validWaterBodiesArray) do
        -- no need to check validity here: waterBodyCleanup in updateWaterBody can only remove current waterbody
        waterbody_update.updateWaterBody(waterBody, updateBudget)
    end
end

-- Move tiles into the newBinset dynamic binset.
-- From: pendingTiles queue, old binsets (these 2 in requestNewBinsetUpdate)
-- and from backfill of newBinset if front is not active
-- Validates each tile still belongs to this water body as water.
-- Returns number of tiles moved (used to deduct update budget outside).
function waterbody_update.binsetMaintenance(waterBody, gridsData, max_to_move)
    local success = waterbodies.ensureAndUpdateBinset(waterBody)
    if not success then return 0 end

    local oldBinsets = gridsData.oldBinsets
    local newBinset = gridsData.newBinset
    local pendingTiles = gridsData.pendingTiles

    if max_to_move <= 0 then return 0 end

    local moved = 0

    -- Fast references for validation/lookups
    local waterGridWithData = gridsData.waterGridWithData
    local pending_tiles_enqueue, _ = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(false)
    
    local dynamic_bins_backfill_consume = dynamic_bins.backfill_consume

    if #oldBinsets == 0 and newBinset.total <= 0 and pendingTiles.size == 0 then
        -- theoretically there is no water tiles (under these conditions)
        -- check against the truth if that's the case
        -- and if there is some water tiles - re-prime pending tiles
        -- only look at waterGridWithData
        -- and specifically not at lazyWaterGridWithData
        -- because it will use callbacks on-copy to add to pending tiles
        local gridKey

        while moved < max_to_move do
            gridKey, _ = next(waterGridWithData, gridKey)
            if gridKey == nil then
                -- no more tiles - break
                break
            end
            pending_tiles_enqueue(pendingTiles, gridKey)
            moved = moved + 1
        end
    end

    local searchFinished = waterBody.searchData.finished
    moved = moved + waterbody_depletion.requestNewBinsetUpdate(gridsData, max_to_move - moved, searchFinished, 0.5)

    if moved < max_to_move then
        -- attempt to fix backfill on the current binset
        moved = moved + dynamic_bins_backfill_consume(newBinset, max_to_move - moved, false)
    end

    return moved
end

function waterbody_update.get_work_amount(updateBudget, work_left, cost_per_work_unit, budget_per_work_unit)
    local work_amount = math.min(work_left, updateBudget.budget / budget_per_work_unit) / cost_per_work_unit
    return work_amount
end

function waterbody_update.update_work_amount(updateBudget, work_left, cost_per_work_unit, budget_per_work_unit, work_done)
    local value_of_work_done = work_done * cost_per_work_unit
    local budget = updateBudget.budget - value_of_work_done * budget_per_work_unit
    updateBudget.budget = budget
    work_left = work_left - work_done
    local finished = work_left <= 0 or budget <= 0
    return work_left, finished
end

function waterbody_update.extraWorkUpdateWaterBody(waterBody, updateBudget, maxExtraWork, update_budget_per_move)
    local work_left = maxExtraWork
    local work_amount, finished, work_done = 0, false, 0

    local gridsData = waterBody.gridsData

    -- multiple conditions: pending tiles, old binsets & search finished, backfill consumption - handled inside call
    local cost_of_adding_pending_tile = 1
    work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_adding_pending_tile,
        update_budget_per_move)

    -- move pending tiles to new binset (no lazy tables here)
    work_done = waterbody_update.binsetMaintenance(waterBody, gridsData, work_amount)

    work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left, cost_of_adding_pending_tile,
        update_budget_per_move, work_done)
    if finished then return end


    local surfaceName = waterBody.surface.name
    local waterBodyRef = storage.WaterBodyRef[waterBody.waterBodyId]

    local function callback_dry(gridKey, tileData)
        waterbodies.replaceWithNewRef(gridKey, waterBodyRef, surfaceName)
    end

    local extra_data_array
    local lazyDriedTilesGridWithData = gridsData.lazyDriedTilesGridWithData

    if #lazyDriedTilesGridWithData > 0 then
        local cost_of_dried_lazy_to_grid = 2
        work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_dried_lazy_to_grid,
            update_budget_per_move)

        -- move lazy dried tiles grid to dried tiles grid
        work_done, extra_data_array = utils.LazyTables.moveLazyTables(gridsData.driedTilesGridWithData,
            lazyDriedTilesGridWithData, work_amount, work_amount, false, callback_dry)

        if utils.LazyTables.wasAnyTableEmptied(extra_data_array) then
            waterbodies.removeOldRefs(waterBody, surfaceName)
        end

        work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left, cost_of_dried_lazy_to_grid,
            update_budget_per_move, work_done)

        if finished then return end
    end

    local pendingTiles = gridsData.pendingTiles
    -- callback for water tiles includes pendingTiles
    -- dried tiles will instead be joined on the driedStack
    local function callback_water(gridKey, tileData)
        waterbodies.replaceWithNewRef(gridKey, waterBodyRef, surfaceName)
        utils.Queue.deduplicate_enqueue(pendingTiles, gridKey)
    end

    local lazyWaterGridWithData = gridsData.lazyWaterGridWithData
    if #lazyWaterGridWithData > 0 then
        local cost_of_water_lazy_to_grid = 2.5
        work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_water_lazy_to_grid,
            update_budget_per_move)

        -- move lazy water grid to water grid
        work_done, extra_data_array = utils.LazyTables.moveLazyTables(gridsData.waterGridWithData, lazyWaterGridWithData,
            work_amount, work_amount, false, callback_water)

        if utils.LazyTables.wasAnyTableEmptied(extra_data_array) then
            waterbodies.removeOldRefs(waterBody, surfaceName)
        end

        work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left, cost_of_water_lazy_to_grid,
            update_budget_per_move, work_done)

        if finished then return end
    end

    local lazyDriedStack = gridsData.lazyDriedStack
    local enqueue, dequeue

    if #lazyDriedStack > 0 then
        local cost_of_dried_stack_to_grid = 1.5
        work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_dried_stack_to_grid,
            update_budget_per_move)

        enqueue, dequeue = waterbodies.getDriedStackOrPendingTilesEnqueueAndDequeue(true)
        -- move lazy dried stack to dried stack
        work_done, extra_data_array = utils.LazyTables.moveLazyTables(gridsData.driedStack, lazyDriedStack, work_amount,
            work_amount, true, nil, enqueue, dequeue)

        work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left, cost_of_dried_stack_to_grid,
            update_budget_per_move, work_done)

        if finished then return end
    end

    local lazyEdgeGrid = gridsData.lazyEdgeGrid

    if #lazyEdgeGrid > 0 then
        local cost_of_edge_grid_to_grid = 1.0
        work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_edge_grid_to_grid,
            update_budget_per_move)
        -- move lazy edge grid to edge grid
        work_done, extra_data_array = utils.LazyTables.moveLazyTables(gridsData.edgeGrid, lazyEdgeGrid, work_amount,
            work_amount, false, nil)

        work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left, cost_of_edge_grid_to_grid,
            update_budget_per_move, work_done)

        if finished then return end
    end

    local searchData = waterBody.searchData
    local lazySearchQueue = searchData.lazySearchQueue

    if #lazySearchQueue > 0 then
        local cost_of_search_queue_to_search_queue = 1.33
        work_amount = waterbody_update.get_work_amount(updateBudget, work_left, cost_of_search_queue_to_search_queue,
            update_budget_per_move)

        enqueue, dequeue = waterbodies.getSearchQueueEnqueueAndDequeue(searchData.searchQueue)
        -- move lazy search queue to search queue
        work_done, extra_data_array = utils.LazyTables.moveLazyTables(searchData.searchQueue, lazySearchQueue,
            work_amount, work_amount, true, nil, enqueue, dequeue)

        work_left, finished = waterbody_update.update_work_amount(updateBudget, work_left,
            cost_of_search_queue_to_search_queue, update_budget_per_move, work_done)

        if finished then return end
    end
end

function waterbody_update.getExtraWorkAmount()
    return utils.normalize_update_values_per_second(storage.MaxExtraWorkPerSecond, true,
        storage.PeriodicTicksPerExtraWorkUpdate)
end

function waterbody_update.prepareUpdateConditionFunc(waterBody)
    local gridsData = waterBody.gridsData
    -- if any of lazy arrays is not empty, we need to update it
    if #gridsData.lazyWaterGridWithData > 0 or #gridsData.lazyDriedTilesGridWithData > 0 or #gridsData.lazyEdgeGrid > 0 or #waterBody.searchData.lazySearchQueue > 0 or #gridsData.lazyDriedStack > 0 then
        return true
    end

    local pendingTiles = gridsData.pendingTiles
    local oldBinsets = gridsData.oldBinsets
    if pendingTiles.size > 0 or #oldBinsets > 0 then
        return true
    end
    local newBinset = gridsData.newBinset
    if newBinset and (newBinset.total == 0 or #newBinset.backfill > 0) then
        return true
    end
    return false
end

function waterbody_update.prepareToDryTilesUpdateConditionFunc(waterBody)
    local state = waterBody.waterBodyStateData
    if state.ToDryTiles ~= 0 then
        return true
    end
    return false
end

function waterbody_update.extraWorkUpdate(updateBudget)
    -- TODO: capture ToDryTiles and make them a priority
    -- Each waterbody with ToDryTiles should calculate how much tiles
    -- it has to dry per each work update (need to know how many work updates before next big update)
    -- so that it for sure can process quite evenly all ToDryTiles before the next big update
    -- only after that it should process other work if budgets allow
    -- preferably a separate function and filter for this before surfaces even?
    -- if the work wouldn't be enough then increase past budgets to get it done evenly
    -- need to capture how many more work updates are there before next big update

    local update_budget_per_move = 1 / 100
    local initial_work_weight = 0
    local work_weight_per_surface = 1
    local lazyOrphanedDryTilesOriginalName = storage.lazyOrphanedDryTilesOriginalName
    local surfaces_to_work_on = {}
    -- check every surface
    for surface_name, lazyArray in pairs(lazyOrphanedDryTilesOriginalName) do
        if #lazyArray > 0 then
            surfaces_to_work_on[surface_name] = true
            initial_work_weight = initial_work_weight + work_weight_per_surface
        end
    end

    local working_waterbodies_array, work_amount_per_waterbody_weight = waterbody_scan
    .prepareDistributedBudgetUpdateForValidWaterBodies(waterbody_update.getExtraWorkAmount(), updateBudget,
        waterbody_update.prepareUpdateConditionFunc, initial_work_weight)
    if working_waterbodies_array == nil or work_amount_per_waterbody_weight == nil then
        return
    end

    -- first update orphaned dry tiles
    for surface_name, _ in pairs(surfaces_to_work_on) do
        local lazyArray = lazyOrphanedDryTilesOriginalName[surface_name]
        local work_amount = math.ceil(work_weight_per_surface * work_amount_per_waterbody_weight)
        local moved, extra_data_array = utils.LazyTables.moveLazyTables(
        storage.OrphanedDryTilesOriginalName[surface_name], lazyArray, work_amount, work_amount, false, nil)
        updateBudget.budget = updateBudget.budget - (moved * update_budget_per_move)
        if updateBudget.budget <= 0 then
            break
        end
    end

    for _, waterBody in ipairs(working_waterbodies_array) do
        local work_amount = math.ceil(waterBody.searchData.ScanWeight * work_amount_per_waterbody_weight)
        waterbody_update.extraWorkUpdateWaterBody(waterBody, updateBudget, work_amount, update_budget_per_move)
        if updateBudget and updateBudget.budget <= 0 then
            break
        end
    end
end
