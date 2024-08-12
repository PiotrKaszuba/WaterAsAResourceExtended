
data:extend(
{
	{
    name = "crude-oil",
    type = "tile",
    collision_mask =
    {
      "water-tile",
	  "item-layer",
      "resource-layer",
      "player-layer",
      "doodad-layer"
    },
    autoplace = nil,
    draw_in_water_layer = true,
	pollution_absorption_per_second = 0,
    layer = 2,
    variants = {
      main =
      {
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil1.png",
          count = 8,
          size = 1,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-hr1.png",
            count = 8,
            scale = 0.5,
            size = 1
          }
        },
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil2.png",
          count = 8,
          size = 2,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-hr2.png",
            count = 8,
            scale = 0.5,
            size = 2
          }
        },
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil4.png",
          count = 8,
          size = 4,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-hr4.png",
            count = 8,
            scale = 0.5,
            size = 4
          }
        }
      },
      inner_corner =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-inner-corner.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-inner-corner-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      outer_corner =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-outer-corner.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-outer-corner-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      side =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-side.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-side-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      u_transition =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-u.png",
        count = 1,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-u-hr.png",
          count = 1,
          scale = 0.5
        }
      },
      o_transition =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-o.png",
        count = 1,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil/crude-oil-o-hr.png",
          count = 1,
          scale = 0.5
        }
      },
    },
    --allowed_neighbors = { "grass-1" },
    map_color={r=128, g=128, b=128},
    ageing=0.0006
  },
  {
    name = "crude-oil-deep",
    type = "tile",
    collision_mask =
    {
	  "water-tile",
      "resource-layer",
      "item-layer",
      "player-layer",
      "doodad-layer"
    },
    autoplace = nil,
    draw_in_water_layer = true,
	pollution_absorption_per_second = 0,
    layer = 4,
    variants = {
      main =
      {
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep1.png",
          count = 8,
          size = 1,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep1-hr.png",
            count = 8,
            scale = 0.5,
            size = 1
          }
        },
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep2.png",
          count = 8,
          size = 2,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep2-hr.png",
            count = 8,
            scale = 0.5,
            size = 2
          }
        },
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep4.png",
          count = 8,
          size = 4,
          hr_version =
          {
            picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep4-hr.png",
            count = 8,
            scale = 0.5,
            size = 4
          }
        }
      },
      inner_corner =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-inner-corner.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-inner-corner-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      outer_corner =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-outer-corner.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-outer-corner-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      side =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-side.png",
        count = 6,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-side-hr.png",
          count = 6,
          scale = 0.5
        }
      },
      u_transition =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-u.png",
        count = 1,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-u-hr.png",
          count = 1,
          scale = 0.5
        }
      },
      o_transition =
      {
        picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-o.png",
        count = 1,
        hr_version =
        {
          picture = "__WaterAsAResource__/graphics/terrain/crude-oil-deep/crude-oil-deep-o-hr.png",
          count = 1,
          scale = 0.5
        }
      }
    },
    allowed_neighbors = { "crude-oil" },
    map_color={r=48, g=48, b=48},
    ageing=0.0006
  }
}
)