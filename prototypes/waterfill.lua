local function emptyPic()
    return {
        filename = "__core__/graphics/empty.png",
        priority = "high",
        width = 1,
        height = 1,
        shift = {0, 0}
    }
end

-- technology
local waterfill_tech = {
    type = "technology",
    name = "waterfill-tech",
    icon = "__WaterAsAResourceExtended__/graphics/icons/water.png",
    icon_size = 128,
    prerequisites = {
        "landfill",
        "explosives"
    },
    effects = {
        {
            type = "unlock-recipe",
            recipe = "waterfill-recipe"
        }
    },
    unit = {
        count = 100,
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
        },
        time = 30
    },
    order = "b-d"
}

-- recipe
local waterfill_recipe = {
    type = "recipe",
    name = "waterfill-recipe",
    energy_required = 1,
    enabled = false,
    category = "crafting-with-fluid",
    ingredients = {
        {
            type = "item",
            name = "explosives",
            amount = 1,
        },
        {type="fluid", name="water", amount=500},
    },
    result = "waterfill",
    result_count = 3
}

-- item
local waterfill_item = {
    type = "item",
    name = "waterfill",
    tooltip = "wftt",
    icon = "__WaterAsAResourceExtended__/graphics/icons/water.png",
    icon_size = 128,
    flags = {},
    subgroup = data.raw["item"]["landfill"].subgroup,
    order = data.raw["item"]["landfill"].order .. "a",
    stack_size = 100,
    place_result = "waterfill-placer"
}

-- entity (placer)
local waterfill_placer = {
    type = "offshore-pump",
    name = "waterfill-placer",
    icon = "__WaterAsAResourceExtended__/graphics/icons/water.png",
    icon_size = 128,
    picture = emptyPic(),
    collision_mask = {"object-layer", "floor-layer"},
    collision_box = {{-0.2, -0.6}, {0.2, 0.3}},
    center_collision_mask = {"water-tile", "object-layer", "player-layer"},
    flags = {"placeable-neutral", "player-creation", "filter-directions"},
    fluid_box_tile_collision_test = {},
    fluid = "water",
    fluid_box = {
        filter = "water",
        pipe_connections = {
            {
                position = {0, 1},
                type = "output"
            }
        },
        production_type = "none"
    },
    placeable_position_visualization = {
        priority = "extra-high-no-scale",
        filename = "__core__/graphics/cursor-boxes-32x32.png",
        x = 192,
        height = 64,
        width = 64,
        scale = 0.5
    },
    pumping_speed = 1,
}

data:extend({
    waterfill_tech,
    waterfill_recipe,
    waterfill_item,
    waterfill_placer
})

data.raw.tile["water-shallow"].collision_mask = {
    "water-tile",
    "floor-layer",
    "resource-layer",
    "doodad-layer",
}

data.raw.tile["water-mud"].collision_mask = {
    "water-tile",
    "floor-layer",
    "resource-layer",
    "doodad-layer",
}