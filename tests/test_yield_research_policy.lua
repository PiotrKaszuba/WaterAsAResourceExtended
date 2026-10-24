local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")

t.start()

local definitions = {}
assert(loadfile("settings.lua", "t", {
    data = { extend = function(_, values)
        for _, value in ipairs(values) do definitions[value.name] = value end
    end },
}))()
t.eq(definitions["Yield-Boost-Max-Level"].default_value, 6, "finite yield cap defaults to 6")
t.eq(definitions["Yield-Boost-Max-Level"].minimum_value, 1, "finite cap allows 1")
t.eq(definitions["Yield-Boost-Max-Level"].maximum_value, 100, "finite cap allows 100")
t.eq(definitions["Yield-Boost-Max-Level"].setting_type, "startup", "finite cap is startup-only")
t.eq(definitions["Enable-Infinite-Yield-Research"].default_value, false, "infinite research defaults off")
t.eq(definitions["Enable-Infinite-Yield-Research"].setting_type, "startup", "infinite research is startup-only")

local function prototype_profile(cap, infinite)
    local technologies = {}
    assert(loadfile("prototypes/technology.lua", "t", {
        settings = { startup = {
            ["Yield-Boost-Max-Level"] = { value = cap },
            ["Enable-Infinite-Yield-Research"] = { value = infinite },
        } },
        ipairs = ipairs,
        util = { technology_icon_constant_speed = function() return {} end },
        data = { extend = function(_, values)
            for _, value in ipairs(values) do technologies[value.name] = value end
        end },
    }))()
    return technologies
end

for _, cap in ipairs({ 1, 3, 5, 6, 9, 100 }) do
    local technologies = prototype_profile(cap, false)
    for level = 1, 6 do
        local prototype = technologies["waar-yield-boost-" .. level]
        t.eq(prototype ~= nil, level <= cap, "finite cap " .. cap .. " controls tier " .. level)
        if prototype and level <= 5 then
            t.eq(prototype.unit.count, level * 100, "finite cap preserves tier " .. level .. " research cost")
        end
    end
    if cap >= 6 then
        local last = technologies["waar-yield-boost-6"]
        t.eq(last.max_level, cap, "repeat prototype ends at configured cap " .. cap)
        t.eq(last.unit.count_formula, "2^(L-5)*1000", "repeat costs retain existing progression")
        t.eq(last.unit.ingredients[5][1], "space-science-pack", "repeat research retains space science")
    end
end
local infinite_prototypes = prototype_profile(1, true)
t.ok(infinite_prototypes["waar-yield-boost-5"] ~= nil, "infinite mode retains prerequisite chain despite a low finite cap")
t.eq(infinite_prototypes["waar-yield-boost-6"].max_level, "infinite", "infinite mode ignores finite cap")

local world = env.create_world()
local player_record = forces.AddForceIfNotExists("player")
t.eq(player_record.water_usage_multiplier, 1, "unresearched higher tiers grant no bonus")
world:complete_research("waar-yield-boost-1", 1)
t.eq(player_record.water_usage_multiplier, 0.85, "first completed tier grants first-level bonus")
world:complete_research("waar-yield-boost-5", 5)
world:complete_research("waar-yield-boost-6", 6)
t.eq(world.force.technologies["waar-yield-boost-6"].researched, true, "finite final tier remains at its researched level")
t.eq(player_record.water_usage_multiplier, 0.85 ^ 6, "finite final tier applies level 6 without subtracting one")

settings.startup["Yield-Boost-Max-Level"].value = 3
player_record.water_usage_multiplier = 0.001 -- stale saved value from a previous configuration
control.VersionChanged({ mod_changes = {} })
t.eq(storage.PlayerForces.player, player_record, "configuration refresh preserves pump references to the saved force record")
t.eq(player_record.water_usage_multiplier, 0.85 ^ 3, "lowering cap clamps cached bonuses from completed research")
t.eq(storage.PlayerForces[world.force.index], nil, "force aliases do not create numeric cached records")

settings.startup["Yield-Boost-Max-Level"].value = 9
local repeat_technology = world.force.technologies["waar-yield-boost-6"]
repeat_technology.prototype.max_level = 9
repeat_technology.level, repeat_technology.researched = 9, false
forces.refreshYieldBoosts()
t.eq(player_record.water_usage_multiplier, 0.85 ^ 8, "incomplete finite repeat tier reports next level; completed level is one less")
world:complete_research("waar-yield-boost-6", 9)
t.eq(player_record.water_usage_multiplier, 0.85 ^ 9, "completed finite last level applies its full bonus")

settings.startup["Enable-Infinite-Yield-Research"].value = true
settings.startup["Yield-Boost-Max-Level"].value = 1
repeat_technology.prototype.max_level = "infinite"
world:complete_research("waar-yield-boost-6", 10)
t.eq(repeat_technology.level, 11, "infinite mock matches engine next-available-level semantics")
t.eq(repeat_technology.researched, false, "infinite technology never completes its whole range")
t.eq(player_record.water_usage_multiplier, 0.85 ^ 10, "infinite event applies completed level 10, not next level 11 or name suffix 6")
forces.refreshYieldBoosts()
t.eq(player_record.water_usage_multiplier, 0.85 ^ 10, "save/configuration refresh retains completed infinite progress")

game.forces.other = { name = "other", valid = true, technologies = {
    ["waar-yield-boost-2"] = { name = "waar-yield-boost-2", level = 2, researched = true },
} }
t.eq(forces.AddForceIfNotExists("other").water_usage_multiplier, 0.85 ^ 2, "new force registration hydrates already researched bonuses")
t.eq(forces.GetTechYieldBoost("not-waar-yield-boost-6", 10), nil, "unrelated names do not grant yield bonuses")

t.finish("Finite and optional infinite yield research policy")
assert(not t.has_failures(), "yield research policy test failed")
