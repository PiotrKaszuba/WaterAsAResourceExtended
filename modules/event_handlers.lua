require("modules.entities")
require("modules.tiles")
require("modules.forces")
require("modules.utils")
require("modules.waterbody_scan")

event_handlers = {}

function event_handlers.signalCreatedWaterBodyPendingScanningToPlayer(waterBody)
    return "A new water body has been created and is pending scanning."
end

function event_handlers.signalAttachedToWaterBody(waterBody)
    local shared_msg = "A pump has been added to "
    if waterBody.searchData.finished then
        return string.format("%s%s, with %sL of water with regen %sL and total area of %s tiles.", shared_msg, waterbodies.getFullNameForWaterBody(waterBody), utils.comma_value(waterBody.waterAreaData.AmountWtr), waterBody.waterAreaData.RegenAmount, waterBody.waterAreaData.TotalArea)
    else
        return string.format("%s water body that is still being scanned.", shared_msg)
    end
end

function event_handlers.BuiltPump(entity)

    local pump = entities.initAndRegisterNewPump(entity)

    if not entities.validatePumpPlacement(pump) then
        utils.rejectEntityPlacement(pump.entity, "Must be placed on water edge and not on a dry (depleted) tile")
    else
        local waterBodyId, created = waterbody_scan.createWaterBodyFromTileIfNotExists(pump.input_position, pump.surface)
        entities.addPumpToWaterBody(waterBodyId, pump)
        waterbodies.signalPerForce(waterbodies.getWaterBody(waterBodyId), created and event_handlers.signalCreatedWaterBodyPendingScanningToPlayer or event_handlers.signalAttachedToWaterBody)
    end
end


event_handlers.offshore_pump_handlers = {
    ["built"] = event_handlers.BuiltPump,
    ["destroyed"] = entities.DestroyedPump,
    ["teleported"] = entities.TeleportedPump,
}

event_handlers.waterfill_placer_handlers = {
    ["built"] = tiles.placerWater,
}


function event_handlers.HandleEntity(event, event_type)
    local entity = event.entity
    local handlers = nil

    -- this must be first because waterfill may also be of prototype type == offshore_pump_prototype_type
    if tiles.waterfill_placer_to_water_tile[entity.name] then
        handlers = event_handlers.waterfill_placer_handlers
    elseif entity.prototype.type == entities.offshore_pump_prototype_type then
        handlers = event_handlers.offshore_pump_handlers        
    end

    if handlers and handlers[event_type] then
        handlers[event_type](entity)
    end
end


function event_handlers.BuiltEntity(event)
    event_handlers.HandleEntity(event, "built")
end


function event_handlers.DestroyedEntity(event)
    event_handlers.HandleEntity(event, "destroyed")
end


function event_handlers.TeleportedEntity(event)
    event_handlers.HandleEntity(event, "teleported")
end

function event_handlers.handlePlayerTileEvents(event)
    if event.mod_name == "creative-mod" then return end
    
    local surface = utils.GetSurfaceById(event.surface_index)

    tiles.handleTileEventsInternal(
        event.tiles,
        surface,
        event.tile.name
    )
end

function event_handlers.handleScriptTileEvents(event)
    local tileTypes = {}
    local tileCount = 0
    for _, tile in pairs(event.tiles) do
        if tileTypes[tile.name] == nil then
            tileTypes[tile.name] = true
            tileCount = tileCount + 1
        end
    end
    
    if tileCount > 1 then
        utils.profile_hits("event_handlers.handleScriptTileEvents", "script_raised_set_tiles with multiple tile types - processing all")
        game.print("Warning: script_raised_set_tiles with multiple tile types - processing all")
    end

    local surface = utils.GetSurfaceById(event.surface_index)
    
    tiles.handleTileEventsInternal(
        event.tiles,
        surface
    )
end

function event_handlers.TechTrack(event)
    if utils.CheckSubstring(event.research.name, forces.TechYieldBoostName) then
        forces.UpdateForceTechYieldBoost(event.research.force.name, event.research.name, event.research.level)
    end
end
