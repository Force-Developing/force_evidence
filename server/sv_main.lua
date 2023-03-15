ESX = nil 

TriggerEvent(Config.ESX, function(obj) ESX = obj  
end)  

ESX.RegisterServerCallback("force_evidence:lookUp", function(source, cb, value)
    MySQL.Async.fetchAll("SELECT * FROM characters WHERE id = @id", {
        ["@id"] = value
    }, function(data)
        if data[1] then
            print("2")
            cb(data[1])
        else
            print("1")
            TriggerClientEvent("force_evidence:SendNoti", source, "Du har skrivit in fel personnummer.")
        end
    end)
end)