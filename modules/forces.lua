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
	local game_force = forces.getGameForce(name)
	return {
		name = name,
		water_usage_multiplier = forces.getForceYieldBoost(game_force),
		force = game_force,
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
local function yieldTechnologyLevel(name)
	return tonumber(string.match(name, "^waar%-yield%-boost%-(%d+)$"))
end

-- research_level is a completed level, not the next available LuaTechnology.level.
function forces.GetTechYieldBoost(research_name, research_level)
	local base_level = yieldTechnologyLevel(research_name)
	if not base_level then return nil end
	local level = base_level >= 6 and (research_level or base_level) or base_level
	if not settings.startup["Enable-Infinite-Yield-Research"].value then
		level = math.min(level, settings.startup["Yield-Boost-Max-Level"].value)
	end
	return (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ math.max(0, level)
end

function forces.getForceYieldBoost(game_force)
	local highest_level = 0
	for name, technology in pairs(game_force.technologies) do
		local base_level = yieldTechnologyLevel(name)
		if base_level then
			local completed_level = 0
			if technology.researched then
				completed_level = technology.level
			elseif base_level >= 6 and technology.level > base_level then
				-- The engine advances repeat research before on_research_finished fires.
				completed_level = technology.level - 1
			end
			highest_level = math.max(highest_level, completed_level)
		end
	end
	if not settings.startup["Enable-Infinite-Yield-Research"].value then
		highest_level = math.min(highest_level, settings.startup["Yield-Boost-Max-Level"].value)
	end
	return (1 - forces.TechYieldBoostLevelInfiniteBoost) ^ highest_level
end

-- Refresh in place: pump records keep references to these saved force records.
-- With no argument, refresh every game force after startup configuration changes.
function forces.refreshYieldBoosts(force_name)
	local game_forces = force_name and { [force_name] = forces.getGameForce(force_name) } or game.forces
	for _, game_force in pairs(game_forces) do
		local name = game_force.name
		local player_force = forces.AddForceIfNotExists(name)
		player_force.force = game_force
		player_force.water_usage_multiplier = forces.getForceYieldBoost(game_force)
	end
end

function forces.UpdateForceTechYieldBoost(force_name, research_name)
	if yieldTechnologyLevel(research_name) then forces.refreshYieldBoosts(force_name) end
end
