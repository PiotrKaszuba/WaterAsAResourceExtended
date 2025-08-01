require("modules.waterbodies")
require("modules.waterbody_scan")
require("modules.waterbody_depletion")
require("modules.entities")

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
        text = string.format("%s - %s - %.2f %%", waterBody.waterBodyName, utils.comma_value(remaining), 100 - percent)
    elseif waterBody.searchData.finished and depleted then
        text = string.format("%s - Depleted", waterBody.waterBodyName)
    end

    for force_name, _ in pairs(waterBody.entitiesData.forces) do
        local marker = waterBody.waterBodyStateData.MapMarkers[force_name]
        local force = game.forces[force_name]
        local position = nil
        if force_to_pump[force_name] then
            position = force_to_pump[force_name].input_position
        else
            local _, tileData = next(waterBody.gridsData.waterGridWithData)
            if not tileData or not tileData.position then
                game.print(string.format("Warning: no position found for waterbody %s and force %s", waterBody.waterBodyName, force_name))
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

function waterbody_update.signalDepletionToPlayer(waterBody, force, player_idx)
    force.players[player_idx].print(string.format("%s has been depleted.", waterBody.waterBodyName or "Water body"))
end

function waterbody_update.signalAlarmToPlayer(waterBody, force, player_idx, alarm_type)
    force.players[player_idx].print(string.format("%s has used %.0f%% of available water.", waterBody.waterBodyName or "Water body", percentUsed))
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
            waterbodies.signalPerPlayer(waterBody, waterbody_update.signalAlarmToPlayer)
        end
    end
end

function waterbody_update.bigUpdateWaterLevel(waterBody, waterUsedChange, regenAmount)
	local state = waterBody.waterBodyStateData
	state.WaterUsedPrev = state.WaterUsed
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



function waterbody_update.calculateWaterUsage(waterBody)
    -- it just sums up the tick stats - the estimation between ticks 
    -- is done getWaterUsageStatsForPump by multiplying by storage.PeriodicEveryXTicks
    local waterUsageTickStats = waterBody.waterUsageTickStats
    if not waterUsageTickStats then return 0 end

    local total_pumping_water = 0
    for _, waterUsage in ipairs(waterUsageTickStats) do
        total_pumping_water = total_pumping_water + waterUsage
    end

    return total_pumping_water
end

function waterbody_update.calculateEffectiveRegenAmount(waterBody)
	-- Placeholder for regen calculation
	local regen_base = waterBody.waterAreaData.RegenAmount * (storage.LoopNumTicks * storage.PeriodicEveryXTicks) / 60
    local missing_water_percentage = waterbodies.calculatePercentageWaterUsed(waterBody)/100
    -- best regen is at 75% missing water -> 150%
    -- at 100% missing water, regen is at 50% and at 0% missing water, regen is at 75%
    local multiplier = 0.75
    if missing_water_percentage > 0.75 then
        multiplier = math.max(math.min(1.5 - (missing_water_percentage - 0.75) * 4, 1.5), 0.5)
    else
        multiplier = math.max(math.min(0.75 + (0.75 - missing_water_percentage) * 1, 1.5), 0.5)
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

function waterbody_update.updateWaterUsageTickStats(waterbody, loop_tick, waterbody_total_pumping_water)
	if loop_tick == 0 or not waterbody.waterUsageTickStats then
		waterbody.waterUsageTickStats = waterbodies.initWaterUsageTickStats()
	end
	waterbody.waterUsageTickStats[loop_tick + 1] = waterbody_total_pumping_water
end

function waterbody_update.waterBodyDepleted(waterBody)
    local state = waterBody.waterBodyStateData
    state.Depleted = true
    entities.deactivateWaterBodyPumps(waterBody.waterBodyId)
    waterbodies.signalPerPlayer(waterBody, waterbody_update.signalDepletionToPlayer)
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
    if not state.Depleted then
        state.TempUsedWater = state.TempUsedWater + waterbody_total_pumping_water
        if state.TempUsedWater >= state.TempAvailableWater then
            waterbody_update.waterBodyDepleted(waterBody)
        end
    elseif waterbody_total_pumping_water > 0 then
        game.print("Warning: waterbody_total_pumping_water > 0 but waterbody is depleted")
    end
end

function waterbody_update.collectWaterUsageStats(loop_tick)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        local waterbody_total_pumping_water = waterbody_update.collectWaterUsageStatsForWaterBody(id)
		local waterbody = waterbodies.getWaterBody(id)
		waterbody_update.updateWaterUsageTickStats(waterbody, loop_tick, waterbody_total_pumping_water)
        waterbody_update.smallUpdateRemainingWaterDepletion(waterbody, waterbody_total_pumping_water)
    end
end

function waterbody_update.signalOrphanedToPlayer(waterBody, force, player_idx)
    local is_depleted = waterBody.waterBodyStateData.Depleted
    local depleted_msg = is_depleted and " depleted and " or ""
    force.players[player_idx].print(string.format("%s has been %s orphaned and is removed.", waterBody.waterBodyName or "Water body", depleted_msg))
end

function waterbody_update.getRemoveDepletedOrphaned()
    return settings.global["FluidArea-RemoveDepletedOrphaned"].value
end

function waterbody_update.waterBodyCleanup(waterBody)
    local isOrphaned = waterbodies.isWaterBodyOrphaned(waterBody)

    local state = waterBody.waterBodyStateData

    if isOrphaned then
        state.OrphanedBigUpdateCount = state.OrphanedBigUpdateCount + 1
        -- remove only unnamed waterbody types and after bigUpdates higher than their area
        if ((waterbodies.WaterBodyTypeToNamesCollection[waterBody.waterAreaData.WaterBodyType] == nil) and state.OrphanedBigUpdateCount > waterBody.waterAreaData.TotalArea)
            or (waterbody_update.getRemoveDepletedOrphaned() and state.Depleted) then
            
            waterbodies.signalPerPlayer(waterBody, waterbody_update.signalOrphanedToPlayer)
            waterbodies.removeWaterBody(waterBody)
        end
    else
        state.OrphanedBigUpdateCount = 0
    end
end

function waterbody_update.updateWaterBody(waterBodyId, updateBudget)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
    
	if not waterBody or not waterBody.valid then return end

	waterbody_scan.scanningLoop(waterBodyId, updateBudget)
	local waterUsedChange = waterbody_update.calculateWaterUsage(waterBody) 
	local regen = waterbody_update.calculateEffectiveRegenAmount(waterBody) --includes bonuses
	waterbody_update.bigUpdateWaterLevel(waterBody, waterUsedChange, regen)
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