ESX = nil
-- Don't touch any of these please....
local playerData
local IsAnimated, NPCBlip, RBlip, jobNPC, canceljob, inMission, ClientList, jobName = false, false, false, false, false, false, {}, Config.JobName

-- Notification Settings
notify = function(type, msg, duration, title)
	if type ~= nil and msg ~= nil then
		if Config.Notification.client == "ns" then
			if type == 1 then
				exports["ns_notify"]:sendNotify(title, msg, duration, "success")
			elseif type == 2 then
				exports["ns_notify"]:sendNotify(title, msg, duration, "info")
			elseif type == 3 then
				exports["ns_notify"]:sendNotify(title, msg, duration, "error")
			elseif type == 4 then
				exports["ns_notify"]:sendNotify(title, msg, duration, "warning")
			end
		elseif Config.Notification.client == "mythic_old" then
			if type == 1 then
				exports["mythic_notify"]:DoCustomHudText("success", msg, 10000)
			elseif type == 2 then
				exports["mythic_notify"]:DoCustomHudText("inform", msg, 10000)
			elseif type == 3 or 4 then
				exports["mythic_notify"]:DoCustomHudText("error", msg, 10000)
			end
		elseif Config.Notification.client == "mythic_new" then
			if type == 1 then
				exports["mythic_notify"]:SendAlert("success", msg, {
					["background-color"] = "#ffffff",
					["color"] = "#000000",
				})
			elseif type == 2 then
				exports["mythic_notify"]:SendAlert("inform", msg, {
					["background-color"] = "#ffffff",
					["color"] = "#000000",
				})
			elseif type == 3 or 4 then
				exports["mythic_notify"]:SendAlert("error", msg, {
					["background-color"] = "#ffffff",
					["color"] = "#000000",
				})
			end
		elseif Config.Notification.client == "esx" then
			ESX.ShowNotification(msg)
		elseif Config.Notification.client == "chat" then
			TriggerEvent("chat:addMessage", {
				color = {255, 0, 0},
				multiline = true,
				args = {"Me", msg},
			})
		elseif Config.Notification.client == "custom" then
			-- Insert Custom Notification here
		end
	end
end

RegisterCommand(Config.Command, function()
	MissionCancel()
	inMission = false
end)

-- In case someone job changes
RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(j) playerData.job = j end)

-- Fail the mission in case die
AddEventHandler("esx:onPlayerDeath", function(data)
	MissionCancel()
	inMission = false
end)

-- This event exists to make sure people get the correct drink from the drink tray. Doesn't make sense to me, but it magically works, so don't fucking touch it.
RegisterNetEvent("BLBartender:AssignDrink", function(id, tsource)
	table.insert(ClientList, {
		id = id,
		player = tsource,
	})
end)

-- Drunk effects
RegisterNetEvent("BLBartender:onDrink2")
AddEventHandler("BLBartender:onDrink2", function(prop_name)
	if not IsAnimated then
		if not prop_name then prop_name = "prop_beer_patriot" end
		IsAnimated = true
		Citizen.CreateThread(function()
			local playerPed = PlayerPedId()
			local x, y, z = table.unpack(GetEntityCoords(playerPed))
			local prop = CreateObject(GetHashKey(prop_name), x, y, z + 0.2, true, true, true)
			local boneIndex = GetPedBoneIndex(playerPed, 18905)
			AttachEntityToEntity(prop, playerPed, boneIndex, 0.12, 0.028, 0.001, 270.0, 170.0, -10.0, true, true, false, true, 1, true)

			ESX.Streaming.RequestAnimDict("mp_player_intdrink", function()
				TaskPlayAnim(playerPed, "mp_player_intdrink", "loop_bottle", 1.0, -1.0, 2000, 0, 1, true, true, true)

				Citizen.Wait(3000)
				IsAnimated = false
				ClearPedSecondaryTask(playerPed)
				DeleteObject(prop)
			end)
		end)
	end
	notify(1, _U("drinking"), 5000, "Time to Get Drunk")
end)

