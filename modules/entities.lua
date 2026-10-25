require("modules.utils")
require("modules.waterbodies")
require("modules.forces")

entities = {}

function entities.initTrackedEntities()
    if storage.TrackedEntities == nil then
        storage.TrackedEntities = {} -- unit_number -> "entity_data" = {type = ("pump", "drain"), waterBodyId = int, force = <force_id>} and other fields
    end
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

function entities.shouldHandlePump(entity)
    if not entity.valid or entity.prototype.type ~= entities.offshore_pump_prototype_type then return false end
    if not utils.isManagedSurface(entity.surface) then return false end
    if entity.name == "waterfill-placer" or entity.name == "waterfill-placer-deep" then return false end
    local source = entity.get_fluid_source_tile()
    local tile = source and entity.surface.get_tile(source)
    if tile and utils.DryWaterTiles[tile.name] then return true end
    local fluid = entity.get_fluid_source_fluid()
    if fluid and fluid ~= "water" then return false end
    -- Unknown water tiles require their own drying/restoration mapping. A pump
    -- with no fluid source still goes through the existing placement validation.
    return fluid == nil or (tile and utils.WaterTiles[tile.name]) == true
end

function entities.initAndRegisterNewPump(entity)
    -- "pump_data"
    local pump_data = {
        ["entity"] = entity,
        ["unit_number"] = entity.unit_number,
        ["input_position"] = entity.get_fluid_source_tile(),
        ["spritepos"] = entity.position,
        ["surface"] = entity.surface,
        ["direction"] = entity.direction,
        ["tileName"] = "water", -- Only water is supported now
        ["playerForce"] = forces.AddForceIfNotExists(entity.force.name),

        ["type"] = "pump",

        ["waterBodyId"] = nil,

        ["disabled"] = false,
    }
    entities.registerTrackedEntity(pump_data.unit_number, pump_data)
    entities.blacklistPumpMovement(entity)
    return pump_data
end

function entities.blacklistPumpMovement(entity)
    if remote.interfaces["PickerDollies"] then
        remote.call("PickerDollies", "add_blacklist_name", entity.name)
    end
end

function entities.blacklistTrackedPumps()
    local names = {}
    for _, pump in pairs(storage.TrackedEntities) do
        if pump.entity.valid and not names[pump.entity.name] then
            entities.blacklistPumpMovement(pump.entity)
            names[pump.entity.name] = true
        end
    end
end

function entities.releaseUnmanagedPumps()
    for unit_number, pump in pairs(storage.TrackedEntities) do
        if pump.type == "pump" and (not pump.entity.valid or not entities.shouldHandlePump(pump.entity)) then
            -- This mod already controls tracked pumps' script activation. Release
            -- that control once; normal fuel/power/circuit restrictions still apply.
            if pump.entity.valid then pump.entity.disabled_by_script = false end
            entities.removePumpFromWaterBody(unit_number, pump.waterBodyId)
            entities.removeTrackedEntity(unit_number)
        end
    end
end

