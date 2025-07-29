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

entities.waterfill_placer_to_water_tile = {
    ["waterfill-placer"] = "water-shallow",
    ["waterfill-placer-deep"] = "deepwater",
}

entities.offshore_pumps_names = {
    ["offshore-pump"] = true,
}

entities.offshore_drains_names = {
    ["offshore-drain"] = true,
}

function initNewPump(entity)
    local input_position = utils.calculate_direction_offset(entity.position, entity.direction)
    
    -- "pump_data"
    return {
        ["entity"] = entity,
        ["input_position"] = {["x"] = input_position.x, ["y"] = input_position.y},
        ["spritepos"] = {["x"] = entity.position.x, ["y"] = entity.position.y},
        ["surface"] = entity.surface,
        ["direction"] = entity.direction,
        ["tile"] = "water", -- Only water is supported now
        ["active"] = 0,
        ["waterBodyId"] = nil,
        ["force"] = entity.force.name,
        ["type"] = "pump",
    }
end


function entities.placerWater(placed)

    local replacement = entities.waterfill_placer_to_water_tile[placed.name]

    local dir     = placed.direction
    local pos     = placed.position
    local surface = placed.surface

    placed.destroy()
    local tileArray = {}
    local i = 1
	tileArray[i] = {
		name = replacement,
		position = {pos.x, pos.y}
	}
   
    surface.set_tiles(tileArray, true, true, true, true)
end

function entities.isWaterBodyOrphaned(waterBody)
    local hasPumps = next(waterBody.entitiesData.pumps) ~= nil
    return not hasPumps
end

function entities.updateWaterBodyForces(waterBody)
    waterBody.entitiesData.forces = {}
    for _, pump_data in pairs(waterBody.entitiesData.pumps) do
        waterBody.entitiesData.forces[pump_data.force] = true
    end
end

function entities.addNewPump(waterBodyId, pump_data)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if not waterBody then
        error("Water body not found: " .. tostring(waterBodyId))
    end
    waterBody.entitiesData.pumps[pump_data.entity.unit_number] = pump_data
    waterBody.entitiesData.forces[pump_data.force] = true
    pump_data.waterBodyId = waterBodyId
    entities.registerTrackedEntity(pump_data.entity.unit_number, pump_data)
end

function entities.movePumpToWaterBody(unit_number, newWaterBodyId, oldWaterBodyId)
    local pump_data = entities.getTrackedEntity(unit_number)
    if not pump_data then
        error("Pump not found: " .. tostring(unit_number))
    end
    local newWaterBody = waterbodies.getWaterBody(newWaterBodyId)
    if not newWaterBody then
        error("Water body not found: " .. tostring(newWaterBodyId))
    end
    newWaterBody.entitiesData.pumps[pump_data.entity.unit_number] = pump_data
    newWaterBody.entitiesData.forces[pump_data.force] = true
    pump_data.waterBodyId = newWaterBodyId

    if oldWaterBodyId ~= nil then
        local oldWaterBody = waterbodies.getWaterBody(oldWaterBodyId)
        if oldWaterBody and oldWaterBody.valid then
            oldWaterBody.entitiesData.pumps[pump_data.entity.unit_number] = nil
            entities.updateWaterBodyForces(oldWaterBody)
        end
        forces.RemovePumpFromWaterbody(pump_data.force, pump_data.surface, oldWaterBodyId, pump_data.entity.unit_number)
    end

    local new_force_waterbody_id = forces.AddPumpToWaterbody(pump_data.force, pump_data.surface, newWaterBodyId, pump_data.entity.unit_number)
    if new_force_waterbody_id == -1 then
        return
    end
    
    entities.checkActivePumpWaterBody(pump_data)
end

function entities.rejectEntityPlacement(entity, reason)
    if entity.last_user and entity.last_user.valid then
        entity.last_user.print(reason)
        entity.last_user.insert{name = entity.name, count = 1}
    end
    entity.destroy()
end


function entities.BuiltPump(event)

    local entity = event.entity
    local input_position = utils.calculate_direction_offset(entity.position, entity.direction)

    -- Validate that the pump can be placed (must be on water)
    if not utils.validate_tile_placement(input_position, entity.surface, utils.WaterTiles) then
        entities.rejectEntityPlacement(entity, "Must be placed on water edge")
        return
    end

    local pump = initNewPump(entity)
    
    local waterBodyId = waterbodies.createWaterBodyFromTileIfNotExists(input_position, entity.surface)
    entities.addNewPump(waterBodyId, pump)

    local force_waterbody_id = entities.getForceWaterbodyIdFromPump(pump)
    if force_waterbody_id == -1 then
        entities.rejectEntityPlacement(entity, "Too many waterbodies for force")
        return
    end

    entities.checkActivePumpWaterBody(pump)
end



-- Handle building of tracked entities
function entities.BuiltEntity(entity)

	if entities.waterfill_placer_to_water_tile[entity.name] then
		entities.placerWater(entity) 
        return
    end

    if entities.offshore_pumps_names[entity.name] then
        entities.BuiltPump(entity)
        return
    end

    -- if entities.offshore_drains_names[entity.name] then
    --     entities.BuiltDrain(entity)
    --     return
    -- end
	
end 

