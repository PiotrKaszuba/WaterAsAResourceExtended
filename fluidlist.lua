fluidlist = {}

FluidNames = {"water","deepwater","water-shallow","water-mud","water-green","deepwater-green"}

function fluidlist.CheckNames(fluidname)
	for a = #FluidNames, 1, -1 do
		if fluidname == FluidNames[a] then
			if fluidname == "water" or fluidname == "water-shallow" or fluidname == "water-mud" or fluidname == "water-green" then
				return "shallow"
			else
				return "deep"
			end
		end
	end
end
