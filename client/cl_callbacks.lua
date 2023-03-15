RegisterNUICallback("NuiFocus", function(state)
    SetNuiFocus(state, state)
end)

RegisterNUICallback("CompleteSearch", function(value)
    ESX.TriggerServerCallback("force_evidence:lookUp", function(data)
        if data then
            SendNUIMessage({
                action = "SearchCompelted",
                data = data
            })
        end
    end, value)
end)

RegisterNUICallback("OpenStash", function(currentId)
    exports["btrp_storage"]:OpenStorageUnit("Bevismaterial - " .. currentId, 200.0, 24.0)
end)