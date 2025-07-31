require("waterbodies")
require("waterbody_scan")

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
    local waterUsageTickStats = waterBody.waterUsageTickStats
    if not waterUsageTickStats then return 0 end

    local total_pumping_water = 0
    for _, waterUsage in ipairs(waterUsageTickStats) do
        total_pumping_water = total_pumping_water + waterUsage
    end

    total_pumping_water = total_pumping_water * storage.PeriodicEveryXTicks

    return total_pumping_water
end

function waterbody_update.calculateEffectiveRegenAmount(waterBody)
	-- Placeholder for regen calculation
	local regen_base = waterBody.waterAreaData.RegenAmount * 60 -- regen per second
    local missing_water_percentage = waterbodies.calculatePercentageWaterUsed(waterBody)/100
    -- best regen is at 75% missing water -> 150%
    -- at 100% missing water, regen is at 50% and at 0% missing water, regen is at 75%
    local multiplier = 0.75
    if missing_water_percentage > 0.75 then
        multiplier = 1.5 - (missing_water_percentage - 0.75) * 4
    else
        multiplier = 0.75 + (0.75 - missing_water_percentage) * 1
    end
    local regen_with_bonus = regen_base * multiplier
    return regen_with_bonus
end

function waterbody_update.getWaterUsageStatsForPump(pump_data)
	local pumped_last_tick = 0
    if pump_data.entity.valid and pump_data.entity.active then
        pumped_last_tick = pump_data.entity.pumped_last_tick
        local force_data = forces.getPlayerForce(pump_data.forceName)
        if force_data then
            pumped_last_tick = pumped_last_tick * force_data.water_usage_multiplier
        end
    end
    
	return pumped_last_tick
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
	waterbody_scan.scanningLoop(waterBodyId, updateBudget)
	local waterUsedChange = waterbody_update.calculateWaterUsage(waterBody) 
	local regen = waterbody_update.calculateEffectiveRegenAmount(waterBody) --includes bonuses
	waterbody_update.updateWaterLevel(waterBody, waterUsedChange, regen)
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