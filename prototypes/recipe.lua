data:extend(
{ 
	{
    type = "recipe",
    name = "offshore-pump-nofluid",
	enabled = false,
    ingredients =
    {
      {type="item", name="electronic-circuit", amount=2},
      {type="item", name="pipe", amount=1},
      {type="item", name="iron-gear-wheel", amount=1}
    },
    results = {{type="item", name="offshore-pump-nofluid", amount=1}}
  },
  -- 	{
  --   type = "recipe",
  --   name = "offshore-drain",
	-- enabled = false,
  --   ingredients =
  --   {
  --     {type="item", name="electronic-circuit", amount=2},
  --     {type="item", name="pipe", amount=1},
  --     {type="item", name="iron-gear-wheel", amount=1}
  --   },
  --   results = {{type="item", name="offshore-drain", amount=1}}
  -- },
  -- {
  --   type = "recipe",
  --   name = "offshore-crude-oil-pump",
	-- enabled = false,
  --   ingredients =
  --   {
  --     {type="item", name="electronic-circuit", amount=2},
  --     {type="item", name="pipe", amount=1},
  --     {type="item", name="iron-gear-wheel", amount=1}
  --   },
  --   results = {{type="item", name="offshore-crude-oil-pump", amount=1}}
  -- }
}
)