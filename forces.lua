forces = {}


function forces.initPlayerForces()
    if storage.PlayerForces == nil then
        storage.PlayerForces = {}
    end
end

function forces.getGameForce(name)
	return game.forces[name]
end

function forces.InitPlayerForce(name)
	return {
		name = name,
		water_yield_regen_boost = 1.0,
		surfaces = {} -- surface_name -> {} - waterbody_id -> {waterbody_force_id = int, pumps = {unit_number = true}}
	}
end

function forces.getPlayerForce(name)
    return storage.PlayerForces[name]
end

function forces.checkForceExists(name)
    return storage.PlayerForces[name] ~= nil
end

function forces.AddForceIfNotExists(name)
    if not forces.checkForceExists(name) then
        storage.PlayerForces[name] = forces.InitPlayerForce(name)
    end
	return storage.PlayerForces[name]
end

function forces.checkSurfaceExists(force_name, surface_name)
	return forces.checkForceExists(force_name) and storage.PlayerForces[force_name].surfaces[surface_name] ~= nil
end

function forces.AddSurfaceIfNotExists(force_name, surface_name)
	forces.AddForceIfNotExists(force_name)
	if not forces.checkSurfaceExists(force_name, surface_name) then
		storage.PlayerForces[force_name].surfaces[surface_name] = {}
	end
	return storage.PlayerForces[force_name].surfaces[surface_name]
end

function forces.checkWaterbodyExists(force_name, surface_name, waterbody_id)
	return forces.checkSurfaceExists(force_name, surface_name) and storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id] ~= nil
end

function forces.GetMaxWaterbodiesPerSurface(force_name, surface_name)
	return settings.startup["Force-Max-Waterbodies"].value
end

function forces.NextForceWaterbodyId(force_name, surface_name)
	if not forces.checkSurfaceExists(force_name, surface_name) then
		return 1
	end

	-- cycling ID - need to find lowest free ID
	local taken_ids = {}
	for _, v in pairs(storage.PlayerForces[force_name].surfaces[surface_name]) do
		taken_ids[v.waterbody_force_id] = true
	end

	local max_waterbody_id = forces.GetMaxWaterbodiesPerSurface(force_name, surface_name)
	for i = 1, max_waterbody_id do
		if not taken_ids[i] then
			return i
		end
	end
	return -1 -- no free ID found
end

function forces.AttemptToFixWaterbodyForceId(force_name, surface_name, waterbody_id)
	if not forces.checkWaterbodyExists(force_name, surface_name, waterbody_id) then
		return
	end
	storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id].waterbody_force_id = forces.NextForceWaterbodyId(force_name, surface_name)
end

function forces.FindInvalidWaterbodiesAndAttemptToFix(force_name, surface_name)
	for _, waterbody in pairs(storage.PlayerForces[force_name].surfaces[surface_name]) do
		if waterbody.waterbody_force_id == -1 then
			waterbody.waterbody_force_id = forces.NextForceWaterbodyId(force_name, surface_name)
		end
	end
end

function forces.AddWaterbodyIfNotExists(force_name, surface_name, waterbody_id)
	forces.AddSurfaceIfNotExists(force_name, surface_name)
	if not forces.checkWaterbodyExists(force_name, surface_name, waterbody_id) then
		local waterbody_force_id = forces.NextForceWaterbodyId(force_name, surface_name)
		storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id] = {
			waterbody_force_id = waterbody_force_id,
			pumps = {}
		}
	end
	return storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id]
end

function forces.AddPumpToWaterbody(force_name, surface_name, waterbody_id, unit_number)
	local waterbody = forces.AddWaterbodyIfNotExists(force_name, surface_name, waterbody_id)
	waterbody.pumps[unit_number] = true
	return waterbody.waterbody_force_id
end

function forces.RemoveWaterbody(force_name, surface_name, waterbody_id)
	if not forces.checkWaterbodyExists(force_name, surface_name, waterbody_id) then
		return
	end
	storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id] = nil
end

function forces.RemoveWaterbodyFromAllForces(surface_name, waterbody_id)
	for _, force in pairs(storage.PlayerForces) do
		forces.RemoveWaterbody(force.name, surface_name, waterbody_id)
	end
end

function forces.CheckIfAnyPumpsActiveForForceWaterbody(force_name, surface_name, waterbody_id)
	if not forces.checkWaterbodyExists(force_name, surface_name, waterbody_id) then
		return false
	end
	return next(storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id].pumps) ~= nil
end

function forces.RemovePumpFromWaterbody(force_name, surface_name, waterbody_id, unit_number)
	if not forces.checkWaterbodyExists(force_name, surface_name, waterbody_id) then
		return
	end
	storage.PlayerForces[force_name].surfaces[surface_name][waterbody_id].pumps[unit_number] = nil

	if forces.CheckIfAnyPumpsActiveForForceWaterbody(force_name, surface_name, waterbody_id) then
		return
	end	
	forces.RemoveWaterbody(force_name, surface_name, waterbody_id)
end


forces.TechYieldRegenBoostName = "waar-yield-regen-boost-"
forces.TechYieldRegenBoostLevels = {
	[1] = 1.2,
	[2] = 1.4,
	[3] = 1.6,
	[4] = 1.8,
	[5] = 2.0
}

forces.TechYieldRegenBoostLevelInfiniteBoost = 0.2

function forces.GetTechYRBoost(research_name, research_level)
	if forces.CheckSubstring(research_name, forces.TechYieldRegenBoostName) then
		local maxLevel = forces.GetMaxKey(forces.TechYieldRegenBoostLevels)
		local boostLevel = tonumber(forces.RemovePrefix(research_name, forces.TechYieldRegenBoostName))
		
		local boost = 1.0
		if boostLevel > maxLevel then
			boost = forces.TechYieldRegenBoostLevels[maxLevel] + (forces.TechYieldRegenBoostLevelInfiniteBoost * (research_level - maxLevel))
		else
			boost = forces.TechYieldRegenBoostLevels[boostLevel]
		end
		return boost
	end
	return nil
end

function forces.UpdateForceTechYRBoost(force_name, research_name, research_level)
	local boost = forces.GetTechYRBoost(research_name, research_level)
	if boost ~= nil then
		local force = forces.AddForceIfNotExists(force_name)
		force.water_yield_regen_boost = boost
	end
end

function forces.get_set_of_forces_from_pumps(pumps)
	local forces = {}
	for _, v in pairs(pumps) do
		forces[v.entity.force.name] = true
	end
	return forces
end