-- Help Notification
function showHelpNotification(msg)
	AddTextEntry("shopsHelpNotif", msg)
	DisplayHelpTextThisFrame("shopsHelpNotif", false)
end

-- ESX Setup
setupEsx = function()
	while not ESX do
		TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
		Wait(100)
	end
	while not ESX.IsPlayerLoaded() do Wait(1000) end
	playerData = ESX.GetPlayerData()
end

-- Blip Setup
setupBlips = function()
	local blip = AddBlipForCoord(Config.Blips.Location)
	SetBlipSprite(blip, Config.Blips.BlipType)
	SetBlipScale(blip, Config.Blips.BlipSize)
	SetBlipColour(blip, Config.Blips.BlipColor)
	SetBlipAsShortRange(blip, true)
	SetBlipDisplay(blip, Config.Blips.BlipDisplay or 2)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(Config.Blips.Label)
	EndTextCommandSetBlipName(blip)
end

-- Get Closest Marker
getClosestMarker = function(pos)
	local closest, dist, posi
	for k, v in pairs(Config.Bartender) do
		local d = #(v.pos - pos)
		if not dist or d < dist then
			posi = v.pos
			closest = k
			dist = d
		end
	end
	return closest, dist, posi
end

-- Open Boss Menu Function
OpenBossMenu = function()
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open("default", GetCurrentResourceName(), "bartender_boss_menu", {
		title = _U("boss_menu"),
		align = Config.MenuAlign,
		elements = {
			{
				label = _U("employeeactions"),
				value = "employee_actions",
			}, -- Hire | Fire // Promote | Demote // Salary Adjustment
			{
				label = _U("moneyactions"),
				value = "money_actions",
			}, -- Display Current Money | Withdraw | Deposit
			{
				label = _U("recipebookactions"),
				value = "add_recipebook",
			}, -- Display Recipe Book | Add Recipe Items
			{
				label = _U("orderraw"),
				value = "order_raw",
			}, -- Order Raw Materials
			{
				label = _U("learnRecipes"),
				value = "order_recipes",
			}, -- Learn New Recipes
		},
	}, function(data, menu)
		if data.current.value == "employee_actions" then
			OpenEmploymentActions()
		elseif data.current.value == "money_actions" then
			OpenMoneyActions()
		elseif data.current.value == "add_recipebook" then
			OpenRecipeBook()
		elseif data.current.value == "order_raw" then
			OpenRawOrder()
		elseif data.current.value == "order_recipes" then
			OpenOrderRecipes()
		end
	end, function(data, menu) menu.close() end)
end

