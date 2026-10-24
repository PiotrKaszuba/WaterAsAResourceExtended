local t = require("tests.helpers.test_assert")
local env = require("tests.helpers.test_env")
local mock = require("tests.mock.factorio_runtime")
t.start()

local function run_case(width, height, fraction, cover_positions, expected_remaining, label)
    local world, surface = env.create_world()
    settings.global["Waterbody-Regen-Rate"].value = 0
    world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = width - 1, y2 = height - 1 })
    world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
        position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
    env.run_ticks(600)
    local body = storage.WaterBodies[1]
    body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr * fraction
    body.waterBodyStateData.TempAvailableWater = waterbodies.calculateRemainingWater(body)
    local terrain, payload = {}, {}
    for _, position in ipairs(cover_positions) do
        terrain[#terrain + 1] = { name = "landfill", position = position }
        payload[#payload + 1] = { old_tile = { name = "water" }, position = position }
    end
    surface.set_tiles(terrain)
    mock.raise_event(defines.events.on_player_built_tile, {
        surface_index = surface.index, player_index = 1, tile = { name = "landfill" }, tiles = payload,
    })
    env.run_ticks(1200)
    local remaining = 0
    for _, live in pairs(storage.ValidWaterBodies) do remaining = remaining + waterbodies.calculateRemainingWater(live) end
    t.ok(math.abs(remaining - expected_remaining) < 1e-7,
        label .. ": remaining " .. remaining .. " equals " .. expected_remaining)
    t.ok(remaining <= width * height * 50 * (1 - fraction) + 1e-7, label .. ": landfill never increases reserves")
end

run_case(5, 1, 0.4, { { x = 4, y = 0 } }, 120, "single removal")
run_case(5, 1, 0.4, { { x = 3, y = 0 }, { x = 4, y = 0 } }, 90, "same-brush sequential removals")
run_case(20, 10, 0.95, {
    { x = 18, y = 3 }, { x = 19, y = 3 }, { x = 18, y = 4 }, { x = 19, y = 4 },
}, 490, "edge brush with pending-owner potential split")

t.finish("Landfill capacity conservation before split reconstruction")
assert(not t.has_failures(), "landfill conservation failed")
