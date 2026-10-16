local RESOURCE = GetCurrentResourceName()
local MAX_SEARCH_LENGTH = 64

local lastSearch = {} -- [source] = GetGameTimer() of the last search
local results = {}    -- [source] = { citizens = { [id] = citizen }, expires = GetGameTimer() deadline }
local busy = {}       -- [source] = true while a request is handled

local function searchSettings()
  local search = type(Config.Search) == "table" and Config.Search or {}
  return {
    cooldown = (tonumber(search.cooldown) or 2) * 1000,
    maxResults = math.max(1, math.min(50, math.floor(tonumber(search.maxResults) or 10))),
    minNameLength = math.max(1, math.floor(tonumber(search.minNameLength) or 2)),
    lifetime = (tonumber(search.resultLifetime) or 300) * 1000,
  }
end

local function stashSettings()
  local stash = type(Config.Stash) == "table" and Config.Stash or {}
  local prefix = type(stash.prefix) == "string" and stash.prefix or "evidence_"
  return {
    slots = math.max(1, math.floor(tonumber(stash.slots) or 50)),
    maxWeight = math.max(1, math.floor(tonumber(stash.maxWeight) or 200000)),
    prefix = prefix,
  }
end

-- Every job of every locker with its lowest grade, and every locker position: ox_inventory uses both to refuse
-- anyone else and to close the stash when the officer walks away
local stashGroups, stashCoords = {}, {}
for _, locker in pairs(Config.Lockers) do
  for job, grade in pairs(locker.jobs) do
    grade = tonumber(grade) or 0
    if stashGroups[job] == nil or grade < stashGroups[job] then stashGroups[job] = grade end
  end
  stashCoords[#stashCoords + 1] = locker.coords
end

--- Citizen ids are citizenids (QBCore / QBox) or identifiers (ESX, e.g. "char1:1a2b..."): letters, digits, : _ -
--- @return string|nil
local function cleanId(value)
  if type(value) ~= "string" then return nil end
  value = value:match("^%s*(.-)%s*$")
  if #value < 1 or #value > MAX_SEARCH_LENGTH or not value:match("^[%w:_%-]+$") then return nil end
  return value
end

--- The stash id of a citizen. Only ever built from an id the server looked up itself.
--- @param citizenId string
--- @return string|nil
function GetEvidenceStashId(citizenId)
  local id = cleanId(citizenId)
  return id and (stashSettings().prefix .. id) or nil
end

--- LIKE pattern for "starts with", lower case, with the user's wildcards escaped
local function likePrefix(text)
  return (text:lower():gsub("[\\%%_]", "\\%0")) .. "%"
end

local function citizenName(citizen)
  local name = ("%s %s"):format(citizen.firstname or "", citizen.lastname or ""):match("^%s*(.-)%s*$")
  return name ~= "" and name or citizen.id
end

local function playerCoords(source)
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then return nil end
  return GetEntityCoords(ped)
end

--- @return boolean allowed, string|table reasonOrJob
local function checkAccess(source, locker)
  if not IsFrameworkReady() then return false, "not_ready" end
  local job = GetPlayerJob(source)
  if not job then return false, "not_allowed" end
  if not CanUseLocker(locker, job) then
    if Config.RequireDuty and job.onDuty == false and locker.jobs[job.name] ~= nil then return false, "not_on_duty" end
    return false, "not_allowed"
  end
  local coords = playerCoords(source)
  local maxDistance = (tonumber(Config.InteractDistance) or 3.0) + 1.0
  if not coords or #(coords - locker.coords) > maxDistance then return false, "too_far" end
  return true, job
end

--- Runs fn with the player's busy flag set; the flag is always cleared, even when fn errors
local function exclusive(source, label, fn)
  if busy[source] then return false, "busy" end
  busy[source] = true
  local ok, success, result = pcall(fn)
  busy[source] = nil
  if not ok then
    Log("error", ("%s failed: %s"):format(label, tostring(success)))
    return false, label == "Search" and "search_failed" or "open_failed"
  end
  return success, result
end

local function search(source, term)
  local settings = searchSettings()
  local found = {}

  local id = cleanId(term)
  local first, last = term:match("^%s*(%S+)%s+(.-)%s*$")
  if first and last ~= "" then
    if #first < settings.minNameLength or #last < settings.minNameLength then
      return false, "invalid_search"
    end
    found = FindCitizensByName(likePrefix(first), likePrefix(last), settings.maxResults) or {}
  elseif id then
    local citizen = FindCitizenById(id)
    if citizen then found = { citizen } end
  else
    return false, "invalid_search"
  end

  -- Remember exactly what this player was shown: only these citizens can be opened afterwards
  local citizens, list = {}, {}
  for _, citizen in ipairs(found) do
    local citizenId = type(citizen) == "table" and cleanId(citizen.id)
    if citizenId and not citizens[citizenId] and #list < settings.maxResults then
      citizen.id = citizenId
      citizens[citizenId] = citizen
      list[#list + 1] = {
        id = citizenId,
        name = citizenName(citizen),
        dob = type(citizen.dob) == "string" and citizen.dob ~= "" and citizen.dob or nil,
      }
    end
  end
  results[source] = { citizens = citizens, expires = GetGameTimer() + settings.lifetime }
  return true, list
end

lib.callback.register(RESOURCE .. ":server:search", function(source, lockerId, term)
  local locker = GetLocker(lockerId)
  if not locker then return false, "not_allowed" end
  if type(term) ~= "string" or #term > MAX_SEARCH_LENGTH * 2 then return false, "invalid_search" end

  local allowed, reason = checkAccess(source, locker)
  if not allowed then return false, reason end

  local settings = searchSettings()
  if lastSearch[source] and GetGameTimer() - lastSearch[source] < settings.cooldown then return false, "cooldown" end

  return exclusive(source, "Search", function()
    lastSearch[source] = GetGameTimer()
    local success, result = search(source, term)
    Debug("info", "%s searched the evidence archive: %s result(s)", GetPlayerName(source),
      type(result) == "table" and #result or result)
    return success, result
  end)
end)

lib.callback.register(RESOURCE .. ":server:open", function(source, lockerId, citizenId)
  local locker = GetLocker(lockerId)
  if not locker then return false, "not_allowed" end

  local allowed, job = checkAccess(source, locker)
  if not allowed then return false, job end

  local id = cleanId(citizenId)
  local session = results[source]
  local citizen = id and session and session.citizens[id]
  if not citizen then return false, "search_expired" end
  if GetGameTimer() > session.expires then
    results[source] = nil
    return false, "search_expired"
  end

  return exclusive(source, "Opening a locker", function()
    local settings = stashSettings()
    local name = citizenName(citizen)
    local stash = {
      id = settings.prefix .. citizen.id,
      label = locale("stash_label", name),
      slots = settings.slots,
      maxWeight = settings.maxWeight,
      groups = stashGroups,
      coords = #stashCoords == 1 and stashCoords[1] or stashCoords,
    }

    local inventory = GetInventorySystem()
    local opened, extra = StashOpeners[inventory](source, stash)
    if not opened then return false, extra or "open_failed" end

    if Config.LogAccess then
      Log("info", ("%s (%s, %s %s) opened the evidence locker of %s (%s) at %s"):format(GetPlayerName(source), source,
        job.name, job.grade, name, citizen.id, locker.id))
    end
    TriggerEvent(RESOURCE .. ":lockerOpened", source, citizen.id, locker.id, stash.id)

    local response = { name = name }
    if type(extra) == "table" and extra.legacyClientOpen then
      response.legacy = { stash = stash.id, slots = stash.slots, maxWeight = stash.maxWeight }
    end
    return true, response
  end)
end)

exports("GetEvidenceStashId", GetEvidenceStashId)

AddEventHandler("playerDropped", function()
  local src = source
  lastSearch[src] = nil
  results[src] = nil
  busy[src] = nil
end)

-- Setup problems are printed once the server had time to start every resource
OnEnvironmentReady(function()
  SetTimeout(15000, function()
    if GetInventorySystem() == "custom" and Config.Inventory ~= "custom" then
      Log("error", "No supported inventory runs (ox_inventory, qb-inventory), so evidence lockers can't be opened. " ..
        "ESX's default inventory has no stashes: install ox_inventory, or add yours in server/custom/inventory.lua.")
    end
    if not next(Config.Lockers) then Log("error", "Config.Lockers has no valid locker.") end
  end)
end)
