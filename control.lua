require("modules.utils")
require("modules.waterbodies")
require("modules.entities")
require("modules.forces")
require("modules.tiles")
require("modules.waterbody_update")
require("modules.waterbody_scan")
require("modules.event_handlers")
require("modules.split_families")

control = {}

control.periodic_update_ticks = 1     -- periodic update every tick: 60/s
control.desired_big_update_ticks = 30 -- big update 2x per second: 2/s
control.scanning_update_ticks = 10    -- scanning loop a few times per second: 6/s; shift by 1 tick not to run on big update
control.extra_work_update_ticks = 5   -- 12/s; shift by 2 ticks not to run on big update nor scanning update

function control.is_picker_dollies_available()
	return (remote and remote.interfaces['PickerDollies']) or false
end

function control.is_waterfill_feature_enabled()
	local startup = settings.startup["Enable-Waterfill"]
	local startup_enabled = (startup == nil) or startup.value
	local canal_builder_active = script.active_mods and script.active_mods["CanalBuilderMAV"]
	return startup_enabled and not canal_builder_active
end

function control.cleanup_disabled_waterfill_artifacts()
	local removed_entities = 0
	local removed_items = 0

	for _, surface in pairs(game.surfaces) do
		for _, placer_name in pairs({ "waterfill-placer", "waterfill-placer-deep" }) do
			local entities_to_remove = surface.find_entities_filtered({ name = placer_name })
			for _, entity in pairs(entities_to_remove) do
				if entity.valid then
					entity.destroy({ raise_destroy = true })
					removed_entities = removed_entities + 1
				end
			end
		end
	end

	for _, player in pairs(game.players) do
		local removed_from_player = player.remove_item({ name = "waterfill", count = 1000000 })
		removed_items = removed_items + removed_from_player
		if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == "waterfill" then
			player.cursor_stack.clear()
			removed_items = removed_items + 1
		end
	end

	if removed_entities > 0 or removed_items > 0 then
		game.print(string.format(
			"[WaterAsAResource] Waterfill compatibility cleanup: removed %d placer entities and %d waterfill items.",
			removed_entities,
			removed_items
		))
	end
end

function control.Init()
	if storage.PeriodicTick == nil then
		storage.PeriodicTick = 0
	end
	if storage.PeriodicTicksPerBigUpdate == nil then
		storage.PeriodicTicksPerBigUpdate = math.ceil(control.desired_big_update_ticks / control.periodic_update_ticks)
	end
	if storage.PeriodicTicksPerScanningUpdate == nil then
		storage.PeriodicTicksPerScanningUpdate = math.ceil(control.scanning_update_ticks / control.periodic_update_ticks)
	end
	if storage.PeriodicTicksPerExtraWorkUpdate == nil then
		storage.PeriodicTicksPerExtraWorkUpdate = math.ceil(control.extra_work_update_ticks /
		control.periodic_update_ticks)
	end
	if storage.UpdateBudget == nil then
		storage.UpdateBudget = settings.global["Update-Budget-Per-Second"].value
	end

	if storage.MaxEventsPerSecond == nil then
		storage.MaxEventsPerSecond = 100
	end

	if storage.MaxExtraWorkPerSecond == nil then
		storage.MaxExtraWorkPerSecond = 1000
	end

	storage.PeriodicEveryXTicks = control.periodic_update_ticks

	if storage.CurrentUpdateBudget == nil then
		storage.CurrentUpdateBudget = control.initUpdateBudget()
	end

	waterbodies.initWaterBodiesAndTiles()
	tiles.initTileEventQueue()
	entities.initTrackedEntities()
	forces.initPlayerForces()

	split_families.init_storage()

	if not control.is_waterfill_feature_enabled() then
		control.cleanup_disabled_waterfill_artifacts()
	end

	if control.is_picker_dollies_available() then
		remote.call('PickerDollies', 'add_blacklist_name', entities.offshore_pump_prototype_type)
	end

	-- Scan for existing offshore pumps (for saves/scenarios that already have pumps)
	event_handlers.scanForExistingPumps()
end

function control.initUpdateBudget(periodic_ticks_per_update)
	local periodic_ticks_per_update = periodic_ticks_per_update or storage.PeriodicTicksPerBigUpdate
	return { budget = utils.normalize_update_values_per_second(storage.UpdateBudget, true, periodic_ticks_per_update) }
end

function control.BigUpdate(updateBudget, periodicTick)
	-- events handling
	tiles.processTileEventQueue(utils.normalize_update_values_per_second(storage.MaxEventsPerSecond, true), updateBudget)
	waterbody_update.updateWaterBodies(updateBudget)
	entities.updatePumpStates()
	-- families of split waterbodies: maintenance
	split_families.updateSplitFamilies(updateBudget, periodicTick)
end

-- on purpose outside of control module
-- could it enhance performance not to access the module every tick?
function PeriodicUpdate()
	-- this is called every tick or 'small update'
	-- local var to reduce amount of storage read access
	local periodicTick = storage.PeriodicTick

	-- WaterUsage collection from last tick - so before increment
	waterbody_update.collectWaterUsageStats()

	if periodicTick % storage.PeriodicTicksPerBigUpdate == 0 then
		storage.CurrentUpdateBudget = control.initUpdateBudget()
		control.BigUpdate(storage.CurrentUpdateBudget, periodicTick)
	else
		-- if not big update tick, we need to check for scanning update
		if periodicTick % storage.PeriodicTicksPerScanningUpdate == 1 then
			-- reuse the same per-second budget across big/scanning updates
			waterbody_scan.scanningUpdateAll(storage.CurrentUpdateBudget)
		else
			-- extra work update
			if periodicTick % storage.PeriodicTicksPerExtraWorkUpdate == 2 then
				waterbody_update.extraWorkUpdate(storage.CurrentUpdateBudget)
			end
		end
	end
	storage.PeriodicTick = periodicTick + 1
end

function control.VersionChanged(event)
	local mod_changed = event.mod_changes["WaterAsAResourceExtended"]
	if mod_changed then
		if mod_changed.old_version == nil then
			-- Mod was just added to an existing save
			control.Init()
		elseif utils.version_less_than(mod_changed.old_version, "2.0.0") then
			-- Migration from older version
			control.Init()
		elseif utils.version_less_than(mod_changed.old_version, "2.0.4") and not control.is_waterfill_feature_enabled() then
			-- Compatibility migration: remove stale waterfill placers/items when built-in waterfill is disabled.
			control.cleanup_disabled_waterfill_artifacts()
		end
	end

	if not control.is_waterfill_feature_enabled() then
		control.cleanup_disabled_waterfill_artifacts()
	end
end

-- SCRIPT EVENTS --
script.on_init(control.Init)
script.on_configuration_changed(control.VersionChanged)

script.on_nth_tick(control.periodic_update_ticks, PeriodicUpdate) -- Run the main update - 'small update' - most likely every game tick

script.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity }, event_handlers.BuiltEntity)
script.on_event(
{ defines.events.on_player_mined_entity, defines.events.script_raised_destroy, defines.events.on_robot_mined_entity,
	defines.events.on_entity_died }, event_handlers.DestroyedEntity)
script.on_event({ defines.events.script_raised_teleported }, event_handlers.TeleportedEntity)
script.on_event({ defines.events.on_player_built_tile, defines.events.on_robot_built_tile },
	event_handlers.handlePlayerTileEvents)
script.on_event({ defines.events.script_raised_set_tiles }, event_handlers.handleScriptTileEvents)

script.on_event(defines.events.on_research_finished, event_handlers.TechTrack)
