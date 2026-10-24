local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")

t.start()

local definitions = {}
assert(loadfile("settings.lua", "t", {
    data = { extend = function(_, values)
        for _, value in ipairs(values) do definitions[value.name] = value end
    end },
}))()
local definition = definitions["Waterfill-Efficiency"]
t.eq(definition.type, "int-setting", "relocation efficiency is an integer")
t.eq(definition.setting_type, "startup", "relocation efficiency is startup-only")
t.eq(definition.default_value, 25, "default relocation efficiency is 25 percent")
t.eq(definition.minimum_value, 1, "minimum relocation efficiency is 1 percent")
t.eq(definition.maximum_value, 100, "maximum relocation efficiency is 100 percent")

local function load_recipe(shallow_capacity, efficiency)
    local data_fixture = { raw = {
        tile = { ["water-shallow"] = { collision_mask = { layers = {} } } },
        item = { landfill = { subgroup = "terrain", order = "a" } },
    } }
    function data_fixture:extend(values)
        for _, value in ipairs(values) do
            self.raw[value.type] = self.raw[value.type] or {}
            self.raw[value.type][value.name] = value
        end
    end
    assert(loadfile("prototypes/waterfill.lua", "t", {
        data = data_fixture, math = math,
        settings = { startup = {
            ["TileFluidAmount-Shallow"] = { value = shallow_capacity },
            ["Waterfill-Efficiency"] = { value = efficiency },
        } },
    }))()
    local recipe = data_fixture.raw.recipe["waterfill-recipe"]
    return recipe, recipe.ingredients[2].amount
end

env.create_world()
for _, shallow in ipairs({ 10, 11, 200, 201, 5000 }) do
    settings.startup["TileFluidAmount-Shallow"].value = shallow
    local tile_capacity = waterbodies.GetAmountWaterForWaterBodyTileType("ShallowWater-Shallow", true)
    for _, efficiency in ipairs({ 1, 25, 37, 38, 50, 100 }) do
        local recipe, cost = load_recipe(shallow, efficiency)
        local added = recipe.results[1].amount * tile_capacity
        local exact_cost = added / (efficiency / 100)
        local label = shallow .. " capacity, " .. efficiency .. "% efficiency"
        t.ok(cost >= exact_cost and cost < exact_cost + 1, "recipe rounds required input upward: " .. label)
        t.ok(cost >= added, "resulting lake water never exceeds recipe fluid input: " .. label)
        t.eq(recipe.allow_productivity, false, "productivity cannot multiply waterfill output: " .. label)
    end
end

local _, default_cost = load_recipe(definitions["TileFluidAmount-Shallow"].default_value, definition.default_value)
t.eq(default_cost, 1200, "default batch consumes 1200 water")
local multiplier = forces.GetTechYieldBoost("waar-yield-boost-6", 6)
t.ok(math.abs(multiplier - 0.85 ^ 6) < 1e-12, "current maximum yield effect is level 6")
t.eq(forces.GetTechYieldBoost("waar-yield-boost-6", 100), multiplier, "later repeat levels currently retain the same effect")
t.ok(default_cost * multiplier > 300, "default recipe loses reserve water even with current maximum yield bonus")
local _, safe_cost = load_recipe(200, 37)
local _, unsafe_cost = load_recipe(200, 38)
t.ok(safe_cost * multiplier >= 300, "37 percent is conservative at default capacities with current research")
t.ok(unsafe_cost * multiplier < 300, "38 percent can gain reserves at default capacities with current research")
t.ok(default_cost * 0.85 ^ 9 < 300, "a genuine future level-9 bonus would require reassessing the default")

local world, surface = env.create_world()
settings.startup["TileFluidAmount-Shallow"].value = definitions["TileFluidAmount-Shallow"].default_value
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 1, y2 = 0 })
world:build_entity({
    name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 },
})
env.run_ticks(120)
local body = assert(storage.WaterBodies[1])
body.waterBodyStateData.WaterUsed = 200
body.waterBodyStateData.TempAvailableWater = waterbodies.calculateRemainingWater(body)
local remaining_before = waterbodies.calculateRemainingWater(body)
world:waterfill(surface, { x = 2, y = 0 })
env.run_ticks(120)
t.eq(body.waterBodyStateData.WaterUsed, 200, "waterfill does not scale existing absolute depletion")
t.eq(waterbodies.calculateRemainingWater(body) - remaining_before, 100, "waterfill adds full tile capacity to a partly depleted lake")

t.finish("Waterfill recipe efficiency and reserve accounting")
assert(not t.has_failures(), "waterfill efficiency test failed")
