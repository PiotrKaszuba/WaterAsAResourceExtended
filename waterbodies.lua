waterbodies = {}

function waterbodies.WtrName(a) --Random Name Function
	local LName = " Lake"
	local GRName = " Great Lake"
	local SName = " Sea"
	local OName = " Ocean"
	local WaterBodyType = global.WaterGlobalArea[a]["WaterBodyType"]
	if WaterBodyType == 3 then
		RandAmount = #Lakes
		DB = Lakes
	elseif WaterBodyType == 4 then
		RandAmount = #Lakes
		DB = Lakes
	elseif WaterBodyType == 5 then
		RandAmount = #Seas
		DB = Seas
	elseif WaterBodyType == 6 then
		RandAmount = #Oceans
		DB = Oceans
	else
		RandAmount = 1
	end
	if RandAmount ~= 1 then
		local rand = math.random(1,RandAmount)
			if WaterBodyType == 3 then
				WtrName = DB[rand] .. LName
			elseif WaterBodyType == 4 then
				WtrName = DB[rand] .. GRName
			elseif WaterBodyType == 5 then
				WtrName = DB[rand] .. SName
			else
				WtrName = DB[rand] .. OName
			end
		global.WaterGlobalArea[a]["WtrName"] = WtrName
	end
end

Oceans = {"Arctic","Atlantic","Indian","Pacific","Southern"}
Lakes = {"Alakol","Albano","Albert","Alexandrina","Amadeus","Amatitlán","Apanás","Argyle","Assal","Athabasca","Atitlán","Baikal","Balaton","Balkhash","Bangweulu","Baringo","Biel","Big Stone ","Biwa","Bled","Bosumtwi","Bracciano","Bras d’Or ","Buir","Burragorang","Chad","Champlain","Chapala","Chelan","Chiemsee","Chilka ","Chilwa","Chiuta","Chott El-Chergui","Chott El-Hodna","Chott El-Jarid","Chott Melrhir","Chrissie","Chūzenji","Coeur d’Alene","Como","Constance","Crater","Cuitzeo","Derwent","Dhebar","Dian","Dongting","Earn","Edward","Elton","Er","Erie","Eucumbene","Eyasi","Eyre","Faguibine","Fingers","Flathead","Frome","Gairdner","Garda","Gatun","Geneva","George","Great ","Great Bear","Great Salt","Great Slave","Grevelingen","Guier","Ḥammār","Hawea","Hawr Al-Ḥabbāniyyah","Hongze","Hornindals","Hövsgöl","Hulun","Hume Reservoir","Huron","IJsselmeer","Iliamna","Ilmen","Ilopango","Inari","Iseo","Island","Izabal","Kainji","Kariba","Kawartha","Kentucky","Khanka","Kisale","Kivu","Koko Nor","Kolleru","Königssee","Kyoga","Lac Débo","Lac la Ronge","Lac Saint-Jean","Ladoga","Laguna de Bay","Lanao","Last Mountain","Lauricocha","Lesser Slave","Llanquihue","Loch Awe","Loch Katrine","Loch Leven","Loch Lomond","Loch Ness","Loch Shiel","Lough Allen","Lough Corrib","Lough Derg","Lough Erne","Lough Mask","Lough Neagh","Lough Ree","Lucerne","Lugano","Magadi","Maggiore","Mai-Ndombe","Mainit","Mälar","Malebo Pool","Malombe","Managua","Manapouri","Manitoba","Manyara","Mapam","Mar Chiquita","Mead","Melville","Memphremagog","Menindee","Michigan","Mistassini","Mjøsa","Montenegro","Moosehead","Muskoka","Mweru","Mývatn","Nahuel Huapí","Naivasha","Nakuru","Näsi","Nasser","Natron","Naujan","Nemi","Neuchâtel","Neusiedler","Ngami","Nicaragua","Nipigon","Nipissing","Nyasa","Ohrid","Okeechobee","Onega","Ontario","Orta","Päijänne","Peipus","Pend Oreille","Petén Itzá","Pielinen","Pontchartrain","Poopó","Poyang","Prespa","Pukaki","Pulicat","Pyramid","Rainy","Rangeley","Reelfoot","Reindeer","River Tummel","Rotorua","Rudolf","Rukwa","Saimaa","Saint Clair","Sambhar Salt","Saranac","Scutari","Sea of Galilee","Sevan","Sevier","Shala","Siljan","Simcoe","Soap","Soda","Štrbské Pleso","Superior","Taal","Tahoe","Tai","Tana","Tanganyika","Taupo","Te Anau","Tegernsee","Tekapo","Tengiz","Teshekpuk","Texcoco","Thingvalla","Titicaca","Toba","Todos los Santos","Tonle Sap","Torrens","Towada","Trasimeno","Tumba","Tuz","Tyers","Tyri","Tyrrell","Ullswater","Urmia","Utah","Valencia","Van","Väner","Vätter","Victoria","Volta","Võrtsjärv","Waikaremoana","Wakatipu","Wanaka","Windermere","Winnipeg","Winnipegosis","Winnipesaukee","Wissel","Wollaston","Wular","Yellowstone","Yojoa","Ysyk","Zaysan","Zürich"}
Seas = {"Adriatic","Aegean","Albemarle Sound","Alboran","Amundsen","Amundsen Gulf","Andaman","Arabian","Arafura","Archipelago","Arctic Ocean","Argentine","Argolic Gulf","Baffin Bay","Balearic","Bali","Baltic","Banda","Barents","Bass Strait","Bay of Bengal","Bay of Biscay","Bay of Campeche","Bay of Fundy","Beaufort","Bellingshausen","Bering","Bismarck","Black","Block Island Sound","Bohai","Bohol","Bothnian","Buzzards Bay","Camotes","Cantabrian","Cape Cod Bay","Caribbean","Celebes","Celtic","Central Baltic","Ceram","Chesapeake Bay","Chilean","Chukchi","Cilician","Cooperation","Coral","Cosmonauts","Davis","Davis Strait","Delaware Bay","Denmark Strait","Dering Harbor","Drake Passage","D'Urville","East China","East Siberian","English Channel","Fishers Island Sound","Flanders Bay","Flore","Florida Bay","Fort Pond Bay","Gardiners Bay","Golfo de los Mosquitos","Great Australian Bight","Greenland","Gulf of Aden","Gulf of Alaska","Gulf of Carpentaria","Gulf of Corinth","Gulf of Darién","Gulf of Genoa","Gulf of Gonâve","Gulf of Guinea","Gulf of Honduras","Gulf of Lion","Gulf of Maine","Gulf of Martaban","Gulf of Mexico","Gulf of Oman","Gulf of Paria","Gulf of Riga","Gulf of Sidra","Gulf of St. Lawrence","Gulf of Thailand","Gulf of Venezuela","Gulf St Vincent","Halmahera","Hudson Bay","Hudson Strait","Icarian","Inland","Investigator Strait","Ionian","Irish","Irminger","Jamaica Bay","James Bay","Java","Kara","King Haakon VII","Koro","Labrador","Laccadive","Laptev","Lazarev","Levantine","Libyan","Ligurian","Lincoln","Long Beach Bay","Long Island Sound","Lower New York Bay","Mar de Grau","Massachusetts Bay","Mawson","Mediterranean","Mobile Bay","Molucca","Mozambique Channel","Myrtoan","Nantucket Sound","Napeague Bay","Narragansett Bay","New York Bay","North","North  Harbor","North Euboean Gulf","Norwegian","Noyack Bay","Oresund Strait","Pamlico Sound","Pechora","Peconic Bay","Pensacola Bay","Persian Gulf","Philippine","Pipes Cove","Prince Gustav Adolf","Queen Victoria","Raritan Bay","Red","Rhode Island Sound","Riiser-Larsen","Ross","Sag Harbor Bay","Salish","Sandy Hook Bay","Saronic Gulf","Savu","Scotia","Seto Inland","Shelter Island Sound","Sibuyan","Solomon","Somov","South China","South Euboean Gulf","Southold Bay","Spencer Gulf","Sulu","Tampa Bay","Tasman","The Northwest Passages","Thermaic Gulf","Thracian","Three Mile Harbor","Timor","Tobaccolot Bay","Tyrrhenian","Upper New York Bay","Vermillion Bay","Vineyard Sound","Visayan","Wadden","Wandel","Weddell","White","Yellow"}