-- Main destruction handler
function entities.DestroyedEntity(event)
    local entity = event.entity
    local unit_number = entity.unit_number
    
    if not entities.getTrackedEntity(unit_number) then
        return -- Not a tracked entity
    end
    
    local entity_data = entities.getTrackedEntity(unit_number)
    
    if entity_data.type == "pump" then
        entities.DestroyedPump(entity, entity_data)
    -- elseif entity_data.type == "drain" then
    --     entities.DestroyedDrain(entity, entity_data)
    end
    
    entities.removeTrackedEntity(unit_number)
end

function entities.DestroyedPump(entity, entity_data)
    local waterBodyId = entity_data.waterBodyId
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    
    if not waterBody then
        return -- Water body already cleaned up
    end
    
    -- Remove pump from water body
    waterBody.entitiesData.pumps[entity.unit_number] = nil
    
    forces.RemovePumpFromWaterbody(entity_data.force, entity_data.surface, waterBodyId, entity.unit_number)

    -- Update force tracking
    entities.updateWaterBodyForces(waterBody)
    
    -- Check if water body is now orphaned
    -- if entities.isWaterBodyOrphaned(waterBody) then
    --     waterbodies.markWaterBodyForCleanup(waterBody)
    -- end
end

entities.pump_entity_types = {
    legacy = "offshore-pump",
    active = "offshore-pump-x-",
    inactive = "offshore-pump-nofluid"

}

function entities.getActivePumpNameForForceWaterbodyId(force_waterbody_id)
    return entities.pump_entity_types.active .. force_waterbody_id
end

function entities.replacePumpEntity(pump_data, new_entity_type)
    local old_entity = pump_data.entity
    local position = old_entity.position
    local direction = old_entity.direction
    local surface = old_entity.surface
    local force = old_entity.force
    local last_user = old_entity.last_user
    
    entities.removeTrackedEntity(old_entity.unit_number)
    
    -- Destroy old entity
    old_entity.destroy()
    
    -- Create new entity
    local new_entity = surface.create_entity{
        name = new_entity_type,
        position = position,
        direction = direction,
        player = last_user,
        force = force
    }
    
    -- Update references
    pump_data.entity = new_entity
    entities.registerTrackedEntity(new_entity.unit_number, pump_data)
    
    return new_entity
end

function entities.getForceWaterbodyIdFromPump(pump_data)
    local force_waterbody_id = forces.AddPumpToWaterbody(pump_data.force, pump_data.surface, pump_data.waterBodyId, pump_data.entity.unit_number)
    if force_waterbody_id == -1 then
        forces.AttemptToFixWaterbodyForceId(pump_data.force, pump_data.surface, pump_data.waterBodyId)
        force_waterbody_id = forces.AddPumpToWaterbody(pump_data.force, pump_data.surface, pump_data.waterBodyId, pump_data.entity.unit_number)
    end
    return force_waterbody_id
end

function entities.deactivateWaterBodyPumps(waterBodyId)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if not waterBody then
        return
    end
    for _, pump_data in pairs(waterBody.entitiesData.pumps) do
        entities.deactivatePump(pump_data)
    end
end

function entities.deactivatePump(pump_data)
    if pump_data.entity.name == entities.pump_entity_types.legacy or
        utils.CheckSubstring(pump_data.entity.name, entities.pump_entity_types.active) then
        local new_entity_type =  entities.pump_entity_types.inactive
        entities.replacePumpEntity(pump_data, new_entity_type)
        pump_data.active = 0
    end
end


function entities.activatePump(pump_data)
    if pump_data.entity.name == entities.pump_entity_types.legacy or
        pump_data.entity.name == entities.pump_entity_types.inactive then
        local force_waterbody_id = entities.getForceWaterbodyIdFromPump(pump_data)
        if force_waterbody_id == -1 then
            return
        end
        local new_entity_type =  entities.pump_entity_types.active .. force_waterbody_id
        entities.replacePumpEntity(pump_data, new_entity_type)
        pump_data.active = 1
    end
end

function entities.checkActivePumpWaterBody(pump_data)
    local current_name = pump_data.entity.name
    local force_waterbody_id = entities.getForceWaterbodyIdFromPump(pump_data)
    if force_waterbody_id == -1 then
        return
    end
    local required_name = entities.pump_entity_types.active .. force_waterbody_id
    if current_name ~= required_name then
        entities.replacePumpEntity(pump_data, required_name)
    end
end

function entities.updatePumpStates()
    for unit_number, pump_data in pairs(storage.TrackedEntities) do
        if pump_data.type == "pump" then
            local waterBody = waterbodies.getWaterBody(pump_data.waterBodyId)
            local should_be_active = (
                waterBody and 
                waterBody.valid and 
                not waterBody.waterBodyStateData.Depleted and
                pump_data.entity.valid and
                pump_data.entity.neighbours[1] and pump_data.entity.neighbours[1][1] -- to double check if this is correct
            )
            
            if should_be_active and pump_data.active == 0 then
                entities.activatePump(pump_data)
            elseif not should_be_active and pump_data.active == 1 then
                entities.deactivatePump(pump_data)
            else
                entities.checkActivePumpWaterBody(pump_data)
            end
        end
    end
end
