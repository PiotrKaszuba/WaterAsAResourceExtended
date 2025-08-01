require("prototypes.technology")
require("prototypes.waterfill")
require("util")
-- require ("base.prototypes.entities.pipecovers")


local offshorenofluid = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])

offshorenofluid.name ="offshore-pump-nofluid"
offshorenofluid.pumping_speed = 0.1
offshorenofluid.collision_box = {{-0.6, -0.55}, {0.6, 0.3}}
offshorenofluid.fluid_box = {volume=100,pipe_covers = pipecoverspictures(),production_type = "output",pipe_connections = { {position = {0, -0.54},flow_direction = "output", direction=0}, }, }
offshorenofluid.placeable_by = {item = "offshore-pump", count = 1}


local lakeshallow = table.deepcopy(data.raw["tile"]["sand-3"])
lakeshallow.name = "lake-shallow"
lakeshallow.autoplace = nil

local lakedeep = table.deepcopy(data.raw["tile"]["dry-dirt"])
lakedeep.name = "lake-deep"
lakedeep.autoplace = nil

data:extend({
	offshorenofluid,
	lakeshallow,
	lakedeep,
})