function entities.addPumpToWaterBody(waterBodyId, pump_data)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if not (waterBody and waterBody.valid) then
        utils.profile_hits("entities.addPumpToWaterBody", "water body not found or invalid: " .. tostring(waterBodyId))
        game.print("Error:Water body not found or invalid: " .. tostring(waterBodyId))
    else
        local waterBodyStateData = waterBody.waterBodyStateData
        waterBodyStateData.Pumps[#waterBodyStateData.Pumps + 1] = pump_data
        waterBodyStateData.Forces[pump_data.playerForce.name] = pump_data.playerForce
        pump_data.waterBodyId = waterBodyId
        if waterBodyStateData.TempInactive then
            entities.deactivatePump(pump_data)
        end
    end
end

function entities.updateWaterBodyForces(waterBody)
    local state = waterBody.waterBodyStateData
    local new_forces = {}
    for _, pump_data in ipairs(state.Pumps) do
        local player_force = pump_data.playerForce
        new_forces[player_force.name] = player_force
    end
    state.Forces = new_forces
end

function entities.removePumpFromWaterBody(unit_number, waterBodyId)
    if waterBodyId ~= nil then
        local waterBody = waterbodies.getWaterBody(waterBodyId)
        if waterBody and waterBody.valid then
            utils.remove_table_from_array(waterBody.waterBodyStateData.Pumps, "unit_number", unit_number)
            entities.updateWaterBodyForces(waterBody)
        end
    end
end

function entities.validatePumpPlacement(pump_data)
    -- Validate that the pump can be placed (must be on water) and its base not on dry tile
    local surface = pump_data.surface
    local input_position_on_water_or_dry = utils.validate_tile_placement(pump_data.input_position, surface,
        utils.WaterAndDryTiles)
    if not input_position_on_water_or_dry then
        return false
    end
    local base_position_not_water_or_dry = utils.validate_tile_placement(pump_data.spritepos, surface, nil,
        utils.WaterAndDryTiles)
    return base_position_not_water_or_dry
end

function entities.DestroyedPump(entity)
    local unit_number = entity.unit_number
    local pump_data = entities.getTrackedEntity(unit_number)
    if not pump_data then
        return -- Not a tracked entity
    end
    entities.removePumpFromWaterBody(unit_number, pump_data.waterBodyId)
    entities.removeTrackedEntity(unit_number)
end

function entities.TeleportedPump(entity)
    if not entities.getTrackedEntity(entity.unit_number) and not entities.shouldHandlePump(entity) then return end
    -- it shouldn't happen - issue a warning and disable the pump
    utils.profile_hits("entities.TeleportedPump", "a pump was teleported")
    game.print("Warning: a pump was teleported")
    local pump_data = entities.getTrackedEntity(entity.unit_number)
    if not pump_data then
        -- entity is not tracked - we still need to disable it and we need 'pump_data' for it
        pump_data = entities.initAndRegisterNewPump(entity)
    end
    entities.disablePump(pump_data)
    entities.DestroyedPump(entity)
end

function entities.deactivatePump(pump_data)
    pump_data.entity.disabled_by_script = true
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
    pump_data.entity.disabled_by_script = false
end

function entities.enablePump(pump_data)
    -- enable means that it can be active but not necessarily now
    pump_data.disabled = false
end

function entities.call_on_each_waterbody_pump(waterBodyId, func)
    local waterBody = waterbodies.getWaterBody(waterBodyId)
    if waterBody and waterBody.valid then
        for _, pump_data in ipairs(waterBody.waterBodyStateData.Pumps) do
            func(pump_data)
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

function entities.getFirstPumpPerForce(waterBody)
    local force_to_pump = {}
    for _, pump_data in ipairs(waterBody.waterBodyStateData.Pumps) do
        local force_name = pump_data.playerForce.name
        if not force_to_pump[force_name] then
            force_to_pump[force_name] = pump_data
        end
    end
    return force_to_pump
end

function entities.updatePumpStates()
    local to_remove = {}
    for unit_number, pump_data in pairs(storage.TrackedEntities) do
        if pump_data.type == "pump" then
            if not pump_data.entity.valid then
                entities.removePumpFromWaterBody(unit_number, pump_data.waterBodyId)
                to_remove[unit_number] = true
            else
                local should_be_active = false
                local waterBody = waterbodies.getWaterBody(pump_data.waterBodyId)
                if waterBody and waterBody.valid then
                    local state = waterBody.waterBodyStateData
                    should_be_active = (
                        not state.TempInactive and
                        not state.Depleted and
                        not pump_data.disabled
                    )
                end

                if should_be_active then
                    entities.activatePump(pump_data)
                else
                    entities.deactivatePump(pump_data)
                end
            end
        end
    end
    for unit_number, _ in pairs(to_remove) do
        entities.removeTrackedEntity(unit_number)
    end
end
