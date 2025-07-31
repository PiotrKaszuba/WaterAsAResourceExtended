require("utils")
require("waterbodies")
require("entities")
require("forces")
require("tiles")
require("waterbody_update")
require("event_handlers")

control = {}

control.periodic_update_ticks = 1
control.desired_big_update_ticks = 60

function normalize_values_per_second(value, as_int_ceiling)
	local normalized_value = value * storage.LoopNumTicks * storage.PeriodicEveryXTicks / 60
	if as_int_ceiling then
		return math.ceil(normalized_value)
	end
	return normalized_value
end

function initUpdateBudget()
	return {budget = normalize_values_per_second(storage.UpdateBudget, true)}
end
function EverySecond()
	local updateBudget = initUpdateBudget()
	-- events handling
	tiles.processTileEventQueue(normalize_values_per_second(storage.MaxEventsPerSecond, true), updateBudget)
	waterbody_update.updateWaterBodies(updateBudget)
	entities.updatePumpStates()
end

function SecondTickCounter(numTicks)
	if storage.LoopTick == nil or storage.LoopTick >= numTicks then
		storage.LoopTick = 0
		storage.LoopNumTicks =  math.ceil(control.desired_big_update_ticks / control.periodic_update_ticks)
		return true
	else
		storage.LoopTick = storage.LoopTick + 1
	end
	return false
end

function PeriodicUpdate()
	waterbody_update.collectWaterUsageStats(storage.LoopTick)
	if SecondTickCounter(storage.LoopNumTicks) then
		EverySecond()
	end
end

local function is_picker_dollies_available()
    return (remote and remote.interfaces['PickerDollies']) or false
end

function Init()
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

	if is_picker_dollies_available() then
		remote.call('PickerDollies', 'add_blacklist_name', entities.offshore_pump_prototype_type)
	end
end




-- SCRIPT EVENTS -- 
script.on_init(Init)
script.on_load(Init)

script.on_nth_tick(control.periodic_update_ticks, PeriodicUpdate) -- Run the main update every tick

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, event_handlers.BuiltEntity)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, event_handlers.DestroyedEntity)
script.on_event({defines.events.script_raised_teleported}, event_handlers.TeleportedEntity)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, event_handlers.handlePlayerTileEvents)
script.on_event({defines.events.script_raised_set_tiles}, event_handlers.handleScriptTileEvents)

script.on_event(defines.events.on_research_finished, event_handlers.TechTrack)
