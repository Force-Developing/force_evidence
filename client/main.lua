local RESOURCE = GetCurrentResourceName()
local MENU_ID = RESOURCE .. ":results"
local CALLBACK_TIMEOUT = 15000
local MARKER_DISTANCE = 10.0
local KEY_E = 38

local points = {}       -- lib.points
local oxZones = {}      -- ox_target zone ids
local qbZones = {}      -- qb-target zone names
local shownText = nil   -- key of the text UI this resource shows
local busy = false
local dialogOpen = false -- our search input dialog is open
local lastKeyPress = 0

local function notify(message, notifyType)
  lib.notify({ description = message, type = notifyType or "inform" })
end

local function showText(key, text)
  if shownText == key then return end
  lib.showTextUI(text)
  shownText = key
end

local function hideText(key)
  if not shownText or (key and shownText ~= key) then return end
  lib.hideTextUI()
  shownText = nil
end

local function canUse(locker)
  return CanUseLocker(locker, GetPlayerJob())
end

local function minNameLength()
  return type(Config.Search) == "table" and tonumber(Config.Search.minNameLength) or 2
end

local function notifyReason(reason, fallback)
  reason = type(reason) == "string" and reason or fallback
  if reason == "invalid_search" then return notify(locale(reason, minNameLength()), "error") end
  notify(locale(reason), "error")
end

--- lib.callback with its own timeout (ox_lib waits 5 minutes and throws). Returns nil when the server didn't answer.
local function awaitServer(name, ...)
  local p = promise.new()
  local settled = false
  local function settle(value)
    if settled then return end
    settled = true
    p:resolve(value)
  end
  lib.callback(name, false, function(...)
    settle({ n = select("#", ...), ... })
  end, ...)
  SetTimeout(CALLBACK_TIMEOUT, function() settle(false) end)
  local result = Citizen.Await(p)
  if not result then return nil end
  return table.unpack(result, 1, result.n)
end

--- Runs a server request with the busy flag; the flag is cleared on every path
local function request(name, ...)
  if busy then
    notify(locale("busy"), "error")
    return false
  end
  busy = true
  local args = table.pack(...)
  local ok, success, result = pcall(function() return awaitServer(name, table.unpack(args, 1, args.n)) end)
  busy = false
  if not ok then
    Debug("error", "%s failed: %s", name, tostring(success))
    notify(locale("server_no_response"), "error")
    return false
  end
  if success == nil then
    notify(locale("server_no_response"), "error")
    return false
  end
  return true, success, result
end

--- Asks the server to open a citizen's evidence locker. The server only accepts citizens from this player's last
--- search and builds the stash id itself.
--- @param lockerId string
--- @param citizenId string
function OpenEvidenceLocker(lockerId, citizenId)
  local answered, success, result = request(RESOURCE .. ":server:open", lockerId, citizenId)
  if not answered then return end
  if not success then return notifyReason(result, "open_failed") end

  result = type(result) == "table" and result or {}
  local legacy = result.legacy
  if type(legacy) == "table" and type(legacy.stash) == "string" then
    -- qb-inventory 1.x has no server-side stash API: it opens stashes from the client
    TriggerServerEvent("inventory:server:OpenInventory", "stash", legacy.stash,
      { maxweight = legacy.maxWeight, slots = legacy.slots })
    TriggerEvent("inventory:client:SetCurrentStash", legacy.stash)
  end
  notify(locale("opened", tostring(result.name or citizenId)), "success")
end

local function showResults(lockerId, list)
  local options = {}
  for _, citizen in ipairs(list) do
    if type(citizen) == "table" and type(citizen.id) == "string" then
      local citizenId = citizen.id
      options[#options + 1] = {
        title = tostring(citizen.name or citizenId),
        description = citizen.dob and locale("result_description", citizenId, citizen.dob)
            or locale("result_description_no_dob", citizenId),
        icon = "box-archive",
        -- the request yields; run it in its own thread instead of the menu's callback
        onSelect = function() CreateThread(function() OpenEvidenceLocker(lockerId, citizenId) end) end,
      }
    end
  end
  if #options == 0 then return notify(locale("no_results"), "error") end
  lib.registerContext({ id = MENU_ID, title = locale("results_title"), options = options })
  lib.showContext(MENU_ID)
end

--- Asks for a citizen id or name, searches on the server and lists the matching citizens.
--- @param lockerId string
function OpenEvidenceArchive(lockerId)
  local locker = GetLocker(lockerId)
  if not locker then return end
  if not canUse(locker) then return notify(locale("not_allowed"), "error") end
  if busy then return notify(locale("busy"), "error") end

  dialogOpen = true
  local ok, input = pcall(lib.inputDialog, locale("search_title"), {
    { type = "input", label = locale("search_label"), description = locale("search_description"), required = true,
      min = 1, max = 64 },
  })
  dialogOpen = false
  if not ok then return Debug("error", "The search dialog failed: %s", tostring(input)) end
  local term = type(input) == "table" and input[1]
  if type(term) ~= "string" or term:match("^%s*$") then return end

  local answered, success, result = request(RESOURCE .. ":server:search", lockerId, term)
  if not answered then return end
  if not success then return notifyReason(result, "search_failed") end
  showResults(lockerId, type(result) == "table" and result or {})
