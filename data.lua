require("prototypes.entities")
require("prototypes.item")
require("prototypes.recipe")
require("prototypes.tiles")
require("prototypes.technology")
require("util")

--data.raw.item["offshore-pump"].icon = "__WaterAsAResource__/graphics/icons/offshore-pump.png"

local offshorenofluid = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

offshorenofluid.name ="offshore-pump-nofluid"
offshorenofluid.pumping_speed = 0.1
offshorenofluid.collision_box = {{-0.6, -0.55}, {0.6, 0.3}}
offshorenofluid.fluid_box = {base_area = 1,base_level = 1,pipe_covers = pipecoverspictures(),production_type = "output",pipe_connections = { {position = {0, -0.56},type = "output"}, }, }
offshorenofluid.placeable_by = {item = "offshore-pump", count = 1}

local offshorecrudeoil = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

offshorecrudeoil.name = "offshore-crude-oil-pump"
offshorecrudeoil.fluid = "crude-oil"
offshorecrudeoil.pumping_speed = 20
offshorecrudeoil.fluid_box ={base_area = 1,base_level = 1,pipe_covers = pipecoverspictures(),production_type = "output",filter = "crude-oil",pipe_connections ={ {position = {0, 1},type = "output" }, }, }
offshorecrudeoil.placeable_by = {item = "offshore-pump", count = 1}

local lakeshallow = table.deepcopy(data.raw["tile"]["sand-3"])
lakeshallow.name = "lake-shallow"
lakeshallow.autoplace = nil

local lakedeep = table.deepcopy(data.raw["tile"]["dry-dirt"])
lakedeep.name = "lake-deep"
lakedeep.autoplace = nil

data:extend({offshorenofluid, offshorecrudeoil, lakeshallow, lakedeep})

table.insert(water_tile_type_names, "crude-oil")
table.insert(water_tile_type_names, "crude-oil-deep")

if mods["alien-biomes"] then
	alien_biomes_priority_tiles = alien_biomes_priority_tiles or {}
	table.insert(alien_biomes_priority_tiles,"lake-shallow")
	table.insert(alien_biomes_priority_tiles,"lake-deep")
	table.insert(alien_biomes_priority_tiles,"crude-oil")
	table.insert(alien_biomes_priority_tiles,"crude-oil-deep")
end