-- Go pickup Recipe from NPC
FetchMission = function()
	local ped = PlayerPedId()
	local dist = 500000
	local pedcreated, pedgreet = false, false

	-- Fetch Blip Settings
	NPCBlip = AddBlipForCoord(Config.FetchXYZ)
	SetBlipSprite(NPCBlip, 309)
	SetBlipScale(NPCBlip, 0.8)
	SetBlipColour(NPCBlip, 27)
	SetBlipAsShortRange(NPCBlip, true)
	SetBlipDisplay(NPCBlip, 2)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName("Recipe Reward")
	EndTextCommandSetBlipName(NPCBlip)

	SetBlipRoute(NPCBlip, true)
	notify(1, _U("fetch"), 5000, "Go Get It!")
	inMission = true
	while not canceljob do
		Citizen.Wait(1)
		local pos = GetEntityCoords(ped)
		dist = #(Config.FetchXYZ - pos)

		if dist > 75 then
			Citizen.Wait(500)
			if pedcreated then
				pedcreated = false
				DeleteEntity(jobNPC)
			end
		end

		if dist < 75 and not pedcreated then
			if Config.FetchNPC then
				RequestModel(Config.NPCModel)
				while not HasModelLoaded(Config.NPCModel) do Wait(10) end
				RequestAnimDict("mini@strip_club@idles@bouncer@base")
				while not HasAnimDictLoaded("mini@strip_club@idles@bouncer@base") do Wait(10) end
				local NPC = CreatePed(4, Config.NPCModel, Config.NPCCoords, true, true)
				NetworkRegisterEntityAsNetworked(NPC)
				SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(NPC), true)
				SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(NPC), true)
				SetPedKeepTask(NPC, true)
				SetPedDropsWeaponsWhenDead(NPC, false)
				SetEntityInvincible(NPC, true)
				SetEntityVisible(NPC, true)
				SetEntityAsMissionEntity(NPC)
				TaskPlayAnim(NPC, "mini@strip_club@idles@bouncer@base", "base", 8.0, 0.0, -1, 1, 0, 0, 0, 0)
				jobNPC = NPC
				Citizen.Wait(1000)
				FreezeEntityPosition(NPC, true)
			end
			pedcreated = true
		end

		if dist < 10 and not pedgreet then
			notify(1, _U("greeting"), 5000, "Hey!")
			pedgreet = true
		end

		if dist < 3 then
			showHelpNotification(_U("receive_recipe"))
			if IsControlJustPressed(0, Config.OpenMenuButton) then
				SetBlipRoute(NPCBlip, false)
				RemoveBlip(NPCBlip)
				notify(1, _U("Go_Back"), 5000, "Next Step!")
				local res = ReturnBack()
				if res then return true end
			end
		end
		Citizen.Wait(0)
	end
end

-- Go back to drop off recipe
ReturnBack = function()
	local ped = PlayerPedId()
	local dist = 500000

	RBlip = AddBlipForCoord(Config.Bartender["RecipeBook"].pos)
	SetBlipSprite(RBlip, 309)
	SetBlipScale(RBlip, 0.8)
	SetBlipColour(RBlip, 27)
	SetBlipAsShortRange(RBlip, true)
	SetBlipDisplay(RBlip, 2)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName("Recipe Reward")
	EndTextCommandSetBlipName(RBlip)

	SetBlipRoute(RBlip, true)

	while not canceljob do
		local pos = GetEntityCoords(ped)
		dist = #(Config.Bartender["RecipeBook"].pos - pos)
		Citizen.Wait(300)
		if dist < 5 then
			MissionSuccess()
			return true
		end
	end
end

-- Mission was failed
MissionCancel = function()
	canceljob = true
	if inMission then
		PlayMissionCompleteAudio("GENERIC_FAILED")
		Citizen.Wait(700)
		notify(3, _U("Mission_Failed"), 5000, "Successfully Failed!")
		if DoesEntityExist(jobNPC) then DeleteEntity(jobNPC) end
		if DoesBlipExist(NPCBlip) then
			RemoveBlip(NPCBlip)
			SetBlipRoute(NPCBlip, false)
		end
		if DoesBlipExist(RBlip) then
			RemoveBlip(RBlip)
			SetBlipRoute(RBlip, false)
		end
	end
	canceljob = false
	inMission = false
end

-- Mission was Successful
MissionSuccess = function()
	PlayMissionCompleteAudio("FRANKLIN_BIG_01")
	Citizen.Wait(700)
	notify(1, _U("Mission_Success"), 5000, "Success!")
	if DoesEntityExist(jobNPC) then DeleteEntity(jobNPC) end
	if DoesBlipExist(NPCBlip) then
		RemoveBlip(NPCBlip)
		SetBlipRoute(NPCBlip, false)
	end
	if DoesBlipExist(RBlip) then
		RemoveBlip(RBlip)
		SetBlipRoute(RBlip, false)
	end
	inMission = false
end

