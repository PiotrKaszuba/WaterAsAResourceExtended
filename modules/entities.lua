require("modules.utils")
require("modules.waterbodies")

entities = {}

function entities.initTrackedEntities()
    storage.TrackedEntities = {} -- unit_number -> "entity_data" = {type = ("pump", "drain"), waterBodyId = int, force = <force_id>} and other fields
end

function entities.registerTrackedEntity(unit_number, entity_data)
    storage.TrackedEntities[unit_number] = entity_data
end

function entities.getTrackedEntity(unit_number)
    return storage.TrackedEntities[unit_number]
end

function entities.removeTrackedEntity(unit_number)
    storage.TrackedEntities[unit_number] = nil
end


entities.offshore_pump_prototype_type = "offshore-pump"
entities.offshore_drain_prototype_type = "offshore-drain"

function initNewPump(entity)
    local input_position = utils.calculate_direction_offset(entity.position, entity.direction)
    
    -- "pump_data"
    return {
        ["entity"] = entity,
        ["input_position"] = {["x"] = input_position.x, ["y"] = input_position.y},
        ["spritepos"] = {["x"] = entity.position.x, ["y"] = entity.position.y},
        ["surfaceName"] = entity.surface.name,
        ["direction"] = entity.direction,
        ["tileName"] = "water", -- Only water is supported now
        ["forceName"] = entity.force.name,

        ["type"] = "pump",

        ["waterBodyId"] = nil,

        ["disabled"] = false,
    }
end

function entities.registerPumpAndAddToWaterBody(waterBodyId, pump_data)
    entities.registerTrackedEntity(pump_data.entity.unit_number, pump_data)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if not (waterBody and waterBody.valid) then
        game.print("Error:Water body not found or invalid: " .. tostring(waterBodyId))
    else
        waterBody.entitiesData.pumps[pump_data.entity.unit_number] = true
        waterBody.entitiesData.forces[pump_data.forceName] = true
        pump_data.waterBodyId = waterBodyId
    end
end

function entities.removePumpFromWaterBody(unit_number, waterBodyId)
    if waterBodyId ~= nil then
        local waterBody = waterbodies.getWaterBody(waterBodyId)
        if waterBody and waterBody.valid then
            waterBody.entitiesData.pumps[unit_number] = nil
            waterbodies.updateWaterBodyForces(waterBody)
        end
    end
end

function entities.movePumpToWaterBody(unit_number, newWaterBodyId, oldWaterBodyId)
    local pump_data = entities.getTrackedEntity(unit_number)
    if not pump_data then
        game.print("Error: Pump not found: " .. tostring(unit_number))
        return
    end
    entities.registerPumpAndAddToWaterBody(newWaterBodyId, pump_data)
    entities.removePumpFromWaterBody(unit_number, oldWaterBodyId)
end


function entities.rejectEntityPlacement(entity, reason)
    if entity.last_user and entity.last_user.valid then
        entity.last_user.print(reason)
        entity.last_user.insert{name = entity.name, count = 1}
    end
    entity.destroy()
end


function entities.rejectOrDeactivatePump(pump, reason, do_not_reject)
    if not do_not_reject then
        entities.rejectEntityPlacement(pump.entity, reason)
    else
        entities.deactivatePump(pump)
    end
end




function entities.DestroyedPump(entity)
    local unit_number = entity.unit_number
    if not entities.getTrackedEntity(unit_number) then
        return -- Not a tracked entity
    end
    
    local entity_data = entities.getTrackedEntity(unit_number)

    local waterBodyId = entity_data.waterBodyId
    entities.removePumpFromWaterBody(unit_number, waterBodyId)
    
    entities.removeTrackedEntity(unit_number)
end


function entities.TeleportedPump(entity)
    -- it shouldn't happen - issue a warning and disable the pump
    game.print("Warning: a pump was teleported")
    local pump_data = entities.getTrackedEntity(entity.unit_number)
    if not pump_data then
        -- entity is not tracked - we still need to disable it and we need 'pump_data' for it
        pump_data = initNewPump(entity)
    end
    entities.disablePump(pump_data)
    entities.DestroyedPump(entity)
end




function entities.deactivatePump(pump_data)
    pump_data.entity.active = 0
end

function entities.disablePump(pump_data)
    -- disable means that it cannot be active
    entities.deactivatePump(pump_data)
    pump_data.disabled = true
end


function entities.activatePump(pump_data)
    -- activate only if it is not disabled
    if pump_data.disabled then
        return
    end
    pump_data.entity.active = 1
end

function entities.enablePump(pump_data)
    -- enable means that it can be active but not necessarily now
    pump_data.disabled = false
end

function entities.call_on_each_waterbody_pump(waterBody, func)
	local waterBody = waterbodies.getWaterBody(waterBodyId)
	if waterBody and waterBody.valid then
		for unit_number, _ in pairs(waterBody.entitiesData.pumps) do
			func(entities.getTrackedEntity(unit_number))
		end
	end
end

function entities.disableWaterBodyPumps(waterBodyId)
    entities.call_on_each_waterbody_pump(waterBodyId, entities.disablePump)
end

function entities.deactivateWaterBodyPumps(waterBodyId)
    entities.call_on_each_waterbody_pump(waterBodyId, entities.deactivatePump)
end

function entities.activateWaterBodyPumps(waterBodyId)
    entities.call_on_each_waterbody_pump(waterBodyId, entities.activatePump)
end

function entities.disablePumpsAndRemoveWaterBody(waterBody)
	entities.disableWaterBodyPumps(waterBody.waterBodyId)
    waterbodies.removeWaterBody(waterBody)
end

function entities.getActivePumpCount(waterBody)
    local count = 0
    for unit_number, _ in pairs(waterBody.entitiesData.pumps) do
        local pump_data = entities.getTrackedEntity(unit_number)
        if not pump_data.disabled and pump_data.entity.valid and pump_data.entity.active == 1 then
            count = count + 1
        end
    end
    return count
end

function entities.updatePumpStates()
    for unit_number, pump_data in pairs(storage.TrackedEntities) do
        if pump_data.type == "pump" then
            local waterBody = waterbodies.getWaterBody(pump_data.waterBodyId)
            local should_be_active = (
                waterBody and 
                waterBody.valid and 
                not waterBody.waterBodyStateData.Depleted and
                not pump_data.disabled and
                pump_data.entity.valid and
                pump_data.entity.neighbours[1] and pump_data.entity.neighbours[1][1] -- to double check if this is correct
            )
            
            if should_be_active then
                entities.activatePump(pump_data)
            else
                entities.deactivatePump(pump_data)
            end
        end
    end
end
