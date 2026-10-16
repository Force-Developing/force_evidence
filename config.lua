Config = {}

-- Prints extra info to the F8 / server console. Setup errors are always printed.
Config.Debug = false

-- "en", "sv" or "auto" (follows the replicated ox:locale convar: setr ox:locale "sv")
Config.Locale = "en"

-- "auto" (detected by the server: qbx_core, es_extended, qb-core), "esx", "qb", "qbx" or "custom"
Config.Framework = "auto"

-- "auto" (ox_target, then qb-target, else [E] + text UI), "ox_target", "qb-target" or "none" ([E] + text UI)
Config.Target = "auto"

-- Where the evidence is stored. "auto" uses ox_inventory, then qb-inventory, otherwise "custom"
-- (server/custom/inventory.lua). ESX's default inventory has no stashes: use ox_inventory on ESX.
Config.Inventory = "auto"

-- Draw a ground marker at every locker
Config.DrawMarkers = true

-- QBCore / QBox: the player must be on duty to use a locker. ESX has no duty state and ignores this.
Config.RequireDuty = false

-- How far (meters) a player may be from the locker point when searching or opening (checked on the server)
Config.InteractDistance = 3.0

-- Print every opened locker (officer and citizen) to the server console.
-- The server event "force_evidence:lockerOpened" fires either way (see the docs).
Config.LogAccess = true

-- Every citizen has one evidence stash, shared by all lockers.
Config.Stash = {
  slots = 50,
  maxWeight = 200000, -- grams
  -- Stash id = prefix .. citizen id (citizenid on QBCore / QBox, identifier on ESX).
  -- Changing the prefix hides the evidence stored under the old one.
  prefix = "evidence_",
}

Config.Search = {
  -- Seconds between two searches by the same player
  cooldown = 2,
  -- Most citizens listed for one name search
  maxResults = 10,
  -- Minimum letters of the first and the last name in a name search
  minNameLength = 2,
  -- Seconds a search result can be opened before the officer has to search again
  resultLifetime = 300,
}

--[[
  Evidence lockers. Each key is the locker id.
  label  = title of the menu
  coords = where the locker is opened (target zone or [E] point)
  jobs   = { [job name] = minimum grade }. Only these jobs can search and open evidence here.
]]
Config.Lockers = {
  mrpd = {
    label = "Evidence Archive",
    coords = vec3(472.94, -996.66, 26.27),
    jobs = { police = 0 },
  },
}
