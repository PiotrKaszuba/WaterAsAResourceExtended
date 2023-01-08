data:extend({
    {
        type = "bool-setting",
        name = "Alarms-Low-Level (50/75/90%)",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "Alarms-High-Level (95/97/98/99%)",
        setting_type = "runtime-global",
        default_value = true
    },
	{
        type = "bool-setting",
        name = "Alarms-Landfill Message",
        setting_type = "runtime-per-user",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "Disable-RestoreWater-Command",
        setting_type = "runtime-global",
        default_value = false
    },
    {
        type = "int-setting",
        name = "FluidArea-Start-Area",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 100,
        maximum_value = 100000
    },
	{
        type = "int-setting",
        name = "FluidArea-Additional-Tiles-Per-Second",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 10,
        maximum_value = 50000
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
        default_value = 100,
        minimum_value = 20,
        maximum_value = 10000
    },
	    {
        type = "bool-setting",
        name = "Alarms-Continuing-Search",
        setting_type = "runtime-per-user",
        default_value = true
    },
		{
        type = "int-setting",
        name = "FluidArea-RegenRate",
        setting_type = "runtime-global",
        default_value = 10, 
        minimum_value = 1,
        maximum_value = 100
    },
	{
        type = "bool-setting",
        name = "Disable-FluidArea-RegenRate",
        setting_type = "runtime-global",
        default_value = false
    },
	{
        type = "string-setting",
        name = "FluidArea-Replace-Method",
		setting_type = "runtime-global",
        allowed_values = {"Random","From/To Pump"},
        default_value = "From/To Pump"
    },
	{
        type = "int-setting",
        name = "FluidArea-RereplacePumps",
        setting_type = "runtime-global",
        default_value = 25, 
        minimum_value = 0,
        maximum_value = 100
    },
	{
        type = "int-setting",
        name = "FluidArea-ReactivateDrains",
        setting_type = "runtime-global",
        default_value = 75, 
        minimum_value = 0,
        maximum_value = 100
    },
	{
        type = "bool-setting",
        name = "FluidArea-RemoveFromTable",
        setting_type = "runtime-global",
        default_value = false
    },
	{
        type = "bool-setting",
        name = "FluidArea-DebugQueueLength",
        setting_type = "runtime-global",
        default_value = false
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
        default_value = 2000000, 
        minimum_value = 600000,
        maximum_value = 9999999999
    },
})