require("utils")
require("waterbodies")
require("entities")
require("forces")
require("tiles")
require("waterbody_update")
require("event_handlers")




function initUpdateBudget()
	return {budget = storage.UpdateBudget}
end
function EverySecond()
	local updateBudget = initUpdateBudget()
	-- events handling
	tiles.processTileEventQueue(storage.MaxEventsPerSecond, updateBudget)
	waterbody_update.updateWaterBodies(updateBudget)
	entities.updatePumpStates()
end

function SecondTickCounter(numTicks)
	if storage.LoopTick == nil then
		storage.LoopTick = 0
	end
	if storage.LoopTick < numTicks then
		storage.LoopTick = storage.LoopTick + 1
	else
		storage.LoopTick = 0
		return true
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
		storage.LoopNumTicks = 10
	end
	if storage.UpdateBudget == nil then
		storage.UpdateBudget = 100 -- todo later add this as as a setting
	end

	if storage.MaxEventsPerSecond == nil then
		storage.MaxEventsPerSecond = 20 -- todo later add this as as a setting
	end

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

script.on_nth_tick(6, PeriodicUpdate) -- Run he main update 10 times per second

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, event_handlers.BuiltEntity)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, event_handlers.DestroyedEntity)
script.on_event({defines.events.script_raised_teleported}, event_handlers.TeleportedEntity)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, event_handlers.handlePlayerTileEvents)
script.on_event({defines.events.script_raised_set_tiles}, event_handlers.handleScriptTileEvents)
