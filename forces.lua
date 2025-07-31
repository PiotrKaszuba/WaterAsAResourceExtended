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