-- Ordering new Recipes Menu
OpenOrderRecipes = function()
	ESX.TriggerServerCallback("BLBartender:LevelUpRecipe", function(free, paid)
		local elements = {}
		if paid then
			table.insert(elements, {
				label = _U("payrecipe", Config.PaidRecipeCost),
				value = "pay_recipe",
			})
		end -- Learn New Recipes
		if free then
			table.insert(elements, {
				label = _U("freerecipe", Config.XPRecipeCost),
				value = "free_recipe",
			})
		end
		if not elements[1] then
			elements = {
				{
					label = _U("noprize"),
					value = "no",
				},
			}
		end
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "order_recipes", {
			title = _U("boss_menu"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			if data.current.value == "pay_recipe" then
				local result = FetchMission()
				if result then TriggerServerEvent("BLBartender:PaidRecipe") end
			elseif data.current.value == "free_recipe" then
				local result = FetchMission()
				if result then TriggerServerEvent("BLBartender:FreeRecipe") end
			else
				notify(3, _U("noprize"), 5000, "No more Recipes to learn!")
			end
			ESX.UI.Menu.CloseAll()
		end, function(data, menu) menu.close() end)
	end)
end

-- Open Employement Actions Menu Function
OpenEmploymentActions = function()
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open("default", GetCurrentResourceName(), "employment_menu", {
		title = _U("employ_menu"),
		align = Config.MenuAlign,
		elements = {
			{
				label = _U("hire"),
				value = "hire_e",
			}, {
				label = _U("fire"),
				value = "fire_e",
			}, {
				label = _U("manage"),
				value = "manage_e",
			}, {
				label = _U("salary"),
				value = "salary_e",
			},
		},
	}, function(data, menu)
		if data.current.value == "hire_e" then
			OpenHireMenu()
		elseif data.current.value == "fire_e" then
			OpenFireMenu()
		elseif data.current.value == "manage_e" then
			OpenManageMenu()
		elseif data.current.value == "salary_e" then
			OpenSalaryMenu()
		end
	end, function(data, menu) OpenBossMenu() end)
end

-- Open the Recipe Book
OpenRecipeBook = function()
	ESX.TriggerServerCallback("BLBartender:KnownRecip", function(Rec)
		local elements = {}
		for k, v in pairs(Rec) do
			table.insert(elements, {
				label = v.label,
				value = k,
				glass = Recipes.Glasses[v.ReqGlass],
				gcount = 1,
				reqitems = v.ReqItems,
				gname = v.ReqGlass,
			})
		end
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "RecipeBook", {
			title = _U("recipebookactions"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			local elements2 = {}
			ESX.TriggerServerCallback("BLBartender:PrepIngredients", function(PrepI)
				ESX.TriggerServerCallback("BLBartender:RawIngredients", function(RawI)
					for k, v in pairs(data.current.reqitems) do
						local PCount = math.floor(PrepI[v.name].count)
						table.insert(elements2, {
							label = v.count .. " " .. v.label .. string.format(" | Stock: %s", PCount),
						})
					end
					table.insert(elements2, {
						label = data.current.gcount .. " " .. data.current.glass .. " | Stock: " .. math.floor(RawI[data.current.gname].count),
					})
					ESX.UI.Menu.Open("default", GetCurrentResourceName(), "RecipeRequirements", {
						title = _U("recipereq"),
						align = Config.MenuAlign,
						elements = elements2,
					}, function(data2, menu2) end, function(data2, menu2) menu2.close() end)
				end)
			end)
		end, function(data, menu) menu.close() end)
	end)
end

-- Open Hire Menu Function
OpenHireMenu = function()
	ESX.UI.Menu.CloseAll()
	local nearbyPlayers = {}
	local player = PlayerId()
	local pos = GetEntityCoords(PlayerPedId())
	local players = GetActivePlayers()

	for k, v in pairs(players) do
		if v ~= player then
			local ped = GetPlayerPed(v)
			if DoesEntityExist(ped) then
				local pedPos = GetEntityCoords(ped)
				if pedPos then
					local distcheck = #(pedPos - pos)
					if distcheck <= Config.NearbyPlayerCheck then
						v = GetPlayerServerId(v)
						table.insert(nearbyPlayers, {
							player = v,
							distance = distcheck,
						})
					end
				end
			end
		end
	end

	if nearbyPlayers[1] ~= nil then
		table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
		ESX.TriggerServerCallback("BLBartender:GetOtherPlayerData", function(playertable)
			if playertable[1] == nil then
				notify(2, _U("nearbyhire"), 5000, "No Nearby Players")
				return
			end
			ESX.UI.Menu.Open("default", GetCurrentResourceName(), "HireMenu", {
				title = _U("hire_menu"),
				align = Config.MenuAlign,
				elements = playertable,
			}, function(data, menu)
				ESX.UI.Menu.Open("default", GetCurrentResourceName(), "HireConfirm", {
					title = _U("hire_player", data.current.label),
					align = Config.MenuAlign,
					elements = {
						{
							label = _U("yes"),
							value = "yes",
						}, {
							label = _U("no"),
							value = "no",
						},
					},
				}, function(data2, menu2)
					menu.close()
					if data2.current.value == "yes" then
						TriggerServerEvent("BLBartender:RegisterEmployee", data.current.value, data.current.ident, "hire")
						ESX.UI.Menu.CloseAll()
					else
						OpenEmploymentActions()
					end
				end, function(data2, menu2) menu2.close() end)
			end, function(data, menu) OpenEmploymentActions() end)
		end, nearbyPlayers)
	else
		notify(2, _U("nearbyhire"), 5000, "No Nearby Players")
	end
end

-- Open Fire Menu Function
OpenFireMenu = function()
	ESX.UI.Menu.CloseAll()
	ESX.TriggerServerCallback("BLBartender:GetEmployees", function(FireTable)
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "fire_menu", {
			title = _U("fire_menu"),
			align = Config.MenuAlign,
			elements = FireTable,
		}, function(data, menu)
			ESX.UI.Menu.Open("default", GetCurrentResourceName(), "FireConfirm", {
				title = _U("fire_player", data.current.label),
				align = Config.MenuAlign,
				elements = {
					{
						label = _U("yes"),
						value = "yes",
					}, {
						label = _U("no"),
						value = "no",
					},
				},
			}, function(data2, menu2)
				if data2.current.value == "yes" then
					TriggerServerEvent("BLBartender:RegisterEmployee", false, data.current.value, "fire")
					OpenBossMenu()
				else
					OpenEmploymentActions()
				end
			end, function(data2, menu2) menu.close() end)
		end, function(data, menu) OpenBossMenu() end)
	end)
end

-- Open Manage Employee Function
OpenManageMenu = function()
	ESX.UI.Menu.CloseAll()
	ESX.TriggerServerCallback("BLBartender:GetEmployees", function(ManageTable)
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "manage_menu", {
			title = _U("manage_employees"),
			align = Config.MenuAlign,
			elements = ManageTable,
		}, function(data, menu)
			ESX.TriggerServerCallback("BLBartender:ManageEmployees", function(elementlist)
				ESX.UI.Menu.Open("default", GetCurrentResourceName(), "promote_demote", {
					title = _U("manage_player", data.current.label),
					align = Config.MenuAlign,
					elements = elementlist,
				}, function(data2, menu2)
					TriggerServerEvent("BLBartender:RegisterEmployee", false, data.current.value, "manage", data2.current.grade, data2.current.value)
					OpenBossMenu()
				end, function(data2, menu2) menu2.close() end)
			end, data.current.value, data.current.status, data.current.jobgrade)
		end, function(data, menu) OpenEmploymentActions() end)
	end)
