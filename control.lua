require("modules.utils")
require("modules.waterbodies")
require("modules.entities")
require("modules.forces")
require("modules.tiles")
require("modules.waterbody_update")
require("modules.waterbody_scan")
require("modules.event_handlers")

control = {}

control.periodic_update_ticks = 1 -- periodic update every tick: 60/s
control.desired_big_update_ticks = 30 -- big update 2x per second: 2/s
control.scanning_update_ticks = 10 -- scanning loop a few times per second: 6/s - but not on big update, so less than 6/s -> 4/s

function control.is_picker_dollies_available()
    return (remote and remote.interfaces['PickerDollies']) or false
end

function control.Init()
	if storage.PeriodicTick == nil then
		storage.PeriodicTick = 0
	end
    if storage.PeriodicTicksPerBigUpdate == nil then
        storage.PeriodicTicksPerBigUpdate =  math.ceil(control.desired_big_update_ticks / control.periodic_update_ticks)
    end
	if storage.PeriodicTicksPerScanningUpdate == nil then
		storage.PeriodicTicksPerScanningUpdate =  math.ceil(control.scanning_update_ticks / control.periodic_update_ticks)
	end
	if storage.UpdateBudget == nil then
		storage.UpdateBudget = settings.global["Update-Budget-Per-Second"].value
	end

	if storage.MaxEventsPerSecond == nil then
		storage.MaxEventsPerSecond = 100
	end

	storage.PeriodicEveryXTicks = control.periodic_update_ticks

	if storage.CurrentUpdateBudget == nil then
		storage.CurrentUpdateBudget = control.initUpdateBudget()
	end
	
	waterbodies.initWaterBodiesAndTiles()
	tiles.initTileEventQueue()
	entities.initTrackedEntities()
	forces.initPlayerForces()

	if control.is_picker_dollies_available() then
		remote.call('PickerDollies', 'add_blacklist_name', entities.offshore_pump_prototype_type)
	end
end

function control.initUpdateBudget(periodic_ticks_per_update)
	local periodic_ticks_per_update = periodic_ticks_per_update or storage.PeriodicTicksPerBigUpdate
	return {budget = utils.normalize_update_values_per_second(storage.UpdateBudget, true, periodic_ticks_per_update)}
end

function control.BigUpdate(updateBudget)
	-- events handling
	tiles.processTileEventQueue(utils.normalize_update_values_per_second(storage.MaxEventsPerSecond, true), updateBudget)
    waterbody_update.updateWaterBodies(updateBudget)
	entities.updatePumpStates()
end

-- on purpose outside of control module
-- could it enhance performance not to access the module every tick?
function PeriodicUpdate()
	-- this is called every tick or 'small update'
	-- local var to reduce amount of storage read access
	local periodicTick = storage.PeriodicTick

	-- WaterUsage collection from last tick - so before increment
	waterbody_update.collectWaterUsageStats()

	local big_update_tick = periodicTick % storage.PeriodicTicksPerBigUpdate
	if big_update_tick == 0 then
		storage.CurrentUpdateBudget = control.initUpdateBudget()
		control.BigUpdate(storage.CurrentUpdateBudget)
	else
		-- if not big update tick, we need to check for scanning update
		local scanning_update_tick = periodicTick % storage.PeriodicTicksPerScanningUpdate
        if scanning_update_tick == 0 then
            -- reuse the same per-second budget across big/scanning updates
            waterbody_scan.scanningUpdateAll(storage.CurrentUpdateBudget)
		end
	end
	storage.PeriodicTick = periodicTick + 1

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
