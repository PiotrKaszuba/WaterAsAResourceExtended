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

    local text = "Pending..."
    local icon = {type = "fluid", name = "water"}
    local percent = waterbodies.calculatePercentageWaterUsed(waterBody)
    local depleted = waterBody.waterBodyStateData.Depleted

    if waterBody.searchData.finished and not depleted then
        local remaining = math.ceil(waterBody.waterAreaData.AmountWtr * (100 - percent) / 100)
        text = string.format("%s - %s - %.2f %%", waterbodies.getFullNameForWaterBody(waterBody), utils.comma_value(remaining), 100 - percent)
    elseif waterBody.searchData.finished and depleted then
        text = string.format("%s - Depleted", waterbodies.getFullNameForWaterBody(waterBody))
    end

    for force_name, _ in pairs(waterBody.entitiesData.forces) do
        local marker = waterBody.waterBodyStateData.MapMarkers[force_name]
        local force = game.forces[force_name]
        local position = nil
        if force_to_pump[force_name] then
            position = force_to_pump[force_name].input_position
            -- fix position to left-top corner
            local tile = utils.GetTile(position, waterBody.surfaceId)
            position = tile.position
        else
            local _, tileData = next(waterBody.gridsData.waterGridWithData)
            if not tileData or not tileData.position then
                game.print(string.format("Warning: no position found for waterbody %s and force %s", waterbodies.getFullNameForWaterBody(waterBody), force_name))
                break
            end
            position = tileData.position
        end
        
        if not marker or not marker:valid() then
            marker = waterbodies.MapMarker:new(force, waterBody.surfaceId, position, text, icon)
            waterBody.waterBodyStateData.MapMarkers[force_name] = marker
        else
            marker:update(position, text, icon)
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

function waterbody_update.getWaterUsageStatsForPump(pump_data)
	local water_usage = 0
    if pump_data.entity.valid and pump_data.entity.active then
        water_usage = pump_data.entity.pumped_last_tick
        local force_data = forces.getPlayerForce(pump_data.forceName)
        if force_data then
            water_usage = water_usage * force_data.water_usage_multiplier
        end
    end

    -- estimation of the water usage between ticks
    -- i.e. if we sample pumped value every 10 ticks we assume
    -- that it was the average value over these 10 ticks and calculate the total usage
    water_usage = water_usage * storage.PeriodicEveryXTicks
    
	return water_usage
end

function waterbody_update.collectWaterUsageStatsForWaterBody(waterBodyId)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if not waterBody or not waterBody.valid then return end
	local total_pumping_water = 0
	for unit_number, _ in pairs(waterBody.entitiesData.pumps) do
		local pump_data = entities.getTrackedEntity(unit_number)
		local pumpUsage = waterbody_update.getWaterUsageStatsForPump(pump_data)
		total_pumping_water = total_pumping_water + pumpUsage
	end
	return total_pumping_water
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
    if percentUsed >= 100 and not state.Depleted then
        waterbody_update.waterBodyDepleted(waterBody)
    elseif percentUsed < waterbody_update.getPumpsReactivationLevelPerThousand() / 10 and state.Depleted then
        waterbody_update.waterBodyRestored(waterBody)
    end

    waterbody_update.handleDepletionAlarms(waterBody, percentUsed)
    waterbody_depletion.updateDepletionAppearance(waterBody)
end

function waterbody_update.smallUpdateRemainingWaterDepletion(waterBody, waterbody_total_pumping_water)
	local state = waterBody.waterBodyStateData
    state.TempUsedWater = state.TempUsedWater + waterbody_total_pumping_water
    if state.Depleted and waterbody_total_pumping_water > 0 then
        game.print(string.format("Warning: waterbody %s is depleted but total pumping water is %s - how?", waterbodies.getFullNameForWaterBody(waterBody), waterbody_total_pumping_water))
    end
    if state.TempUsedWater >= state.TempAvailableWater then
        -- we call depleted if state is not depleted or if there is still some water being pumped
        -- the remaining pumps will be deactivated by the depletion handler
        if not state.Depleted or waterbody_total_pumping_water > 0 then
            waterbody_update.waterBodyDepleted(waterBody)
        end
    end

end

function waterbody_update.collectWaterUsageStats(loop_tick)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        local waterbody_total_pumping_water = waterbody_update.collectWaterUsageStatsForWaterBody(id)
		local waterbody = waterbodies.getWaterBody(id)
        waterbody_update.smallUpdateRemainingWaterDepletion(waterbody, waterbody_total_pumping_water)
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

function waterbody_update.updateWaterBody(waterBodyId, updateBudget)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
    
	if not waterBody or not waterBody.valid then return end

	waterbody_scan.scanningLoop(waterBodyId, updateBudget)
	waterbody_update.bigUpdateWaterLevel(waterBody)
	waterbody_update.handleDepletion(waterBody)
	waterbody_update.createMapMarker(waterBody)
    waterbody_update.waterBodyCleanup(waterBody)
end

function waterbody_update.updateWaterBodies(updateBudget)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        waterbody_update.updateWaterBody(id, updateBudget)
    end
end