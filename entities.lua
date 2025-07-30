entities = {}

function entities.initTrackedEntities()
    storage.TrackedEntities = {} -- unit_number -> "entity_data" = {type = ("pump", "drain"), waterBodyId = int, force = <force_id>} and other fields
    storage.TrackedPoles = {} -- unit_number -> "pole-data" = {entity = <entity>, distance = number}
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

function entities.registerTrackedPole(unit_number, pole_data)
    storage.TrackedPoles[unit_number] = pole_data
end

function entities.getTrackedPole(unit_number)
    return storage.TrackedPoles[unit_number]
end

function entities.removeTrackedPole(unit_number)
    storage.TrackedPoles[unit_number] = nil
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
        ["poles"] = {} -- unit_number -> true; indicator table for poles
    }
end

function entities.getMaxPoleDistance()
    local max_distance = prototypes.max_electric_pole_supply_area_distance
    local max_quality_bonus = 0 -- TODO: Implement quality bonus
    return max_distance + max_quality_bonus
end

function entities.getPoleDistance(entity)
    local distance = prototypes.entity[entity.prototype.name].radius_visualisation_specification.distance
    local quality_bonus = 0 -- TODO: Implement quality bonus
    return distance + quality_bonus
end

function initNewPole(entity)
    return {
        ["entity"] = entity,
        ["surface"] = entity.surface,
        ["distance"] = entities.getPoleDistance(entity),
        ["pumps"] = {}, -- unit_number -> true; indicator table for pumps
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
        game.print("Error:Water body not found: " .. tostring(waterBodyId))
    else
        waterBody.entitiesData.pumps[pump_data.entity.unit_number] = pump_data
        waterBody.entitiesData.forces[pump_data.force] = true
        pump_data.waterBodyId = waterBodyId
    end
    entities.capturePolesAroundPump(pump_data)
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




function entities.enlargedBoundingBox(bbox, distance)
    local lt = bbox.left_top
    local rb = bbox.right_bottom
    local new_bbox = {
        left_top = {
            x = lt.x - distance,
            y = lt.y - distance,
        },
        right_bottom = {
            x = rb.x + distance,
            y = rb.y + distance,
        },
    }
    return new_bbox
end

function entities.findEntitiesWithinAreaDistance(surface, bbox, distance, type)
    local within_bbox = entities.enlargedBoundingBox(bbox, distance)
    local found_entities = surface.find_entities_filtered({area = within_bbox, type = type})
    return found_entities
end

function entities.addPumpAndPole(pole_data, pump_data)
    pole_data.pumps[pump_data.entity.unit_number] = true
    pump_data.poles[pole_data.entity.unit_number] = true
end

function entities.removePumpAndPole(pole_data, pump_data)
    pole_data.pumps[pump_data.entity.unit_number] = nil
    pump_data.poles[pole_data.entity.unit_number] = nil
    entities.poleEmptyCheck(pole_data)
end

function entities.removeFromPump(pump_data, pole_data)
    pump_data.poles[pole_data.entity.unit_number] = nil
end

function entities.removeFromPole(pole_data, pump_data)
    pole_data.pumps[pump_data.entity.unit_number] = nil
    entities.poleEmptyCheck(pole_data)
end

function entities.poleEmptyCheck(pole_data)
    if next(pole_data.pumps) == nil then
        entities.removeTrackedPole(pole_data.entity.unit_number)
    end
end

function entities.BuiltPole(entity)
    -- Find pumps within distance
    local pole_distance = entities.getPoleDistance(entity)
    local found_entities = entities.findEntitiesWithinAreaDistance(entity.surface, entity.position, pole_distance, "offshore-pump")
    
    -- if pump is found - track the pole
    if #found_entities > 0 then
        local pole_data = initNewPole(entity)
        entities.registerTrackedPole(entity.unit_number, pole_data)
    
        -- add all pumps to the pole
        for _, pump in pairs(found_entities) do
            -- if the pump is not tracked
            if not entities.getTrackedEntity(pump.unit_number) then
                entities.untrackedPump(pump)
            end
            local pump_data = entities.getTrackedEntity(pump.unit_number)
            -- add the pump to the pole
            entities.addPumpAndPole(pole_data, pump_data)
        end
    end
end

function entities.untrackedPump(entity)
    game.print("Warning: a pump is not tracked") 
    entities.BuiltPump(entity, true)
end


function entities.rejectOrDeactivatePump(pump, reason, do_not_reject)
    if not do_not_reject then
        entities.rejectEntityPlacement(pump.entity, reason)
    else
        entities.deactivatePump(pump)
    end
end

function entities.capturePolesAroundPump(pump_data)
    local max_pole_distance = entities.getMaxPoleDistance()
    local found_entities = entities.findEntitiesWithinAreaDistance(pump_data.surface, pump_data.entity.bounding_box, max_pole_distance, "electric-pole")
    for _, pole in pairs(found_entities) do
        if not entities.getTrackedPole(pole.unit_number) then
            entities.BuiltPole(pole)
        else
            local pole_data = entities.getTrackedPole(pole.unit_number)
            entities.addPumpAndPole(pole_data, pump_data)
        end
    end
end

function entities.BuiltPump(entity, do_not_reject)

    local input_position = utils.calculate_direction_offset(entity.position, entity.direction)
    local pump = initNewPump(entity)

    -- Validate that the pump can be placed (must be on water)
    if not utils.validate_tile_placement(input_position, entity.surface, utils.WaterTiles) then
        entities.rejectOrDeactivatePump(pump, "Must be placed on water edge", do_not_reject)
    else
        local waterBodyId = waterbodies.createWaterBodyFromTileIfNotExists(input_position, entity.surface)
        entities.addNewPump(waterBodyId, pump)
        local valid_waterbody_id = entities.getValidWaterbodyIdFromPump(pump)
        if valid_waterbody_id == -1 then
            entities.rejectOrDeactivatePump(pump, "Too many waterbodies on surface", do_not_reject)
        end

        entities.checkActivePumpWaterBody(pump)
    end
    
end

-- Handle building of tracked entities
function entities.BuiltEntity(event)
    local entity = event.entity
    if entity.prototype.type == "electric-pole" then
        entities.BuiltPole(entity)
        return
    end

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
    if entity.prototype.type == "electric-pole" then
        entities.DestroyedPole(entity)
        return
    end

    if entities.offshore_pumps_names[entity.name] then
        entities.DestroyedPump(entity)
        return
    end

end


function entities.removeFromPumps(pole_data)
    for _, pump_data in pairs(pole_data.pumps) do
        entities.removeFromPump(pump_data, pole_data)
    end
end

function entities.removeFromPoles(pump_data)
    for _, pole_data in pairs(pump_data.poles) do
        entities.removeFromPole(pole_data, pump_data)
    end
end

function entities.DestroyedPump(entity)
    local unit_number = entity.unit_number
    if not entities.getTrackedEntity(unit_number) then
        return -- Not a tracked entity
    end
    
    local entity_data = entities.getTrackedEntity(unit_number)

    local waterBodyId = entity_data.waterBodyId
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    
    if waterBody then
        -- Remove pump from water body
        waterBody.entitiesData.pumps[entity.unit_number] = nil
        forces.RemovePumpFromWaterbody(entity_data.force, entity_data.surface, waterBodyId, entity.unit_number)
         -- Update force tracking
        entities.updateWaterBodyForces(waterBody)
    end
    
    -- Check if water body is now orphaned
    -- if entities.isWaterBodyOrphaned(waterBody) then
    --     waterbodies.markWaterBodyForCleanup(waterBody)
    -- end
    entities.removeFromPoles(entity_data)
    entities.removeTrackedEntity(unit_number)
end

function entities.DestroyedPole(entity)
    local unit_number = entity.unit_number
    local pole_data = entities.getTrackedPole(unit_number)
    if not pole_data then
        return -- Not a tracked entity
    end
    entities.removeFromPumps(pole_data)
    entities.removeTrackedPole(unit_number)
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
    local valid_waterbody_id = entities.getValidWaterbodyIdFromPump(pump_data)
    if valid_waterbody_id == -1 then
        return
    end
    local required_name = entities.pump_entity_types.active .. valid_waterbody_id
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
