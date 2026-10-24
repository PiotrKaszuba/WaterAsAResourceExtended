require("prototypes.technology")
if settings.startup["Enable-Waterfill"].value then
    require("prototypes.waterfill")
end
require("util")

local lakeshallow = table.deepcopy(data.raw["tile"]["sand-3"])
lakeshallow.name = "lake-shallow"
lakeshallow.autoplace = nil

local lakedeep = table.deepcopy(data.raw["tile"]["dry-dirt"])
lakedeep.name = "lake-deep"
lakedeep.autoplace = nil

data:extend({
	lakeshallow,
	lakedeep
})

local dryNames = { "lake-shallow", "lake-deep" }
for _, identity in ipairs(require("shared.water_tiles")) do
    local tile = table.deepcopy(data.raw.tile[identity.appearance])
    tile.name = identity.dry
    tile.localised_name = { "tile-name." .. identity.appearance }
    tile.transition_merges_with_tile = identity.appearance
    data:extend({ tile })
    dryNames[#dryNames + 1] = tile.name
end

local placement = data.raw.item.landfill.place_as_tile
if placement then
    -- The explicit whitelist still limits placement to water and depleted beds.
    -- Keep other mods' conditions and whitelist entries intact.
    if placement.condition and placement.condition.layers then
        placement.condition.layers.ground_tile = nil
    end
    placement.tile_condition = placement.tile_condition or {}
    local present = {}
    for _, name in ipairs(placement.tile_condition) do present[name] = true end
    for _, name in ipairs(dryNames) do
        if not present[name] then placement.tile_condition[#placement.tile_condition + 1] = name end
    end
end