end

-- Open Edit Salary Function
OpenSalaryMenu = function()
	ESX.UI.Menu.CloseAll()
	ESX.TriggerServerCallback("BLBartender:GetSalary", function(SalaryTable)
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "salary_menu", {
			title = _U("manage_salary"),
			align = Config.MenuAlign,
			elements = SalaryTable,
		}, function(data, menu)
			ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "change_salary", {
				title = _U("change_salary_amount"),
			}, function(data2, menu2)
				if not data2.value or tonumber(data2.value) < 100 then
					menu2.close()
					notify(3, _U("wrongsalary"), 5000, "Too Low!")
				else
					notify(1, _U("changedsalary", data.current.jobname, data.current.value, data2.value), 5000, "Success!")
					TriggerServerEvent("BLBartender:ChangeSalary", data.current.grade, data2.value)
					ESX.UI.Menu.CloseAll()
				end
			end, function(data2, menu2) menu2.close() end)
		end, function(data, menu) OpenEmploymentActions() end)
	end)
end

-- Open Money Actions
OpenMoneyActions = function()
	ESX.TriggerServerCallback("BLBartender:GetBalance", function(balance)
		local elements = {
			{
				label = _U("account_balance", balance),
				value = "yes",
			}, -- Account Balance
			{
				label = _U("withdraw_balance"),
				value = "withdraw",
			}, -- Withdraw
			{
				label = _U("deposit_balance"),
				value = "deposit",
			}, -- Deposit
		}
		if Config.WashMoney then
			table.insert(elements, {
				label = _U("wash_money"),
				value = "wash",
			})
		end
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "money_actions", {
			title = _U("moneyactions"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			if data.current.value ~= "yes" then
				ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "withdraw_deposit", {
					title = _U("enter_amount"),
				}, function(data2, menu2)
					if not data2.value then
						menu2.close()
						notify(3, _U("emptynumber"), 5000, "Empty Field!")
					else
						TriggerServerEvent("BLBartender:MoneyFunctions", data.current.value, data2.value)
						ESX.UI.Menu.CloseAll()
					end
				end, function(data2, menu2) menu2.close() end)
			end
		end, function(data, menu) OpenBossMenu() end)
	end)
