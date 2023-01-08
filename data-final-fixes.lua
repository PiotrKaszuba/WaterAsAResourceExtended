require("prototypes.recipe")

table.insert(data.raw["technology"]["fluid-handling"].effects, {type = "unlock-recipe",recipe = "offshore-drain"})

if mods["bobelectronics"] then
	bobmods.lib.recipe.replace_ingredient("offshore-drain","electronic-circuit","basic-circuit-board")
end

if mods["aai-industry"] then
	data:extend({{
    type = "recipe",
    name = "offshore-drain",
	enabled = false,
	ingredients =
		{
			{type="item", name="electric-motor", amount=2},
			{type="item", name="pipe", amount=4}
		},
	result = "offshore-drain"
	}})
	for a = 1, #data.raw["technology"]["fluid-handling"].effects, 1 do
		if data.raw["technology"]["fluid-handling"].effects[a].type == "unlock-recipe" and data.raw["technology"]["fluid-handling"].effects[a].recipe == "offshore-drain" then
			table.remove(data.raw["technology"]["fluid-handling"].effects, a)
		end
	end
	if mods["Krastorio2"] then
		table.insert(data.raw["technology"]["kr-basic-fluid-handling"].effects, {type = "unlock-recipe",recipe = "offshore-drain"})
	else
		table.insert(data.raw["technology"]["basic-fluid-handling"].effects, {type = "unlock-recipe",recipe = "offshore-drain"})
	end
end