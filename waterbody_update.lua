require("waterbodies")

waterbody_update = {}

function waterbody_update.createMapMarker(waterBody)
	local mapMarker = waterBody.mapMarker
	if mapMarker then
		mapMarker.destroy()
	end
	-- TODO: Implement
end

function waterbody_update.handleDepletionAlarms(waterBody, percentUsed)
    local state = waterBody.waterBodyStateData

    -- Handle depletion state
    if percentUsed >= 100 and not state.Depleted then
        state.Depleted = true
        for forceName, _ in pairs(waterBody.entitiesData.forces) do
            game.forces[forceName].print(string.format("%s has been depleted.", waterBody.waterBodyName or "Water body"))
        end
    elseif percentUsed < 100 and state.Depleted then
        state.Depleted = false
    end

    -- Handle alarms
    if not state.Depleted then
        local alarms = {
            {50, "Fired50"}, {75, "Fired75"}, {90, "Fired90"}, 
            {95, "Fired95"}, {97, "Fired97"}, {98, "Fired98"}, {99, "Fired99"}
        }
        for _, alarm in ipairs(alarms) do
            local threshold, flag = table.unpack(alarm)
            if percentUsed >= threshold and not state[flag] then
                for forceName, _ in pairs(waterBody.entitiesData.forces) do
                    game.forces[forceName].print(string.format("%s has used %.0f%% of available water.", waterBody.waterBodyName or "Water body", percentUsed))
                end
                state[flag] = true
            elseif percentUsed < threshold and state[flag] then
                state[flag] = false -- Reset flag if level drops below threshold
            end
        end
    end
end


function waterbody_update.updateWaterLevel(waterBody, waterUsedChange, regenAmount)
	local state = waterBody.waterBodyStateData
	state.WaterUsedPrev = state.WaterUsed
	-- Do not clamp water used to be within bounds - the bound violations should be still handled by depletion
	-- and they might be present to be made up for by the natural regeneration or drainage, etc.
	-- we will only limit natural regeneration not to occur if it would go below 0
	state.WaterUsed = state.WaterUsed + waterUsedChange
	local regen = regenAmount or 0
	regen = math.max(0, math.min(regen, state.WaterUsed)) -- this ensures that regen is not greater than the water used and positive
	state.WaterUsed = state.WaterUsed - regen


	local percentUsed = waterbodies.calculatePercentageWaterUsed(waterBody)
    waterbody_update.handleDepletionAlarms(waterBody, percentUsed)
end



function waterbody_update.calculateWaterUsage(waterBody)
	-- Way1: implement estimation of the water usa on the tick stats
	-- Way2: get production stats from the pump prototypes appropriate for each force - impossible actually
	
	-- local forces = waterBody.entitiesData.forces

	-- for forceName, _ in pairs(forces) do
	-- 	local game_force = forces.getGameForce(forceName)
	-- 	local force_waterbody_id = forces.AddWaterbodyIfNotExists(forceName, waterBody.surfaceId, waterBody.waterBodyId).waterbody_force_id
	-- 	local prototype_name = entities.getActivePumpNameForForceWaterbodyId(force_waterbody_id)
	-- 	local fluid_production_statistics = game_force.get_fluid_production_statistics(waterBody.surfaceId)
	-- 	local water_production_stats = fluid_production_statistics.get_flow_count{name="water", category="input", precision_index=0, sample_index=300, count=true}
	-- end
	
	return 0
end

function waterbody_update.calculateEffectiveRegenAmount(waterBody)
	-- Placeholder for regen calculation
	return waterBody.waterAreaData.RegenAmount or 0
end

function waterbody_update.getWaterUsageStatsForPump(pump_data)
	-- TODO: Implement
	return 0
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
	if loop_tick == 0 then
		waterbody.waterUsageTickStats = waterbodies.initWaterUsageTickStats()
	end
	if not waterbody.waterUsageTickStats then
		waterbody.waterUsageTickStats = waterbodies.initWaterUsageTickStats()
	end
	waterbody.waterUsageTickStats[loop_tick + 1] = waterbody_total_pumping_water
end

function waterbody_update.collectWaterUsageStats(loop_tick)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        local waterbody_total_pumping_water = waterbody_update.collectWaterUsageStatsForWaterBody(id)
		local waterbody = waterbodies.getWaterBody(id)
		waterbody_update.updateWaterUsageTickStats(waterbody, loop_tick, waterbody_total_pumping_water)
    end
end

function waterbody_update.updateWaterBody(waterBodyId, updateBudget)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if not waterBody or not waterBody.valid then return end
	waterbodies.scanningLoop(waterBodyId, updateBudget)
	local waterUsedChange = waterbodies.calculateWaterUsage(waterBody) 
	local regen = waterbodies.calculateEffectiveRegenAmount(waterBody) --includes bonuses
	waterbodies.updateWaterLevel(waterBody, waterUsedChange, regen)
	waterbodies.updateDepletionAppearance(waterBody, updateBudget)
	waterbodies.createMapMarker(waterBody)
end

function waterbodies.updateWaterBodies(updateBudget)
	local validWaterBodies = waterbodies.getValidWaterBodies()
	if not validWaterBodies then return end
    for id, _ in pairs(validWaterBodies) do
        waterbodies.updateWaterBody(id, updateBudget)
    end
end