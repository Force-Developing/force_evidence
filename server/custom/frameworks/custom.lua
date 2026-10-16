-- Runs once force_evidence knows the framework is "custom": Config.Framework = "custom", or "auto" when none
-- of qbx_core, es_extended and qb-core is installed. Keep your code inside this function.
RegisterFramework("custom", function()
  --- TODO: return the player's job from your framework. Without it nobody can use a locker.
  --- @param source number
  --- @return table|nil { name = "police", grade = 0, onDuty = true }
  function GetPlayerJob(source)
    return nil
  end

  --- TODO: look up one character by the id its evidence stash is stored under.
  --- @param id string
  --- @return table|nil { id = "ABC12345", firstname = "John", lastname = "Doe", dob = "1990-01-01" }
  function FindCitizenById(id)
    return nil
  end

  --- TODO: characters whose names match the LIKE patterns (lower case, wildcards escaped, ending in %).
  --- @param first string
  --- @param last string
  --- @param limit number
  --- @return table[] list like FindCitizenById returns
  function FindCitizensByName(first, last, limit)
    return {}
  end
end)
