require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.waterbody_depletion")
require("modules.entities")
require("modules.utils")

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

    local icon = {type = "fluid", name = "water"}
    local percent = waterbodies.calculatePercentageWaterUsed(waterBody)
    local depleted = waterBody.waterBodyStateData.Depleted

    local surface = waterBody.surface
    local remaining = math.ceil(waterBody.waterAreaData.AmountWtr * (100 - percent) / 100)
    
    local text = string.format("%s - %s - %.2f %%", waterbodies.getFullNameForWaterBody(waterBody), utils.comma_value(remaining), 100 - percent)
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
            -- fix position to left-top corner
            local tile = utils.GetTile(position, surface)
            position = tile.position
        else
            local _, tileData = next(waterBody.gridsData.waterGridWithData)
            if not tileData or not tileData.position then
                game.print(string.format("Warning: no position found for waterbody %s and force %s", waterbodies.getFullNameForWaterBody(waterBody), force_name))
                break
            end
            position = tileData.position
        end
        
        if not marker or not utils.MapMarker.valid(marker) then
            marker = utils.MapMarker.new(player_force.force, surface, position, text, icon)
            waterBody.waterBodyStateData.MapMarkers[force_name] = marker
        else
            utils.MapMarker.update(marker, position, text, icon)
        end
    end
end

function waterbody_update.getLowLevelAlarms()
    if settings.global["Alarms-Low-Level"].value then
        return {
            {50, "Fired50"}, {75, "Fired75"}, {90, "Fired90"} 
        }
    end
    return {}
end

function waterbody_update.getHighLevelAlarms()
    if settings.global["Alarms-High-Level"].value then
        return {
            {95, "Fired95"}, {97, "Fired97"}, {98, "Fired98"}, {99, "Fired99"}
        }
    end
    return {}
end

function waterbody_update.signalDepletionToPlayer(waterBody)
    return string.format("%s has been depleted.", waterbodies.getFullNameForWaterBody(waterBody))
end

function waterbody_update.signalAlarmToPlayer(waterBody, force, percentUsed)
    return string.format("%s has used %.0f%% of available water.", waterbodies.getFullNameForWaterBody(waterBody), percentUsed)
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
            elseif percentUsed < (threshold - 1) and state[flag] then  -- -1 is a hysteresis to avoid flickering
                state[flag] = false -- Reset flag if level drops below threshold
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
	local regen = regenAmount or 0
    
    local totalWaterUsed = waterbodies.calculateTotalWaterUsed(waterBody)

	local regen = math.max(0, math.min(regen, totalWaterUsed)) -- this ensures that regen is not greater than the water used and positive
	
    local remainingWaterUsedPenalty = math.max(0, state.WaterUsedPenalty - state.WaterUsedPenaltyRestored)
    local regen1 = math.min(state.WaterUsed, regen)
    local regen2 = math.max(0, math.min(regen - regen1, remainingWaterUsedPenalty)) -- this ensures that regen is not greater than the water used penalty and positive
    
    state.WaterUsed = state.WaterUsed - regen1
    state.WaterUsedPenaltyRestored = state.WaterUsedPenaltyRestored + regen2

    state.TempAvailableWater = state.TempAvailableWater - waterUsedChange + (regen1 + regen2)
end

function waterbody_update.calculateEffectiveRegenAmount(waterBody)
	-- Placeholder for regen calculation
	local regen_base = utils.normalize_values_per_second(waterBody.waterAreaData.RegenAmount)
    local missing_water_percentage = waterbodies.calculatePercentageWaterUsed(waterBody)/100
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
    waterbody_depletion.updateDepletionAppearance(waterBody)
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
        state.TempUsedWater = temp_used_water -- update the state variable now
    
        -- this block will later be removed (it has duplicated is_temp_inactive - but it will be gone after comprehensive testing)
        if total_pumping_water > 0 then
            is_temp_inactive = state.TempInactive
            if is_temp_inactive then
                utils.profile_hits("waterbody_update.collectWaterUsageStats", "inactive and pumping")
                game.print(string.format("Warning: waterbody %s is inactive but total pumping water is %s - how?", waterbodies.getFullNameForWaterBody(waterBody), total_pumping_water))
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
    local depleted_msg = is_depleted and " depleted and " or ""
    return string.format("%s has been %s orphaned and is removed.", waterbodies.getFullNameForWaterBody(waterBody), depleted_msg)
end

function waterbody_update.getRemoveDepletedOrphaned()
    return settings.global["FluidArea-RemoveDepletedOrphaned"].value
end

function waterbody_update.waterBodyCleanup(waterBody)
    local isOrphaned = waterbodies.isWaterBodyOrphaned(waterBody)

    local state = waterBody.waterBodyStateData

    if isOrphaned then
        state.OrphanedSecondsCount = state.OrphanedSecondsCount + utils.normalize_values_per_second(1)
        -- remove only unnamed waterbody types and after bigUpdates higher than their area
        if ((waterbodies.WaterBodyTypeToNamesCollection[waterBody.waterAreaData.WaterBodyType] == nil) and state.OrphanedSecondsCount > waterBody.waterAreaData.TotalArea)
            or (waterbody_update.getRemoveDepletedOrphaned() and state.Depleted) then
            
            waterbodies.signalPerForce(waterBody, waterbody_update.signalOrphanedToPlayer)
            waterbodies.removeWaterBody(waterBody)
        end
    else
        state.OrphanedSecondsCount = 0
    end
end

function waterbody_update.updateWaterBody(waterBody, updateBudget)
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
    -- need to iterate over copy of validWaterBodies
    -- scanning loop can remove/invalidate current waterbody 
    -- or any other waterbody - so removes it from storage.ValidWaterBodies
    -- have to maintain a seprately created copy of valid waterbodies
    -- because iteration over storage.ValidWaterBodies is not safe
    for _, waterBody in pairs(validWaterBodies) do
        validWaterBodiesArray[#validWaterBodiesArray + 1] = waterBody
    end
    
    -- first run the disruptive scanning loop
    -- we do it before all other updates because if merge happened
    -- that removes waterbody after it has been update - i.e. regen applied per tile
    -- it could be that another waterbody would have applied regen from the same tiles
    -- there may be other cases where this is a problem too - the above is enough for separate initial loop
    for _, waterBody in ipairs(validWaterBodiesArray) do
        -- need validity check here - because scanning loop can remove/invalidate this waterbody
        if waterBody.valid then
            waterbody_scan.scanningLoop(waterBody, updateBudget)
        end
    end

    -- then run the rest of the updates - but we need to collect validWaterBodiesArray again
    validWaterBodiesArray = {}
    for _, waterBody in pairs(validWaterBodies) do
        validWaterBodiesArray[#validWaterBodiesArray + 1] = waterBody
    end

    for _, waterBody in ipairs(validWaterBodiesArray) do
        -- no need to check validity here:
        -- iterating new array of valid waterbodies
        -- and waterBodyCleanup in updateWaterBody can only remove current waterbody - not others
        -- so we can safely proceed with the valid waterbodies loop
        waterbody_update.updateWaterBody(waterBody, updateBudget)
    end
end