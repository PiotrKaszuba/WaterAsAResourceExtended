local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
local t = require("tests.helpers.test_assert")
t.start()
local world, surface = env.create_world()
local setting = settings.global["Waterbody-Regen-Enabled-By-Size"]
local areas = { 1, 3, 4, 200, 6000, 60000, 600000 }
for i, area in ipairs(areas) do
    t.eq(waterbodies.GetWaterBodyType(area), i - 1, "ordered size boundary " .. i)
    setting.value = string.rep("0", i - 1) .. "1" .. string.rep("0", 7 - i)
    for j, other_area in ipairs(areas) do
        t.eq(waterbodies.GetWaterBodyRegen(other_area, 1) > 0, i == j,
            "mask position " .. i .. " controls class " .. j)
    end
end
for _, invalid in ipairs({ "", "111111", "11111111", "111x111", "1,1,1,1,1,1,1" }) do
    setting.value = invalid
    t.eq(waterbodies.getRegenerationMask(), "1111111", "invalid mask falls back: " .. invalid)
end
setting.value = " 0000001 "
t.eq(waterbodies.getRegenerationMask(), "0000001", "leading zeros retained and outer whitespace trimmed")

setting.value = "1111111"
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 4, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(120)
local body = storage.WaterBodies[1]
local original = body.waterAreaData.RegenAmount
setting.value = "0000001"
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Enabled-By-Size" })
t.eq(body.waterAreaData.RegenAmount, 0, "mask edit disables existing pond")
setting.value = "1111111"
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Enabled-By-Size" })
t.eq(body.waterAreaData.RegenAmount, original, "mask edit reenables existing pond")
setting.value = "0000001"
waterbodies.CalculateAndUpdateWaterBodyAreaData(body)
t.eq(body.waterAreaData.RegenAmount, 0, "topology recalculation obeys mask")
setting.value = "invalid"
local warnings = 0
game.print = function() warnings = warnings + 1 end
mock.raise_event(defines.events.on_runtime_mod_setting_changed, { setting = "Waterbody-Regen-Enabled-By-Size" })
for _ = 1, 5 do waterbodies.GetWaterBodyRegen(200, 1) end
t.eq(warnings, 1, "invalid edit warns once rather than per waterbody/update")
t.finish("Regeneration size mask")
