require("prototypes.technology")
require("prototypes.waterfill")
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
