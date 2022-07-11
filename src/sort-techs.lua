local table = require("__flib__.table")
local constants = require("constants")

--- @param tech LuaTechnology
--- @param queue Queue?
local function are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not table.find(queue.queue, name) then
        return false
      end
    end
  end
  return true
end

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return ResearchState
local function get_research_state(force_table, tech)
  if tech.researched then
    return constants.research_state.researched
  end
  if not tech.enabled then
    return constants.research_state.disabled
  end
  if are_prereqs_satisfied(tech) then
    return constants.research_state.available
  end
  if are_prereqs_satisfied(tech, force_table.queue) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
end

--- @class ToShow
--- @field tech LuaTechnology
--- @field state ResearchState

--- @param force LuaForce
--- @param force_table ForceTable
return function(force, force_table)
  local techs = {}
  for name, tech in pairs(force.technologies) do
    local research_state = get_research_state(force_table, tech)
    -- Factorio Lua preserves the insertion order of technologies
    techs[name] = { state = research_state, tech = tech }
  end
  force_table.technologies = techs
end
