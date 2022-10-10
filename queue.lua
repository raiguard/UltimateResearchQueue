local event = require("__flib__.event")
local misc = require("__flib__.misc")

local constants = require("__UltimateResearchQueue__.constants")
local util = require("__UltimateResearchQueue__.util")

--- @class Queue
local queue = {}

--- @param tech_name string
--- @return boolean
function queue:contains(tech_name)
  return self.queue[tech_name] and true or false
end

--- Add one or more technologies to the back of the queue
--- @param tech_names string[]
--- @return QueuePushError?
function queue:push(tech_names)
  local technologies = self.force.technologies
  local first_added
  local num_techs = #tech_names
  if num_techs > constants.queue_limit then
    return constants.queue_push_error.too_many_prerequisites
  else
    -- It shouldn't ever be greater... right?
    if self.len >= constants.queue_limit then
      return constants.queue_push_error.queue_full
    elseif self.len + num_techs > constants.queue_limit then
      return constants.queue_push_error.too_many_prerequisites_queue_full
    end
  end
  local last = tech_names[#tech_names]
  if self:contains(last) then
    return constants.queue_push_error.already_in_queue
  end
  for _, tech_name in pairs(tech_names) do
    if not self.queue[tech_name] then
      if not first_added then
        first_added = tech_name
      end
      self.queue[tech_name] = "[img=infinity]"
      self.len = self.len + 1
      util.update_research_state_reqs(self.force_table, technologies[tech_name])
    end
  end
  if next(self.queue) == first_added then
    self:update_active_research()
  end
  event.raise(constants.on_research_queue_updated, { force = self.force })
end

--- Add one or more technologies to the front of the queue
--- @param tech_names string[]
function queue:push_front(tech_names)
  local technologies = self.force.technologies
  --- @type table<string, string>
  local new = {}
  for _, tech_name in pairs(tech_names) do
    new[tech_name] = "[img=infinity]"
    self.len = self.len + 1
    util.update_research_state_reqs(self.force_table, technologies[tech_name])
  end
  for name, duration in pairs(self.queue) do
    if not new[name] then
      new[name] = duration
    end
  end
  self.queue = new
  self:update_active_research()
  event.raise(constants.on_research_queue_updated, { force = self.force })
end

--- @param tech_name string
--- @param is_recursive boolean?
function queue:remove(tech_name, is_recursive)
  if not self.queue[tech_name] then
    return
  end
  self.queue[tech_name] = nil
  self.len = self.len - 1
  local technologies = self.force.technologies
  local force_table = self.force_table
  local research_states = force_table.research_states
  util.update_research_state(self.force_table, technologies[tech_name])
  -- Remove any now-invalid researches from the queue
  local requisites = global.technology_requisites[tech_name]
  if requisites then
    for requisite_name in pairs(requisites) do
      util.update_research_state(force_table, technologies[requisite_name])
      if self.queue[requisite_name] and research_states[requisite_name] == constants.research_state.not_available then
        self:remove(requisite_name, true)
      end
    end
  end
  if not is_recursive then
    self:update_active_research()
    event.raise(constants.on_research_queue_updated, { force = self.force })
  end
end

function queue:toggle_paused()
  self.paused = not self.paused
  self:update_active_research()
  event.raise(constants.on_research_queue_updated, { force = self.force })
end

function queue:update_active_research()
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

--- @param speed number
function queue:update_durations(speed)
  local duration = 0
  for tech_name in pairs(self.queue) do
    if speed == 0 then
      self.queue[tech_name] = "[img=infinity]"
    else
      local tech = self.force.technologies[tech_name]
      local progress = util.get_research_progress(tech)
      duration = duration + (1 - progress) * util.get_research_unit_count(tech) * tech.research_unit_energy / speed
      self.queue[tech_name] = misc.ticks_to_timestring(duration)
    end
  end
end

function queue:verify_integrity()
  local old_queue = self.queue
  self.queue = {}
  self.len = 0
  for tech_name in pairs(old_queue) do
    if self.force.technologies[tech_name] then
      self:push({ tech_name })
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
  queue.load(self)
  return self
end

function queue.load(self)
  setmetatable(self, { __index = queue })
end

return queue
