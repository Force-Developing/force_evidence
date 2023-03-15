ESX              = nil
local PlayerData = {}

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent(Config.ESX, function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    Citizen.Wait(500)

    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

Citizen.CreateThread(function()
    while true do
        local player, sleepThread = PlayerPedId(), 500;

        for index, value in pairs(Config.Locations) do

            local distance = #(GetEntityCoords(player) - value)

            if distance <= 2.0 and IsPedOnFoot(player) and not IsPedDeadOrDying(player) then
                sleepThread = 5;

                if PlayerData.job ~= nil and PlayerData.job.name == 'police' then
                    -- exports['bgrp_tools']:DrawText3D(value, '[~g~E~s~] - Öppna bevisarkiv')
                    Funcs.Draw3DText(value, '[~g~E~w~] Öppna Bevisarkiv');

                    if IsControlJustReleased(0, 38) then
                        SendNUIMessage({
                            action = "OpenMenu"
                        })
                    end
                end
            end
        end
        Wait(sleepThread)
    end
end)

