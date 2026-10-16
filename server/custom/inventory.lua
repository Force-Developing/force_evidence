-- Opens a citizen's evidence stash for a player. The server has already checked the job, the distance and that the
-- citizen came from this player's own search; `stash` is built on the server and never comes from the client.
--
-- stash = {
--   id = "evidence_ABC12345",     -- Config.Stash.prefix .. citizen id
--   label = "Evidence: John Doe",
--   slots = 50, maxWeight = 200000,
--   groups = { police = 0 },      -- every job of every locker, lowest grade
--   coords = vector3 or { vector3, ... }, -- every locker
-- }
--
-- Each opener returns true, or false and a locale key. Returning true, { legacyClientOpen = true } makes the client
-- open the stash itself through the old qb-inventory events (see "qb-inventory" below).
--
-- Add your own inventory by filling in StashOpeners.custom and setting Config.Inventory = "custom".

StashOpeners = {}

-- ox_inventory (ESX, QBCore, QBox). The stash is registered with the police groups and the locker coordinates, so
-- ox_inventory itself refuses everyone else and closes it when the officer walks away.
StashOpeners["ox_inventory"] = function(source, stash)
  local ok, result = pcall(function()
    exports.ox_inventory:RegisterStash(stash.id, stash.label, stash.slots, stash.maxWeight, nil, stash.groups,
      stash.coords)
    return exports.ox_inventory:forceOpenInventory(source, "stash", stash.id)
  end)
  if not ok then
    Log("error", "ox_inventory could not open the evidence stash: " .. tostring(result))
    return false, "open_failed"
  end
  if not result then return false, "open_failed" end
  return true
end

local warnedLegacyQb = false

-- qb-inventory. Version 2 (2024 and later) opens stashes on the server through the OpenInventory export.
-- Older qb-inventory versions (and forks such as lj-inventory / ps-inventory) have no server-side stash API: the
-- client opens the stash with an event, and those inventories let any client open any stash name.
StashOpeners["qb-inventory"] = function(source, stash)
  local ok, err = pcall(function()
    exports["qb-inventory"]:OpenInventory(source, stash.id, {
      label = stash.label,
      maxweight = stash.maxWeight,
      slots = stash.slots,
    })
  end)
  if ok then return true end

  if tostring(err):find("No such export", 1, true) then
    if not warnedLegacyQb then
      warnedLegacyQb = true
      Log("warn", "qb-inventory has no OpenInventory export (version 1.x): evidence stashes are opened by the " ..
        "client, which that inventory allows for any stash. Update to qb-inventory 2.x or use ox_inventory.")
    end
    return true, { legacyClientOpen = true }
  end
  Log("error", "qb-inventory could not open the evidence stash: " .. tostring(err))
  return false, "open_failed"
end

-- Your own inventory. Return true when the stash was opened.
StashOpeners["custom"] = function(source, stash)
  return false, "no_inventory"
end

--- The inventory used for evidence, decided when a locker is opened (start order doesn't matter)
--- @return string
function GetInventorySystem()
  local configured = Config.Inventory
  if configured ~= "auto" and StashOpeners[configured] then return configured end
  if GetResourceState("ox_inventory") == "started" then return "ox_inventory" end
  if GetResourceState("qb-inventory") == "started" then return "qb-inventory" end
  return "custom"
end
