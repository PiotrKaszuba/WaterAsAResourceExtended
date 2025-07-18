fluidentities = {}

function fluidentities.CheckFluidProducers()
	local FP = storage.FluidProducers
	if storage.FluidProducers ~= nil and #storage.FluidProducers > 0 then
		for a = 1, #storage.FluidProducers, 1 do
			if FP[a]["entity"].valid and FP[a]["entity"].name == "pumpjack" and FP[a]["FluidType"] ~= "crude-oil" then
				FP[a]["FluidType"] = "crude-oil"
			end
		end
		for a = 1, #storage.FluidProducers, 1 do
			if FP[a]["entity"].valid and FP[a]["FluidType"] == "crude-oil" then
				local fluid = FP[a]["entity"].fluidbox.get_flow(1)
				if FP[a]["LastAmount"] ~= fluid then
					FP[a]["LastAmount"] = fluid
				end
			end
		end
	end
end