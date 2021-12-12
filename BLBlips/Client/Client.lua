local ESX
local PlayerData
local BlipList = {}

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(j)
	PlayerData.job = j
	deleteBlips()
	setupBlips()
end)

setupEsx = function()
	if not Config.ESXLegacy then
		while not ESX do
			TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
			Wait(100)
		end
	end

	while not ESX.IsPlayerLoaded() do Wait(500) end

	PlayerData = ESX.GetPlayerData()
end

function setupBlips()
	local admin = false
	if PlayerData.job ~= nil then
		for k, v in pairs(Config.Blips) do
			if v.AdminOnly then
				if PlayerData.getGroup() == v.AdminLevel then admin = true end
				if admin then
					for i = 1, #v.Pos, 1 do
						local blip = AddBlipForCoord(v.Pos[i])

						SetBlipSprite(blip, v.BlipType)
						SetBlipScale(blip, v.BlipSize)
						SetBlipColour(blip, v.BlipColor)
						SetBlipAsShortRange(blip, true)
						SetBlipDisplay(blip, v.BlipDisplay or 2)
						BeginTextCommandSetBlipName('STRING')
						AddTextComponentSubstringPlayerName(v.Label)
						EndTextCommandSetBlipName(blip)
						table.insert(BlipList, blip)
					end
					admin = false
				end
			elseif not v.ReqJob or v.ReqJob[PlayerData.job.name] or v.ShowAll then
				for i = 1, #v.Pos, 1 do
					local blip = AddBlipForCoord(v.Pos[i])

					SetBlipSprite(blip, v.BlipType)
					SetBlipScale(blip, v.BlipSize)
					SetBlipColour(blip, v.BlipColor)
					SetBlipAsShortRange(blip, true)
					SetBlipDisplay(blip, v.BlipDisplay or 2)
					BeginTextCommandSetBlipName('STRING')
					AddTextComponentSubstringPlayerName(v.Label)
					EndTextCommandSetBlipName(blip)
					table.insert(BlipList, blip)
				end
			end
		end
	end
end

function deleteBlips()
	for i = 1, #BlipList, 1 do
		RemoveBlip(BlipList[i])
		BlipList[i] = nil
	end
end

Citizen.CreateThread(function()
	setupEsx()
	setupBlips()
end)
