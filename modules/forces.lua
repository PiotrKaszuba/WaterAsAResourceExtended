require("modules.utils")

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
		water_usage_multiplier = 1.0,
		force = forces.getGameForce(name),
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

forces.TechYieldBoostLevelInfiniteBoost = 0.15
forces.TechYieldBoostName = "waar-yield-boost-"
forces.TechYieldBoostLevels = {
	[1] = 1.0 * (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ 1,
	[2] = 1.0 * (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ 2,
	[3] = 1.0 * (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ 3,
	[4] = 1.0 * (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ 4,
	[5] = 1.0 * (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ 5,

}

function forces.GetTechYieldBoost(research_name, research_level)
	if utils.CheckSubstring(research_name, forces.TechYieldBoostName) then
		local maxLevel = utils.GetMaxKey(forces.TechYieldBoostLevels)
		local boostLevel = tonumber(utils.RemovePrefix(research_name, forces.TechYieldBoostName))

		local boost = 1.0
		if boostLevel > maxLevel then
			-- Use boostLevel consistently (not research_level) to avoid negative exponents
			boost = forces.TechYieldBoostLevels[maxLevel] *
			((1 - forces.TechYieldBoostLevelInfiniteBoost) ^ (boostLevel - maxLevel))
		else
			boost = forces.TechYieldBoostLevels[boostLevel]
		end
		return boost
	end
	return nil
end

function forces.UpdateForceTechYieldBoost(force_name, research_name, research_level)
	local boost = forces.GetTechYieldBoost(research_name, research_level)
	if boost ~= nil then
		local force = forces.AddForceIfNotExists(force_name)
		force.water_usage_multiplier = boost
	end
end
