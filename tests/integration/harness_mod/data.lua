-- Controlled energy-source fixtures, not a claim of testing a third-party ZIP.
-- Based on vanilla offshore pumps; speed/power match the modern pump variants.
local burner = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])
burner.name = "water-test-burner-pump"
burner.minable = nil
burner.energy_source = { type = "burner", fuel_categories = { "chemical" },
    effectivity = 1, fuel_inventory_size = 1 }
burner.energy_usage = "900kW"
burner.pumping_speed = 5
local electric = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])
electric.name = "water-test-electric-pump"
electric.minable = nil
electric.energy_source = { type = "electric", usage_priority = "secondary-input" }
electric.energy_usage = "450kW"
local source = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name = "water-test-power"
source.energy_source.buffer_capacity = "100MJ"
source.energy_source.usage_priority = "primary-output"
source.energy_production = "10MW"
source.energy_usage = "0W"
data:extend({ burner, electric, source })

local recipe = data.raw.recipe["waterfill-recipe"]
if recipe then assert(recipe.allow_productivity == false, "Waterfill must prohibit productivity") end
