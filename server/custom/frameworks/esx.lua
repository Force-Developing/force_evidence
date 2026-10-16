-- Runs once force_evidence knows the framework is "esx" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("esx", function()
  local ESX
  local resource = GetFrameworkResource() or "es_extended"
  -- Loaded again when es_extended restarts: the old shared object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:getSharedObject()
  end, function(obj)
    ESX = obj
  end)

  --- @param source number
  --- @return table|nil { name, grade, onDuty }
  function GetPlayerJob(source)
    local xPlayer = ESX and ESX.GetPlayerFromId(source)
    local job = xPlayer and xPlayer.job
    if type(job) ~= "table" or type(job.name) ~= "string" then return nil end
    -- ESX has no duty state by default; newer versions with job.onDuty are respected
    return { name = job.name, grade = tonumber(job.grade) or 0, onDuty = job.onDuty ~= false }
  end

  local function toCitizen(row)
    if type(row) ~= "table" or type(row.identifier) ~= "string" then return nil end
    return {
      id = row.identifier,
      firstname = type(row.firstname) == "string" and row.firstname or "",
      lastname = type(row.lastname) == "string" and row.lastname or "",
      dob = type(row.dateofbirth) == "string" and row.dateofbirth or nil,
    }
  end

  --- One character by its identifier (the stash belongs to this id). Throws on a database error.
  --- @param id string
  --- @return table|nil { id, firstname, lastname, dob }
  function FindCitizenById(id)
    local rows = MySQL.query.await(
      "SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE identifier = ? LIMIT 1", { id })
    return toCitizen(rows and rows[1])
  end

  --- Characters whose first and last name start with the given (escaped, lower case) LIKE patterns.
  --- @param first string LIKE pattern
  --- @param last string LIKE pattern
  --- @param limit number
  --- @return table[]
  function FindCitizensByName(first, last, limit)
    local rows = MySQL.query.await(
      "SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE firstname LIKE ? AND lastname LIKE ? LIMIT ?",
      { first, last, limit }) or {}
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = toCitizen(row) end
    return out
  end
end)
