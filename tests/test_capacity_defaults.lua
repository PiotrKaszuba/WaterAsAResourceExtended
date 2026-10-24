local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")

t.start()

local definitions = {}
assert(loadfile("settings.lua", "t", {
    data = { extend = function(_, values)
        for _, value in ipairs(values) do definitions[value.name] = value end
    end },
}))()

t.eq(definitions["TileFluidAmount-Shallow"].default_value, 200, "actual normal-water default is 200")
t.eq(definitions["TileFluidAmount-Deep"].default_value, 2000, "actual deep-water default is 2000")
t.eq(definitions["TileFluidAmount-Shallow"].setting_type, "startup", "normal-water capacity remains startup-only")
t.eq(definitions["TileFluidAmount-Deep"].setting_type, "startup", "deep-water capacity remains startup-only")

local world, surface = env.create_world()
-- Existing regression fixtures intentionally remain a custom 50/150 profile.
t.eq(settings.startup["TileFluidAmount-Shallow"].value, 50, "custom normal-water fixture remains available")
t.eq(settings.startup["TileFluidAmount-Deep"].value, 150, "custom deep-water fixture remains available")
for _, name in ipairs({ "TileFluidAmount-Shallow", "TileFluidAmount-Deep" }) do
    settings.startup[name].value = definitions[name].default_value
end
settings.global["Waterbody-Regen-Rate"].value = 0

local terrain = {}
for index, name in ipairs({ "water", "water-green", "water-shallow", "water-mud", "deepwater", "deepwater-green" }) do
    terrain[#terrain + 1] = { name = name, position = { x = index - 1, y = 0 } }
end
surface.set_tiles(terrain)
world:build_entity({
    name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 },
})
env.run_ticks(120)

local body = assert(storage.WaterBodies[1], "scanning should create a waterbody")
t.eq(body.waterAreaData.TotalArea, 6, "all six supported water tile variants are scanned")
t.eq(waterbodies.GetAmountWaterForWaterBodyTileType("ShallowWater", true), 200, "normal water uses 200")
t.eq(waterbodies.GetAmountWaterForWaterBodyTileType("ShallowWater-Shallow", true), 100, "waterfill retains half-capacity multiplier")
t.eq(waterbodies.GetAmountWaterForWaterBodyTileType("ShallowWater-Mud", true), 50, "mud retains quarter-capacity multiplier")
t.eq(waterbodies.GetAmountWaterForWaterBodyTileType("DeepWater", true), 2000, "deep water uses 2000")
t.eq(body.waterAreaData.AmountWtr, 4550, "scanned mixed waterbody totals the new tile capacities")

t.finish("Capacity defaults and real scan accounting")
assert(not t.has_failures(), "capacity defaults test failed")
