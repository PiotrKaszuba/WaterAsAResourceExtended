require("modules.entities")
require("modules.tiles")
require("modules.forces")
require("modules.utils")
require("modules.waterbody_scan")

event_handlers = {}

function event_handlers.BuiltPump(entity, do_not_reject)

    local input_position = utils.calculate_direction_offset(entity.position, entity.direction)
    local pump = initNewPump(entity)

    -- Validate that the pump can be placed (must be on water)
    if not utils.validate_tile_placement(input_position, entity.surface, utils.WaterTiles) then
        entities.rejectOrDeactivatePump(pump, "Must be placed on water edge", do_not_reject)
    else
        local waterBodyId = waterbody_scan.createWaterBodyFromTileIfNotExists(input_position, entity.surface)
        entities.registerPumpAndAddToWaterBody(waterBodyId, pump)
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
    if entity.prototype.type == entities.offshore_pump_prototype_type then
        handlers = event_handlers.offshore_pump_handlers
    elseif tiles.waterfill_placer_to_water_tile[entity.name] then
        handlers = event_handlers.waterfill_placer_handlers
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
    
    tiles.handleTileEventsInternal(
        event.tiles,
        event.surface_index
    )
end

function event_handlers.handleScriptTileEvents(event)
    local tileTypes = {}
    for _, tile in pairs(event.tiles) do
        tileTypes[tile.name] = true
    end
    
    if #tileTypes > 1 then
        game.print("Warning: script_raised_set_tiles with multiple tile types - processing all")
    end
    
    tiles.handleTileEventsInternal(
        event.tiles,
        event.surface_index
    )
end

function event_handlers.TechTrack(event)
    if forces.CheckSubstring(event.research.name, forces.TechYieldBoostName) then
        forces.UpdateForceTechYieldBoost(event.research.force.name, event.research.name, event.research.level)
    end
end
