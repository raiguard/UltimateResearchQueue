local format = require("__flib__/format")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class ResearchQueue
local research_queue = {}

--- @param self ResearchQueue
--- @param tech_name string
--- @return boolean
function research_queue.contains(self, tech_name)
  return self.queue[tech_name] and true or false
end

--- Add one or more technologies to the back of the queue
--- @param self ResearchQueue
--- @param tech_name string
--- @return LocalisedString?
function research_queue.push(self, tech_name)
  local technologies = self.force.technologies
  if research_queue.contains(self, tech_name) then
    return { "message.urq-already-in-queue" }
  end
  self.queue[tech_name] = "[img=infinity]"
  self.len = self.len + 1
  research_queue.update_research_state_reqs(self.force_table, technologies[tech_name])
  if next(self.queue) == tech_name then
    research_queue.update_active_research(self)
  end
end

--- Add one or more technologies to the front of the queue
--- @param self ResearchQueue
--- @param tech_name string
function research_queue.push_front(self, tech_name)
  local technologies = self.force.technologies
  --- @type table<string, string>
  local new = { [tech_name] = "[img=infinity]" }
  research_queue.update_research_state_reqs(self.force_table, technologies[tech_name])
  for name, duration in pairs(self.queue) do
    if not new[name] then
      new[name] = duration
    end
  end
  self.queue = new
  research_queue.update_active_research(self)
end

--- @param self ResearchQueue
--- @param tech_name string
--- @param is_recursive boolean?
--- @return boolean?
function research_queue.remove(self, tech_name, is_recursive)
  if not self.queue[tech_name] then
    return
  end
  self.queue[tech_name] = nil
  self.len = self.len - 1
  local technologies = self.force.technologies
  local force_table = self.force_table
  local research_states = force_table.research_states
  research_queue.update_research_state(self.force_table, technologies[tech_name])
  -- Remove any now-invalid researches from the queue
  local requisites = global.technology_requisites[tech_name]
  if requisites then
    for requisite_name in pairs(requisites) do
      research_queue.update_research_state(force_table, technologies[requisite_name])
      if self.queue[requisite_name] and research_states[requisite_name] == constants.research_state.not_available then
        research_queue.remove(self, requisite_name, true)
      end
    end
  end
  if not is_recursive then
    research_queue.update_active_research(self)
  end
end

--- @param self ResearchQueue
function research_queue.toggle_paused(self)
  self.paused = not self.paused
  research_queue.update_active_research(self)
end

--- @param self ResearchQueue
function research_queue.update_active_research(self)
  local first = next(self.queue)
  if not self.paused and first then
    local current_research = self.force.current_research
    if not current_research or first ~= current_research.name then
      self.force.add_research(first)
    end
  else
    self.force.cancel_current_research()
  end
end

--- @param self ResearchQueue
--- @param speed number
function research_queue.update_durations(self, speed)
  local duration = 0
  for tech_name in pairs(self.queue) do
    if speed == 0 then
      self.queue[tech_name] = "[img=infinity]"
    else
      local tech = self.force.technologies[tech_name]
      local progress = util.get_research_progress(tech)
      duration = duration + (1 - progress) * util.get_research_unit_count(tech) * tech.research_unit_energy / speed
      self.queue[tech_name] = format.time(duration --[[@as uint]])
    end
  end
end

--- @param self ResearchQueue
function research_queue.verify_integrity(self)
  -- TODO: highest_levels
  local old_queue = self.queue
  self.queue = {}
  self.len = 0
  for tech_name in pairs(old_queue) do
    if self.force.technologies[tech_name] then
      research_queue.push(self, tech_name)
      self.len = self.len + 1
    end
  end
end

--- @param force LuaForce
--- @param force_table ForceTable
--- @return ResearchQueue
function research_queue.new(force, force_table)
  --- @class ResearchQueue
  local self = {
    force = force,
    force_table = force_table,
    len = 0,
    paused = false,
    --- @type table<string, string>
    queue = {},
  }
  return self
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function research_queue.update_research_state(force_table, technology)
  local order = global.technology_order[technology.name]
  local grouped_techs = force_table.grouped_technologies
  local previous_state = force_table.research_states[technology.name]
  local new_state = util.get_research_state(force_table, technology)
  -- Change research state
  if new_state ~= previous_state then
    grouped_techs[previous_state][order] = nil
    grouped_techs[new_state][order] = technology
    force_table.research_states[technology.name] = new_state
  end
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function research_queue.update_research_state_reqs(force_table, technology)
  research_queue.update_research_state(force_table, technology)
  local requisites = global.technology_requisites[technology.name]
  if requisites then
    local technologies = technology.force.technologies
    for requisite_name in pairs(requisites) do
      research_queue.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

return research_queue
