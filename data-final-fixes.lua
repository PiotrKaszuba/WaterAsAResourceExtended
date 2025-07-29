require("prototypes.recipe")

local max_waterbodies = settings.startup["Force-Max-Waterbodies"].value


for i = 1, max_waterbodies do
    local offshore_pump = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])
    offshore_pump.name = "offshore-pump-x-" .. i

    data:extend({
        {
        type = "item",
        name = offshore_pump.name,
        icon = "__base__/graphics/icons/signal/signal_everything.png",
        icon_size = 64,
        icon_mipmaps = 1,
        stack_size = 100,
        place_result = offshore_pump.name,
      }

    })
    data:extend({offshore_pump})
   
end







