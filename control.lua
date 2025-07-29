require("utils")
require("waterbodies")
require("entities")
require("forces")




function initUpdateBudget()
	return {budget = storage.UpdateBudget}
end
function EverySecond()
	local updateBudget = initUpdateBudget()
	-- events handling
	waterbodies.processTileEventQueue(storage.MaxEventsPerSecond, updateBudget)
	waterbodies.updateWaterBodies(updateBudget)
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
	waterbodies.collectWaterUsageStats(storage.LoopTick)
	if SecondTickCounter(storage.LoopNumTicks) then
		EverySecond()
	end
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

	waterbodies.initWaterBodies()
	waterbodies.initWaterTiles()
	waterbodies.initTileEventQueue()
	entities.initTrackedEntities()
	forces.initPlayerForces()
end

-- SCRIPT EVENTS -- 
script.on_init(Init)
script.on_load(Init)

script.on_nth_tick(6, PeriodicUpdate) -- Run the main update 10 times per second

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, entities.BuiltEntity)
script.on_event({defines.events.on_player_mined_entity,defines.events.script_raised_destroy,defines.events.on_robot_mined_entity,defines.events.on_entity_died}, entities.DestroyedEntity)
script.on_event({defines.events.on_player_built_tile,defines.events.on_robot_built_tile}, waterbodies.handlePlayerTileEvents)
script.on_event({defines.events.script_raised_set_tiles}, waterbodies.handleScriptTileEvents)