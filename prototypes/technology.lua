local waar_yield_regen_boost_icon = "__WaterAsAResource__/graphics/technology/waar-yield-regen-boost-1.png"

data:extend(
{
  {
    type = "technology",
    name = "waar-yield-regen-boost-1",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 20%"
        --modifier = 0.1
      }
    },
    unit =
    {
      count = 100*1,
      ingredients =
      {
        {"automation-science-pack", 1}
      },
      time = 30
    },
    upgrade = true,
    order = "e-l-a"
  },
  {
    type = "technology",
    name = "waar-yield-regen-boost-2",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 40%"
        --modifier = 0.1
      }
     },
    prerequisites = {"fluid-handling","waar-yield-regen-boost-1"},
    unit =
    {
      count = 100*2,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 30
    },
    upgrade = true,
    order = "e-l-b"
  },
	{
    type = "technology",
    name = "waar-yield-regen-boost-3",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 60%"
        --modifier = 0.2
      }
    },
    prerequisites = {"waar-yield-regen-boost-2"},
    unit =
    {
      count = 100*3,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 60
    },
    upgrade = true,
    order = "e-l-c"
  },
  {
    type = "technology",
    name = "waar-yield-regen-boost-4",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 80%"
        --modifier = 0.2
      }
    },
    prerequisites = {"chemical-science-pack","waar-yield-regen-boost-3"},
    unit =
    {
      count = 100*4,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
		{"chemical-science-pack", 1}
      },
      time = 60
    },
    upgrade = true,
    order = "e-l-d"
  },
  {
    type = "technology",
    name = "waar-yield-regen-boost-5",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 100%"
        --modifier = 0.2
      }
    },
    prerequisites = {"utility-science-pack","waar-yield-regen-boost-4"},
    unit =
    {
      count = 100*5,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
		{"utility-science-pack", 1}
      },
      time = 60
    },
    upgrade = true,
    order = "e-l-e"
  },
   {
    type = "technology",
    name = "waar-yield-regen-boost-6",
    icon_size = 256, icon_mipmaps = 4,
    icons = util.technology_icon_constant_speed(waar_yield_regen_boost_icon),
    effects =
    {
      {
        type = "nothing",
		effect_description = "Increase the fluid area size and regen by 100% + 20% per loop"
        --modifier = 0.1
      }
    },
    prerequisites = {"waar-yield-regen-boost-5", "space-science-pack"},
    unit =
    {
      count_formula = "2^(L-5)*1000",
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60
    },
    max_level = "infinite",
    upgrade = true,
    order = "e-l-f"
  }
  
})
