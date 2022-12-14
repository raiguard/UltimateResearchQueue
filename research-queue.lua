local format = require("__flib__/format")
local math = require("__flib__/math")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class ResearchQueueNode
--- @field data TechnologyData
--- @field level uint
--- @field next ResearchQueueNode?

--- @class ResearchQueue
local research_queue = {}

function research_queue.clear(self)
  while self.head do
    research_queue.remove(self, self.head.data, self.head.level)
  end
end

--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level boolean|uint?
--- @return boolean
function research_queue.contains(self, tech_data, level)
  if not tech_data.is_multilevel then
    return not not self.durations[tech_data.name]
  end

  if level and type(level) == "number" then
    -- This level
    return not not self.durations[tech_data.base_name .. "-" .. level]
  elseif level and tech_data.max_level ~= math.max_uint then
    -- All levels
    for i = tech_data.technology.level, tech_data.max_level do
      if not self.durations[tech_data.base_name .. "-" .. i] then
        return false
      end
    end
  else
    -- Any level
    for key in pairs(self.durations) do
      if string.find(key, tech_data.base_name) then
        return true
      end
    end
  end

  return false
end

--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @return uint
function research_queue.get_highest_level(self, tech_data)
  local node = self.head
  local highest = 0
  while node do
    if node.data == tech_data then
      highest = math.max(node.level, highest or 0)
    end
    node = node.next
  end
  return highest
end

--- Add one or more technologies to the back of the queue
--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level uint
--- @param front boolean?
--- @return LocalisedString?
function research_queue.push(self, tech_data, level, front)
  if research_queue.contains(self, tech_data, level) then
    return { "message.urq-already-in-queue" }
  end
  tech_data.in_queue = true
  -- Add duration and increment length
  local queue_name = util.get_queue_name(tech_data, level)
  self.durations[queue_name] = "[img=infinity]"
  self.len = self.len + 1
  -- Add to linked list
  --- @type ResearchQueueNode
  if front or not self.head then
    self.head = { data = tech_data, level = level, next = self.head }
  else
    local node = self.head --[[@as ResearchQueueNode]]
    while node.next do --- @diagnostic disable-line
      node = node.next
    end
    node.next = { data = tech_data, level = level }
  end
  -- Update research states
  research_queue.update_research_state_reqs(self.force_table, tech_data)
  if self.head.data == tech_data then
    research_queue.update_active_research(self)
  end
end

--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level uint?
--- @return boolean?
function research_queue.remove(self, tech_data, level)
  if not level then
    local node = self.head
    while node do
      if node.data == tech_data then
        research_queue.remove(self, tech_data, node.level)
      end
      node = node.next
    end
    return
  end
  local queue_name = util.get_queue_name(tech_data, level)
  if not self.durations[queue_name] then
    return
  end
  -- Remove from linked list
  local node = self.head
  while node and (node.data ~= tech_data or node.level ~= level) do
    node = node.next
  end
  if not node then
    return
  end
  -- Remove duration and decrement length
  self.durations[queue_name] = nil
  self.len = self.len - 1
  if node == self.head then
    self.head = node.next
  end
  -- Update in_queue status
  if tech_data.is_multilevel then
    tech_data.in_queue = research_queue.contains(self, tech_data, true)
  else
    tech_data.in_queue = false
  end
  -- Update research states
  research_queue.update_research_state(self.force_table, tech_data)
  -- Remove requisites
  local technologies = self.force_table.technologies
  local force_table = self.force_table
  local requisites = global.technology_requisites[tech_data.name]
  if requisites then
    for _, requisite_name in pairs(requisites) do
      local requisite_data = technologies[requisite_name]
      research_queue.update_research_state(force_table, requisite_data)
      if requisite_data.in_queue and requisite_data.research_state == constants.research_state.not_available then
        -- FIXME: Multilevel
        research_queue.remove(self, requisite_data)
      end
    end
  end
  research_queue.update_active_research(self)
end

