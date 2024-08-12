data:extend(
{
  {
  type = "pipe-to-ground",
    name = "offshore-drain",
    icon = "__WaterAsAResource__/graphics/icons/offshore-drain.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"placeable-neutral", "player-creation", "filter-directions"},
    collision_mask = { "object-layer" },
    minable = {mining_time = 0.1, result = "offshore-drain"},
    max_health = 150,
    corpse = "small-remnants",
    resistances =
    {
      {
        type = "fire",
        percent = 70
      },
      {
        type = "impact",
        percent = 30
      }
    },
    collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
    selection_box = {{-1, -1.5}, {1.5, 0.7}},
    fluid_box =
    {
      base_area = 1,
      base_level = 1,
      pipe_covers = pipecoverspictures(),
      production_type = "input",
	  pipe_connections =
      {
        {
          position = {0, 1},
          type = "input"
        },
      },
    },
	working_sound =
    {
      sound =
      {
        {
          filename = "__base__/sound/offshore-pump.ogg",
          volume = 0.4
        }
      },
      match_volume_to_activity = true,
      max_sounds_per_type = 3,
      fade_in_ticks = 10,
      fade_out_ticks = 30,
    },
	min_perceived_performance = 0.5,
    --pumping_speed = 20,
    --tile_width = 1,
    --tile_height = 1,
    vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	underground_sprite =
    {
      filename = "__core__/graphics/arrows/underground-lines.png",
      priority = "extra-high-no-scale",
      width = 1,
      height = 1,
      scale = 0.1
    },
    underground_remove_pipes_sprite =
    {
      filename = "__core__/graphics/arrows/underground-lines-remove.png",
      priority = "high",
      width = 1,
      height = 1,
      x = 0,
      scale = 0.1
    },
    pictures =
    {
      up = -- Input is South
      {
        filename = "__WaterAsAResource__/graphics/entity/offshore-drain.png",
        priority = "high",
        x = 0,
		shift = {1,0},
        width = 160,
        height = 102
      },
      right = -- Input is West
      {
        filename = "__WaterAsAResource__/graphics/entity/offshore-drain.png",
        priority = "high",
        x = 160,
		shift = {0.93,0},
        width = 160,
        height = 102
      },
      down = -- Input it North
      {
        filename = "__WaterAsAResource__/graphics/entity/offshore-drain.png",
        priority = "high",
        x = 320,
        shift = {1,1},
        width = 160,
        height = 102
      },
      left = -- Input is East
      {
        filename = "__WaterAsAResource__/graphics/entity/offshore-drain.png",
        priority = "high",
        x = 480,
		shift = {1,0},
        width = 160,
        height = 102
      }
    },
    placeable_position_visualization =
    {
      filename = "__core__/graphics/cursor-boxes-32x32.png",
      priority = "extra-high-no-scale",
      width = 64,
      height = 64,
      scale = 0.5,
      x = 3*64
    },
    circuit_wire_connection_points = circuit_connector_definitions["offshore-pump"].points,
    circuit_connector_sprites = circuit_connector_definitions["offshore-pump"].sprites,
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
  }
 )