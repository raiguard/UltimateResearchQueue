local format = require("__flib__/format")
local math = require("__flib__/math")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class ResearchQueueNode
--- @field data TechnologyData
--- @field level uint
--- @field duration string
--- @field key string
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
    return not not self.lookup[tech_data.name]
  end

  if level and type(level) == "number" then
    -- This level
    return not not self.lookup[tech_data.base_name .. "-" .. level]
  elseif level and tech_data.max_level ~= math.max_uint then
    -- All levels
    for i = tech_data.technology.level, tech_data.max_level do
      if not self.lookup[tech_data.base_name .. "-" .. i] then
        return false
      end
    end
  else
    -- Any level
    for key in pairs(self.lookup) do
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
      highest = math.max(node.level, highest)
    end
    node = node.next
  end
  return highest
end

--- Add a technology and its prerequisites to the queue.
--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level uint
--- @param to_front boolean?
--- @return LocalisedString?
local function push(self, tech_data, level, to_front)
  -- Update flag and length
  self.len = self.len + 1
  -- Add to linked list
  local key = util.get_queue_key(tech_data, level)
  --- @type ResearchQueueNode
  local new_node = { data = tech_data, level = level, duration = "", key = key }
  self.lookup[key] = new_node
  if to_front or not self.head then
    new_node.next = self.head
    self.head = new_node
  else
    local node = self.head
    while node and node.next do
      node = node.next
    end
    -- This shouldn't ever fail...
    node.next = new_node
  end
  -- Update research states
  research_queue.update_research_state_reqs(self.force_table, tech_data)
  if self.head.data == tech_data and self.head.level == level then
    research_queue.update_active_research(self)
  end
end

--- @param to_research TechnologyDataAndLevel[]
--- @param tech_data TechnologyData
--- @param level uint?
--- @param queue ResearchQueue?
local function add_tech(to_research, tech_data, level, queue)
  local lower = tech_data.technology.level
  if queue then
    lower = math.max(research_queue.get_highest_level(queue, tech_data) + 1, lower)
  end
  for i = lower, level or tech_data.max_level do
    table.insert(to_research, { data = tech_data, level = i })
  end
end

--- Add a technology and its prerequisites to the queue.
--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level uint
--- @param to_front boolean?
--- @return LocalisedString?
function research_queue.push(self, tech_data, level, to_front)
  local research_state = tech_data.research_state
  if research_state == constants.research_state.researched then
    return { "message.urq-already-researched" }
  elseif research_queue.contains(self, tech_data, level) then
    return { "message.urq-already-in-queue" }
  end
  --- @type TechnologyDataAndLevel[]
  local to_research = {}
  if research_state == constants.research_state.not_available then
    -- Add all prerequisites to research this tech ASAP
    local technology = tech_data.technology
    local technologies = self.force_table.technologies
    local technology_prerequisites = global.technology_prerequisites[technology.name]
    for i = 1, #technology_prerequisites do
      local prerequisite_data = technologies[technology_prerequisites[i]]
      if
        not research_queue.contains(self, prerequisite_data, true)
        and prerequisite_data.research_state ~= constants.research_state.researched
      then
        add_tech(to_research, prerequisite_data)
      end
    end
  end
  add_tech(to_research, tech_data, level, self.force_table.queue)
  -- Check for errors
  local num_to_research = #to_research
  if num_to_research > constants.queue_limit then
    return { "message.urq-too-many-unresearched-prerequisites" }
  else
    local len = self.force_table.queue.len
    -- It shouldn't ever be greater... right?
    if len >= constants.queue_limit then
      return { "message.urq-queue-is-full" }
    elseif len + num_to_research > constants.queue_limit then
      return { "message.urq-too-many-prerequisites-queue-full" }
    end
  end
  local start, stop, step
  if to_front then
    start, stop, step = num_to_research, 1, -1
  else
    start, stop, step = 1, num_to_research, 1
  end
  for i = start, stop, step do
    local to_research = to_research[i]
    push(self, to_research.data, to_research.level, to_front)
  end
end

--- @param self ResearchQueue
--- @param tech_data TechnologyData
--- @param level uint
--- @param is_recursive boolean?
--- @return boolean?
function research_queue.remove(self, tech_data, level, is_recursive)
  local key = util.get_queue_key(tech_data, level)
  if not self.lookup[key] then
    return
  end
  -- Remove from linked list
  local node, prev = self.head, nil
  while node and (node.data ~= tech_data or node.level ~= level) do
    prev = node
    node = node.next
  end
  if not node then
    return
  end
  -- Remove node and decrement length
  self.lookup[key] = nil
  self.len = self.len - 1
  if node == self.head then
    self.head = node.next
  else
    prev.next = node.next
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
      local level = requisite_data.technology.level
      if requisite_data.is_multilevel then
        level = level + 1
      end
      if
        research_queue.contains(self, requisite_data, level)
        and requisite_data.research_state == constants.research_state.not_available
      then
        research_queue.remove(self, requisite_data, level, true)
      end
    end
  end
  -- TODO: Remove higher-level techs
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
      node.duration = "[img=infinity]"
    else
      local tech_data = node.data
      local progress = util.get_research_progress(tech_data, level)
      duration = duration
        + (1 - progress)
          * util.get_research_unit_count(tech_data.technology, node.level)
          * tech_data.technology.research_unit_energy
          / speed
      node.duration = format.time(duration --[[@as uint]])
    end
    node = node.next
  end
end

--- @param self ResearchQueue
function research_queue.verify_integrity(self)
  local old_head = self.head
  self.head, self.lookup, self.len = nil, {}, 0
  local node = old_head
  local technologies = self.force_table.technologies
  while node do
    local old_tech_data, old_level = node.data, node.level
    local tech_data = technologies[old_tech_data.name]
    if not tech_data then
      goto continue
    end
    if old_tech_data.is_multilevel and (old_level < tech_data.base_level or old_level > tech_data.max_level) then
      goto continue
    end
    research_queue.push(self, tech_data, level)
    ::continue::
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
    --- @type ResearchQueueNode?
    head = nil,
    len = 0,
    --- @type table<string, ResearchQueueNode>
    lookup = {},
    paused = false,
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
    if not prereq.researched and not research_queue.contains(force_table.queue, prereq_data, true) then
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
