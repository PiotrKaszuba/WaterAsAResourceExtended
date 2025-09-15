data:extend({
    {
        type = "bool-setting",
        name = "Alarms-Low-Level",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "Alarms-High-Level",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "Alarms-Tile-Message",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "int-setting",
        name = "FluidArea-Start-Area",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 10,
        maximum_value = 1000
    },
	{
        type = "int-setting",
        name = "FluidArea-Additional-Tiles-Per-Second",
        setting_type = "runtime-global",
        default_value = 200,
        minimum_value = 50,
        maximum_value = 10000
    },
	{
        type = "int-setting",
        name = "TileFluidAmount-Shallow",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 10,
        maximum_value = 5000
    },
	{
        type = "int-setting",
        name = "TileFluidAmount-Deep",
        setting_type = "runtime-global",
        default_value = 150,
        minimum_value = 20,
        maximum_value = 10000
    },
	{
        type = "int-setting",
        name = "FluidArea-RegenRate",
        setting_type = "runtime-global",
        default_value = 100, 
        minimum_value = 0,
        maximum_value = 1000
    },
    {
        type = "int-setting",
        name = "Visual-Depletion-Start-Percentage",
        setting_type = "runtime-global",
        default_value = 80,
        minimum_value = 50,
        maximum_value = 95,
    },
	{
        type = "int-setting",
        name = "Pumps-Reactivation-LevelPerThousand",
        setting_type = "runtime-global",
        default_value = 990,
        minimum_value = 1,
        maximum_value = 1000
    },
	{
        type = "bool-setting",
        name = "FluidArea-RemoveDepletedOrphaned",
        setting_type = "runtime-global",
        default_value = true
    },
	{
        type = "bool-setting",
        name = "Map-EnableMarkers",
        setting_type = "runtime-global",
        default_value = true
    },
{
        type = "int-setting",
        name = "FluidArea-MaxFluidAreaSize",
        setting_type = "runtime-global",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 9999999999
    },
    {
        type = "int-setting",
        name = "Update-Budget-Per-Second",
        setting_type = "runtime-global",
        default_value = 200, 
        minimum_value = 50,
        maximum_value = 10000
    },
    {
        type = "bool-setting",
        name = "Splits-EnableFamilies",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "int-setting",
        name = "Splits-Family-Timeout-Seconds",
        setting_type = "runtime-global",
        default_value = 120,
        minimum_value = 0,
        maximum_value = 36000
    },
    {
        type = "double-setting",
        name = "Splits-Reeval-Threshold",
        setting_type = "runtime-global",
        default_value = 0.10,
        minimum_value = 0.0,
        maximum_value = 1.0
    },
    {
        type = "int-setting",
        name = "Split-Max-BBox-Side",
        setting_type = "runtime-global",
        default_value = 32,
        minimum_value = 8,
        maximum_value = 1024
    },

})