end

-- Open menu to order raw materials
OpenRawOrder = function()
	ESX.TriggerServerCallback("BLBartender:RawIngredients", function(RawI)
		local elements = {}
		for k, v in pairs(RawI) do
			table.insert(elements, {
				label = v.label .. " | Stock: " .. v.count,
				count = math.floor(v.count),
				value = k,
			})
		end
		table.sort(elements, function(a, b) return a.count < b.count end)
		ESX.UI.Menu.CloseAll()
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "order_menu", {
			title = _U("order_menu"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "order_amount", {
				title = _U("enter_amount"),
			}, function(data2, menu2)
				if not data2.value then
					menu2.close()
					notify(3, _U("emptynumber"), 5000, "Empty Field!")
				else
					TriggerServerEvent("BLBartender:PurchasedRawmenu", data.current.value, data2.value)
					ESX.UI.Menu.CloseAll()
				end
			end, function(data2, menu2) menu2.close() end)
		end, function(data, menu) OpenBossMenu() end)
	end)
end

-- Open the menu to turn raw materials into prepped ingredients
OpenPrepareIngredient = function()
	local playerped = PlayerPedId()
	ESX.TriggerServerCallback("BLBartender:RawIngredients", function(RawI)
		local elements = {}
		for k, v in pairs(RawI) do
			if not Recipes.Glasses[k] and v.count ~= 0 then
				table.insert(elements, {
					label = v.label .. " | Stock: " .. v.count,
					count = v.count,
					value = k,
				})
			end
		end
		if not elements[1] then
			elements = {
				{
					label = "No Raw Materials In Stock",
					value = "no",
				},
			}
		end
		table.sort(elements, function(a, b) return a.count > b.count end)
		ESX.UI.Menu.CloseAll()
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "prep_ingred", {
			title = _U("prep_ingred"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			if data.current.value ~= "no" then
				ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "prep_amount", {
					title = _U("enter_amount"),
				}, function(data2, menu2)
					if not data2.value then
						menu2.close()
						notify(3, _U("emptynumber"), 5000, "Empty Field!")
					else
						if tonumber(data2.value) > tonumber(data.current.count) then
							notify(3, _U("notenoughresources"), 5000, "Not Enough!")
						else
							PrepareMiniGame(data.current.value, data2.value, playerped)
							ClearPedTasks(playerped)
						end
						ESX.UI.Menu.CloseAll()
					end
				end, function(data2, menu2) menu2.close() end)
			else
				ESX.UI.Menu.CloseAll()
			end
		end, function(data, menu) menu.close() end)
	end)
