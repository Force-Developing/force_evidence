RegisterNetEvent("force_evidence:SendNoti")
AddEventHandler("force_evidence:SendNoti", function(text)
    SendNUIMessage({
        action = "SendNoti",
        data = text
    })
end)