--- @param self ResearchQueue
function research_queue.toggle_paused(self)
  self.paused = not self.paused
  research_queue.update_active_research(self)
end

--- @param self ResearchQueue
function research_queue.update_active_research(self)
  local head = self.head
  if not self.paused and head then
    local current_research = self.force.current_research
    if not current_research or head.data.name ~= current_research.name then
      self.force.add_research(head.data.technology)
    end
  else
    self.force.cancel_current_research()
  end
end

--- @param self ResearchQueue
--- @param speed number
function research_queue.update_durations(self, speed)
  local duration = 0
  local node = self.head
  while node do
    if speed == 0 then
      self.durations[util.get_queue_name(node.data, node.level)] = "[img=infinity]"
    else
      local tech_data = node.data
      local progress = util.get_research_progress(tech_data.technology)
      duration = duration
        + (1 - progress)
          * util.get_research_unit_count(tech_data.technology, node.level)
          * tech_data.technology.research_unit_energy
          / speed
      self.durations[util.get_queue_name(node.data, node.level)] = format.time(duration --[[@as uint]])
    end
    node = node.next
  end
end

--- @param self ResearchQueue
function research_queue.verify_integrity(self)
  -- TODO: highest_levels
  -- local old_queue = self.queue
  -- self.queue = {}
  -- self.len = 0
  -- for tech_name in pairs(old_queue) do
  --   if self.force.technologies[tech_name] then
  --     research_queue.push(self, tech_name)
  --     self.len = self.len + 1
  --   end
  -- end
end

--- @param force LuaForce
--- @param force_table ForceTable
--- @return ResearchQueue
function research_queue.new(force, force_table)
  --- @class ResearchQueue
  local self = {
    --- @type table<string, string>
    durations = {},
    force = force,
    force_table = force_table,
    --- @type ResearchQueueNode?
    head = nil,
    len = 0,
    paused = false,
    -- --- @type ResearchQueueNode?
    -- tail = nil,
  }
  return self
end

--- @param force_table ForceTable
--- @param tech_data TechnologyData
function research_queue.update_research_state(force_table, tech_data)
  local order = global.technology_order[tech_data.name]
  local tech_groups = force_table.technology_groups
  local previous_state = tech_data.research_state
  local new_state = research_queue.get_research_state(force_table, tech_data)
  -- Change research state
  if new_state ~= previous_state then
    tech_groups[previous_state][order] = nil
    tech_groups[new_state][order] = tech_data
    tech_data.research_state = new_state
  end
end

--- @param force_table ForceTable
--- @param tech_data TechnologyData
function research_queue.update_research_state_reqs(force_table, tech_data)
  research_queue.update_research_state(force_table, tech_data)
  local requisites = global.technology_requisites[tech_data.name]
  if requisites then
    local technologies = force_table.technologies
    for _, requisite_name in pairs(requisites) do
      research_queue.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

--- @param tech_data TechnologyData
local function are_prereqs_satisfied(tech_data)
  for _, prereq in pairs(tech_data.technology.prerequisites) do
    if not prereq.researched then
      return false
    end
  end
  return true
end

--- @param tech_data TechnologyData
--- @param force_table ForceTable
local function are_prereqs_satisfied_or_queued(tech_data, force_table)
  for _, prereq in pairs(tech_data.technology.prerequisites) do
    local prereq_data = force_table.technologies[prereq.name]
    if not prereq.researched and not prereq_data.in_queue then
      return false
    end
  end
  return true
end

--- @param force_table ForceTable
--- @param tech_data TechnologyData
--- @return ResearchState
function research_queue.get_research_state(force_table, tech_data)
  local technology = tech_data.technology
  if technology.researched then
    return constants.research_state.researched
  end
  if not technology.enabled then
    return constants.research_state.disabled
  end
  if are_prereqs_satisfied(tech_data) then
    return constants.research_state.available
  end
  if are_prereqs_satisfied_or_queued(tech_data, force_table) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
end

return research_queue
