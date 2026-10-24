-- EXPECTED FAILURE: deliberately deferred; excluded from the default suite.
-- Run from the mod root: lua tests/deferred/test_pending_landfill_visual_race.lua
local env = require("tests.helpers.test_env")
local world, surface = env.create_world()
settings.global["Waterbody-Regen-Rate"].value = 0
world:set_water_rectangle(surface, { x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
world:build_entity({ name = "offshore-pump", type = "offshore-pump", surface = surface,
    position = { x = 0, y = -1 }, input_position = { x = 0, y = 0 } })
env.run_ticks(120)
local body = storage.WaterBodies[1]
assert(body and body.valid and body.searchData.finished, "fixture must finish scanning")
-- The resource is exhausted, but the scheduled visual update has not run yet.
body.waterBodyStateData.WaterUsed = body.waterAreaData.AmountWtr
body.waterBodyStateData.TempAvailableWater = 0
waterbody_depletion.updateDepletionAppearanceCount(body)
assert(body.waterBodyStateData.ToDryTiles == 1, "fixture must have pending visual drying")
local position = { x = 0, y = 0 }
local oldName = surface.get_tile(position).name
surface.set_tiles({ { name = "landfill", position = position } })
event_handlers.handlePlayerTileEvents({ surface_index = surface.index,
    tile = { name = "landfill" }, tiles = { { position = position, old_tile = { name = oldName } } } })
assert(tiles.getTileEventQueue().size == 1, "landfill accounting must still be pending")
assert(surface.get_tile(position).name == "landfill", "successful placement must be visible")
-- The normal extra-work path runs before the next accounting BigUpdate.
waterbody_update.processToDryTilesFirst({ budget = 1000 }, 0.01)
local actual = surface.get_tile(position).name
print("Pending landfill visual race: expected landfill, observed " .. actual)
assert(actual == "landfill", "DEFERRED DEFECT: stale visual drying overwrote placed landfill")
