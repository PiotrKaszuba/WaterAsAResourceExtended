require("modules.utils")
require("modules.waterbodies")
require("modules.entities")
require("modules.forces")
require("modules.tiles")
require("modules.waterbody_update")
require("modules.event_handlers")

control = {}

control.periodic_update_ticks = 1
control.desired_big_update_ticks = 30

function control.is_picker_dollies_available()
    return (remote and remote.interfaces['PickerDollies']) or false
end

function control.Init()
	if storage.LoopTick == nil then
		storage.LoopTick = 0
	end
	if storage.LoopNumTicks == nil then
		storage.LoopNumTicks =  math.ceil(control.desired_big_update_ticks / control.periodic_update_ticks)
	end
	if storage.UpdateBudget == nil then
		storage.UpdateBudget = settings.global["Update-Budget-Per-Second"].value
	end

	if storage.MaxEventsPerSecond == nil then
		storage.MaxEventsPerSecond = 100
	end

	storage.PeriodicEveryXTicks = control.periodic_update_ticks
	
	waterbodies.initWaterBodiesAndTiles()
	tiles.initTileEventQueue()
	entities.initTrackedEntities()
	forces.initPlayerForces()

	if control.is_picker_dollies_available() then
		remote.call('PickerDollies', 'add_blacklist_name', entities.offshore_pump_prototype_type)
	end
end


function control.initUpdateBudget()
	return {budget = utils.normalize_values_per_second(storage.UpdateBudget, true)}
end

function control.BigUpdate()
	local updateBudget = control.initUpdateBudget()
	-- events handling
	tiles.processTileEventQueue(utils.normalize_values_per_second(storage.MaxEventsPerSecond, true), updateBudget)
	waterbody_update.updateWaterBodies(updateBudget)
	entities.updatePumpStates()
end

-- on purpose outside of control module
-- could it enhance performance not to access the module every tick?
function PeriodicUpdate()
	-- this is called every tick or 'small update'
	-- local var to reduce amount of storage read access
	local loopTick = storage.LoopTick

	-- WaterUsage collection from last tick - so before increment
	waterbody_update.collectWaterUsageStats()

	if loopTick >= storage.LoopNumTicks then
		-- this is on 'big update' once - no need to optimize too much
		storage.LoopTick = 0
		storage.LoopNumTicks =  math.ceil(control.desired_big_update_ticks / control.periodic_update_ticks)
		-- big update after reset so after increment
		control.BigUpdate()
	else
		storage.LoopTick = loopTick + 1
	end

end

-- SCRIPT EVENTS -- 
script.on_init(control.Init)

script.on_nth_tick(control.periodic_update_ticks, PeriodicUpdate) -- Run the main update - 'small update' - most likely every game tick

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, event_handlers.BuiltEntity)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, event_handlers.DestroyedEntity)
script.on_event({defines.events.script_raised_teleported}, event_handlers.TeleportedEntity)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, event_handlers.handlePlayerTileEvents)
script.on_event({defines.events.script_raised_set_tiles}, event_handlers.handleScriptTileEvents)

script.on_event(defines.events.on_research_finished, event_handlers.TechTrack)