end

-------------------------------------------------------------------------------------------------------------------
-- World: markers, target zones / [E] points
-------------------------------------------------------------------------------------------------------------------

local function drawMarker(coords)
  DrawMarker(1, coords.x, coords.y, coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.6, 40, 120, 255, 90,
    false, false, 2, false, nil, nil, false)
end

local function addTarget(locker)
  local target = GetTargetSystem()
  local name = ("%s:%s"):format(RESOURCE, locker.id)
  local function canInteract() return not cache.vehicle and canUse(locker) end
  -- the input dialog yields, which a target resource's callback can't do: open it in our own thread
  local function open() CreateThread(function() OpenEvidenceArchive(locker.id) end) end

  if target == "ox_target" then
    oxZones[#oxZones + 1] = exports.ox_target:addSphereZone({
      coords = locker.coords,
      radius = 1.2,
      options = { {
        name = name, icon = "fa-solid fa-box-archive", label = locale("open_archive"), distance = 2.0,
        canInteract = canInteract, onSelect = open,
      } },
    })
  elseif target == "qb-target" then
    exports["qb-target"]:AddCircleZone(name, locker.coords, 1.2, { name = name, debugPoly = false, useZ = true }, {
      options = { { icon = "fas fa-box-archive", label = locale("open_archive"), canInteract = canInteract, action = open } },
      distance = 2.0,
    })
    qbZones[#qbZones + 1] = name
  end
end

local function removeTargets()
  -- the target resources may be stopped already; nothing to clean up then
  for _, zone in ipairs(oxZones) do
    local ok, err = pcall(function() exports.ox_target:removeZone(zone) end)
    if not ok then Debug("warn", "Removing an ox_target zone failed: %s", tostring(err)) end
  end
  for _, name in ipairs(qbZones) do
    local ok, err = pcall(function() exports["qb-target"]:RemoveZone(name) end)
    if not ok then Debug("warn", "Removing a qb-target zone failed: %s", tostring(err)) end
  end
  oxZones, qbZones = {}, {}
end

local function addTargets()
  oxZones, qbZones = {}, {}
  for _, locker in pairs(Config.Lockers) do
    local ok, err = pcall(addTarget, locker)
    if not ok then Log("error", ("Locker '%s': adding the target zone failed: %s"):format(locker.id, tostring(err))) end
  end
end

local function setupLocker(locker)
  local id = locker.id
  local hasTarget = GetTargetSystem() ~= "none"
  local textKey = "locker:" .. id
  points[#points + 1] = lib.points.new({
    coords = locker.coords,
    distance = MARKER_DISTANCE,
    nearby = function(point)
      if cache.vehicle or busy or lib.getOpenContextMenu() or not canUse(locker) then return hideText(textKey) end
      if Config.DrawMarkers then drawMarker(locker.coords) end
      if hasTarget then return end
      if point.currentDistance > 1.5 then return hideText(textKey) end
      showText(textKey, locale("open_archive_textui"))
      if IsControlJustReleased(0, KEY_E) and GetGameTimer() - lastKeyPress > 500 then
        lastKeyPress = GetGameTimer()
        hideText(textKey)
        -- the input dialog yields; don't block the points loop
        CreateThread(function() OpenEvidenceArchive(id) end)
      end
    end,
    onExit = function() hideText(textKey) end,
  })
end

exports("openEvidence", OpenEvidenceArchive)

local targetsAdded = false

OnEnvironmentReady(function()
  for _, locker in pairs(Config.Lockers) do
    local ok, err = pcall(setupLocker, locker)
    if not ok then Log("error", ("Locker '%s' could not be set up: %s"):format(tostring(locker.id), tostring(err))) end
  end

  local target = GetTargetSystem()
  if target == "none" then return end
  -- The client starts resources in server.cfg order: a target ensured after this resource isn't running here yet
  CreateThread(function()
    local nextWarning = GetGameTimer() + 10000
    while GetResourceState(target) ~= "started" do
      Wait(250)
      if GetGameTimer() >= nextWarning then
        Log("warn", ("Still waiting for %s to start on this client."):format(target))
        nextWarning = GetGameTimer() + 10000
      end
    end
    if targetsAdded then return end
    targetsAdded = true
    addTargets()
    Debug("info", "Evidence target zones added (%s)", target)
  end)
end)

-- A restarted target resource has forgotten our zones
AddEventHandler("onClientResourceStart", function(resource)
  if not targetsAdded or resource ~= GetTargetSystem() then return end
  addTargets()
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= RESOURCE then return end
  hideText()
  if lib.getOpenContextMenu() == MENU_ID then lib.hideContext() end
  if dialogOpen and lib.closeInputDialog then lib.closeInputDialog() end
  for _, point in ipairs(points) do point:remove() end
  removeTargets()
end)
