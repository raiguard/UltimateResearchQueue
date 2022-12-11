local format = require("__flib__/format")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class Queue
local queue = {}

--- @param self Queue
--- @param tech_name string
--- @return boolean
function queue.contains(self, tech_name)
  return self.queue[tech_name] and true or false
end

--- Add one or more technologies to the back of the queue
--- @param self Queue
--- @param tech_names string[]
--- @return LocalisedString?
function queue.push(self, tech_names)
  local technologies = self.force.technologies
  local first_added
  local num_techs = #tech_names
  if num_techs > constants.queue_limit then
    return { "message.urq-too-many-unresearched-prerequisites" }
  else
    -- It shouldn't ever be greater... right?
    if self.len >= constants.queue_limit then
      return { "message.urq-queue-is-full" }
    elseif self.len + num_techs > constants.queue_limit then
      return { "message.urq-too-many-prerequisites-queue-full" }
    end
  end
  local last = tech_names[#tech_names]
  if queue.contains(self, last) then
    return { "message.urq-already-in-queue" }
  end
  for _, tech_name in pairs(tech_names) do
    if not self.queue[tech_name] then
      if not first_added then
        first_added = tech_name
      end
      self.queue[tech_name] = "[img=infinity]"
      self.len = self.len + 1
      -- FIXME:
      queue.update_research_state_reqs(self.force_table, technologies[tech_name])
    end
  end
  if next(self.queue) == first_added then
    queue.update_active_research(self)
  end
end

--- Add one or more technologies to the front of the queue
--- @param self Queue
--- @param tech_names string[]
function queue.push_front(self, tech_names)
  local technologies = self.force.technologies
  --- @type table<string, string>
  local new = {}
  for _, tech_name in pairs(tech_names) do
    new[tech_name] = "[img=infinity]"
    self.len = self.len + 1
    queue.update_research_state_reqs(self.force_table, technologies[tech_name])
  end
  for name, duration in pairs(self.queue) do
    if not new[name] then
      new[name] = duration
    end
  end
  self.queue = new
  queue.update_active_research(self)
end

--- @param self Queue
--- @param tech_name string
--- @param is_recursive boolean?
--- @return boolean?
function queue.remove(self, tech_name, is_recursive)
  if not self.queue[tech_name] then
    return
  end
  self.queue[tech_name] = nil
  self.len = self.len - 1
  local technologies = self.force.technologies
  local force_table = self.force_table
  local research_states = force_table.research_states
  queue.update_research_state(self.force_table, technologies[tech_name])
  -- Remove any now-invalid researches from the queue
  local requisites = global.technology_requisites[tech_name]
  if requisites then
    for requisite_name in pairs(requisites) do
      queue.update_research_state(force_table, technologies[requisite_name])
      if self.queue[requisite_name] and research_states[requisite_name] == constants.research_state.not_available then
        queue.remove(self, requisite_name, true)
      end
    end
  end
  if not is_recursive then
    queue.update_active_research(self)
  end
end

--- @param self Queue
function queue.toggle_paused(self)
  self.paused = not self.paused
  queue.update_active_research(self)
end

--- @param self Queue
function queue.update_active_research(self)
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

--- @param self Queue
--- @param speed number
function queue.update_durations(self, speed)
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

--- @param self Queue
function queue.verify_integrity(self)
  -- TODO: highest_levels
  local old_queue = self.queue
  self.queue = {}
  self.len = 0
  for tech_name in pairs(old_queue) do
    if self.force.technologies[tech_name] then
      queue.push(self, { tech_name })
      self.len = self.len + 1
    end
  end
end

--- @param force LuaForce
--- @param force_table ForceTable
--- @return Queue
function queue.new(force, force_table)
  --- @class Queue
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
function queue.update_research_state(force_table, technology)
  local order = global.technology_order[technology.name]
  local grouped_techs = force_table.grouped_technologies
  local previous_state = force_table.research_states[technology.name]
  local new_state = util.get_research_state(force_table, technology)
  -- Keep track of the highest-researched upgrade tech
  if technology.upgrade then
    local base_name = string.gsub(technology.name, "%-%d*$", "")
    local upgrade_level = technology.level
    local current_level = force_table.upgrade_states[base_name] or 0
    if
      upgrade_level > current_level
      and (new_state == constants.research_state.researched or queue.contains(force_table.queue, technology.name))
    then
      force_table.upgrade_states[base_name] = upgrade_level
    elseif upgrade_level <= current_level then
      force_table.upgrade_states[base_name] = upgrade_level - 1
    end
  end
  -- Change research state
  if new_state ~= previous_state then
    grouped_techs[previous_state][order] = nil
    grouped_techs[new_state][order] = technology
    force_table.research_states[technology.name] = new_state
  end
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function queue.update_research_state_reqs(force_table, technology)
  queue.update_research_state(force_table, technology)
  local requisites = global.technology_requisites[technology.name]
  if requisites then
    local technologies = technology.force.technologies
    for requisite_name in pairs(requisites) do
      queue.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

return queue