end

-- Open the bartender menu to make drinks that have been ordered.
OpenBartender = function()
	local playerped = PlayerPedId()
	ESX.TriggerServerCallback("BLBartender:MakeList", function(Rec)
		local elements = {}
		for k, v in pairs(Rec) do
			for i = 1, #Rec[k] do
				table.insert(elements, {
					label = k .. " | Drink: " .. Rec[k][i].Recip.label .. " | Count: " .. Rec[k][i].MakeCount,
					value = Rec[k][i].id,
					name = Rec[k][i].RecipeName,
					pname = k,
				})
			end
		end
		if not elements[1] then
			elements = {
				{
					label = "No Drink Orders",
					value = "no",
				},
			}
		end
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "RecipeBook", {
			title = _U("recipebookactions"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			if data.current.value ~= "no" then
				DrinkMiniGame(data.current.value, data.current.name, data.current.pname, playerped)
				ClearPedTasks(playerped)
				ESX.UI.Menu.CloseAll()
			end
			ESX.UI.Menu.CloseAll()
		end, function(data, menu) ESX.UI.Menu.CloseAll() end)
	end)
end

-- Open the register to order drinks
OpenRegister = function()
	ESX.TriggerServerCallback("BLBartender:HasMatsRecips", function(HasMats)
		local elements = {}
		for k, v in pairs(HasMats) do
			if v then
				table.insert(elements, {
					label = v.label .. " | $" .. v.cost,
					value = k,
				})
			end
		end
		if not elements[1] then
			elements = {
				{
					label = "Bar is missing ingredients!",
					value = "no",
				},
			}
		end
		ESX.UI.Menu.Open("default", GetCurrentResourceName(), "Register", {
			title = _U("register"),
			align = Config.MenuAlign,
			elements = elements,
		}, function(data, menu)
			if data.current.value ~= "no" then
				ESX.UI.Menu.Open("dialog", GetCurrentResourceName(), "order_amount", {
					title = _U("enter_amount"),
				}, function(data2, menu2)
					if not data2.value then
						menu2.close()
						notify(3, _U("emptynumber"), 5000, "Empty Field!")
					else
						ESX.TriggerServerCallback("BLBartender:HasMatsRecip", function(haslocal) if haslocal then TriggerServerEvent("BLBartender:PurchasedDrinkmenu", data.current.value, data2.value) end end, data.current.value, data2.value)
						ESX.UI.Menu.CloseAll()
					end
				end, function(data2, menu2) menu2.close() end)
			else
				ESX.UI.Menu.CloseAll()
			end
		end, function(data, menu) menu.close() end)
	end)
end

-- Function to get your drink from the tray.
OpenDrinkTray = function()
	local player = PlayerId()
	local sID = GetPlayerServerId(player)
	local woops = true
	for k, v in pairs(ClientList) do
		if v.player == sID then
			woops = false
			TriggerServerEvent("BLBartender:DrinkTray", v.id)
			ClientList[k] = nil
		end
	end
	if woops then notify(3, _U('nodrinks'), 5000, "Nothing is ready yet!") end
end

-- Make Drinks Mini Game Function
DrinkMiniGame = function(value, name, pname, playerped)
	exports.rprogress:MiniGame({
		Zone = Config.Zone,
		Duration = Config.Duration,
		Easing = "easeLinear",
		Color = "rgba(255, 255, 255, 1.0)",
		BGColor = "rgba(0, 0, 0, 0.4)",
		Animation = {
			animationDictionary = "anim@amb@casino@mini@drinking@bar@drink@heels@base",
			animationName = "intro_bartender",
			flag = 49,
		},
		DisableControls = {
			Mouse = false,
			Player = true,
			Vehicle = true,
		},
		onComplete = function(success)
			ClearPedTasks(playerped)
			if success then
				TriggerServerEvent("BLBartender:MakeDrink", value, name, pname)
			else
				notify(3, _U("failedgame"), 5000, "Noob!")
				TriggerServerEvent("BLBartender:FailMakeDrink", value, name, pname)
			end
		end,
	})
end

-- Prepare Ingredients Mini Game function
PrepareMiniGame = function(fvalue, xvalue, playerped)
	exports.rprogress:MiniGame({
		Zone = Config.Zone,
		Duration = Config.Duration,
		Easing = "easeLinear",
		Color = "rgba(255, 255, 255, 1.0)",
		BGColor = "rgba(0, 0, 0, 0.4)",
		Animation = {
			animationDictionary = "mini@repair",
			animationName = "fixing_a_player",
			flag = 49,
		},
		DisableControls = {
			Mouse = false,
			Player = true,
			Vehicle = true,
		},
		onComplete = function(success)
			ClearPedTasks(playerped)
			if success then
				TriggerServerEvent("BLBartender:PrepIngredmenu", fvalue, xvalue)
				notify(1, _U("success"), 5000, "Nice!")
			else
				notify(3, _U("failedgame"), 5000, "Noob!")
			end
		end,
	})
end

-- Show Help Notification Table
ShowHelpNotif = {
	Register = function() showHelpNotification(_U("press_register")) end,
	DrinkTray = function() showHelpNotification(_U("press_drinktray")) end,
	BossMenu = function(job)
		if job.name == jobName and job.grade_name == "boss" then
			showHelpNotification(_U("press_bossmenu"))
		else
			showHelpNotification(_U("wrong_area"))
		end
	end,
	RecipeBook = function(job)
		if job.name == jobName then
			showHelpNotification(_U("press_recipebook"))
		else
			showHelpNotification(_U("wrong_area"))
		end
	end,
	PrepareIngredients = function(job)
		if job.name == jobName then
			showHelpNotification(_U("press_prepareingredients"))
		else
			showHelpNotification(_U("wrong_area"))
		end
	end,
	Bartender = function(job)
		if job.name == jobName then
			showHelpNotification(_U("press_bartender"))
		else
			showHelpNotification(_U("wrong_area"))
		end
	end,
}

-- Open Menu Table
Open = {
	Register = function() OpenRegister() end,
	DrinkTray = function() OpenDrinkTray() end,
	BossMenu = function(job) if job.name == jobName and job.grade_name == "boss" then OpenBossMenu() end end,
	RecipeBook = function(job) if job.name == jobName then OpenRecipeBook() end end,
	PrepareIngredients = function(job) if job.name == jobName then OpenPrepareIngredient() end end,
	Bartender = function(job) if job.name == jobName then OpenBartender() end end,
}

-- Main Thread
Citizen.CreateThread(function()
	local drawcheck = Config.DrawDistance
	setupEsx()
	setupBlips()
	while true do
		local ped = PlayerPedId()
		local pos = GetEntityCoords(ped)
		local closest, dist, MarkerPos = getClosestMarker(pos)
		local marker = Config.Bartender[closest]

		if dist < drawcheck then
			if marker.show then
				DrawMarker(marker.MarkerType, MarkerPos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, marker.MarkerSize.x, marker.MarkerSize.y, marker.MarkerSize.z, marker.MarkerColor.r, marker.MarkerColor.g, marker.MarkerColor.b, 100, false, true, 2, false, nil, nil, false)
			end
		end

		if dist < Config.InteractDist then
			ShowHelpNotif[closest](playerData.job)
			if IsControlJustPressed(0, Config.OpenMenuButton) then Open[closest](playerData.job) end
		end
		Wait(dist < drawcheck and 0 or 750)
	end
end)