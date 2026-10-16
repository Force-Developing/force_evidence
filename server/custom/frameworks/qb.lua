-- Runs once force_evidence knows the framework is "qb" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("qb", function()
  local QBCore
  local resource = GetFrameworkResource() or "qb-core"
  -- Loaded again when qb-core restarts: the old core object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:GetCoreObject()
  end, function(obj)
    QBCore = obj
  end)

  --- @param source number
  --- @return table|nil { name, grade, onDuty }
  function GetPlayerJob(source)
    local player = QBCore and QBCore.Functions.GetPlayer(source)
    local job = player and player.PlayerData and player.PlayerData.job
    if type(job) ~= "table" or type(job.name) ~= "string" then return nil end
    local grade = type(job.grade) == "table" and job.grade.level or job.grade
    return { name = job.name, grade = tonumber(grade) or 0, onDuty = job.onduty ~= false }
  end

  local function toCitizen(row)
    if type(row) ~= "table" or type(row.citizenid) ~= "string" then return nil end
    local charinfo = {}
    if type(row.charinfo) == "string" and row.charinfo ~= "" then
      local ok, decoded = pcall(json.decode, row.charinfo)
      if ok and type(decoded) == "table" then charinfo = decoded end
    end
    local function text(value) return type(value) == "string" and value or nil end
    return {
      id = row.citizenid,
      firstname = text(charinfo.firstname) or "",
      lastname = text(charinfo.lastname) or "",
      dob = text(charinfo.birthdate),
    }
  end

  --- One character by its citizenid (the stash belongs to this id). Throws on a database error.
  --- @param id string
  --- @return table|nil { id, firstname, lastname, dob }
  function FindCitizenById(id)
    local rows = MySQL.query.await("SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1", { id })
    return toCitizen(rows and rows[1])
  end

  --- Characters whose first and last name start with the given (escaped, lower case) LIKE patterns.
  --- charinfo is a JSON column; JSON_EXTRACT works on MySQL 5.7+ and MariaDB 10.2+.
  --- @param first string LIKE pattern
  --- @param last string LIKE pattern
  --- @param limit number
  --- @return table[]
  function FindCitizensByName(first, last, limit)
    local rows = MySQL.query.await([[
      SELECT citizenid, charinfo FROM players
      WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))) LIKE ?
        AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
      LIMIT ?]], { first, last, limit }) or {}
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = toCitizen(row) end
    return out
  end
end)
