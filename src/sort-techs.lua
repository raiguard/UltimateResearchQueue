local table = require("__flib__.table")
local constants = require("constants")

--- @param tech LuaTechnology
local function are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not table.find(queue, function(tech)
        return tech.name == name
      end) then
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
    return constants.research_state.available
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
  for _, tech in pairs(force.technologies) do
    local research_state = get_research_state(force_table, tech)
    if research_state ~= constants.research_state.disabled then
      table.insert(techs, { state = research_state, tech = tech })
    end
  end
  force_table.technologies = techs
end
