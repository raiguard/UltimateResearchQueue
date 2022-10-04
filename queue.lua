local event = require("__flib__.event")
local misc = require("__flib__.misc")

local util = require("__UltimateResearchQueue__.util")

--- @class Queue
local queue = {}

--- Add one or more technologies to the back of the queue
--- @param tech_names string[]
function queue:push(tech_names)
  local technologies = self.force.technologies
  local first_added
  for _, tech_name in pairs(tech_names) do
    if not self.queue[tech_name] then
      if not first_added then
        first_added = tech_name
      end
      self.queue[tech_name] = "[img=infinity]"
      util.update_research_state_reqs(self.force_table, technologies[tech_name])
    end
  end
  if next(self.queue) == first_added then
    self:update_active_research()
  end
  event.raise(util.on_research_queue_updated, { force = self.force })
end

--- Add one or more technologies to the front of the queue
--- @param tech_names string[]
function queue:push_front(tech_names)
  local technologies = self.force.technologies
  --- @type table<string, string>
  local new = {}
  for _, tech_name in pairs(tech_names) do
    new[tech_name] = "[img=infinity]"
    util.update_research_state_reqs(self.force_table, technologies[tech_name])
  end
  for name, duration in pairs(self.queue) do
    if not new[name] then
      new[name] = duration
    end
  end
  self.queue = new
  self:update_active_research()
  event.raise(util.on_research_queue_updated, { force = self.force })
end

--- @param tech_name string
--- @param is_recursive boolean?
function queue:remove(tech_name, is_recursive)
  if not self.queue[tech_name] then
    return
  end
  self.queue[tech_name] = nil
  local technologies = self.force.technologies
  util.update_research_state(self.force_table, technologies[tech_name])
  -- Remove any now-invalid researches from the queue
  if self.force_table.research_states[tech_name] ~= util.research_state.researched then
    local requisites = global.technology_requisites[tech_name]
    if requisites then
      for requisite_name in pairs(requisites) do
        if self.queue[requisite_name] then
          self:remove(requisite_name, true)
        end
        util.update_research_state(self.force_table, technologies[requisite_name])
      end
    end
  end
  if not is_recursive then
    self:update_active_research()
    event.raise(util.on_research_queue_updated, { force = self.force })
  end
end

function queue:update_active_research()
  local first = next(self.queue)
  if first then
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
  for tech_name in pairs(old_queue) do
    if self.force.technologies[tech_name] then
      self:push({ tech_name })
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
