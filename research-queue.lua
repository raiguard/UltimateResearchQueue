local format = require("__flib__/format")
local math = require("__flib__/math")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class ResearchQueueNode
--- @field technology LuaTechnology
--- @field level uint
--- @field duration string
--- @field key string
--- @field next ResearchQueueNode?

--- @class ResearchQueueMod
local research_queue = {}

--- @param self ResearchQueue
function research_queue.clear(self)
  while self.head do
    research_queue.remove(self, self.head.technology, self.head.level)
  end
end

--- @param self ResearchQueue
--- @param technology LuaTechnology
--- @param level boolean|uint?
--- @return boolean
function research_queue.contains(self, technology, level)
  if not util.is_multilevel(technology) then
    return not not self.lookup[technology.name]
  end

  local base_name = util.get_base_name(technology)
  if level and type(level) == "number" then
    -- This level
    return not not self.lookup[base_name .. "-" .. level]
  elseif level and technology.prototype.max_level ~= math.max_uint then
    -- All levels
    for i = technology.level, technology.prototype.max_level do
      if not self.lookup[base_name .. "-" .. i] then
        return false
      end
    end
  else
    -- Any level
    for key in pairs(self.lookup) do
      if string.find(key, base_name) then
        return true
      end
    end
  end

  return false
end

--- @param self ResearchQueue
--- @param technology LuaTechnology
--- @return uint
function research_queue.get_highest_level(self, technology)
  local node = self.head
  local highest = 0
  while node do
    if node.technology == technology then
      highest = math.max(node.level, highest)
    end
    node = node.next
  end
  return highest
end

--- Add a technology and its prerequisites to the queue.
--- @param self ResearchQueue
--- @param technology LuaTechnology
--- @param level uint
--- @param to_front boolean?
--- @return LocalisedString?
local function push(self, technology, level, to_front)
  -- Update flag and length
  self.len = self.len + 1
  -- Add to linked list
  local key = util.get_queue_key(technology, level)
  --- @type ResearchQueueNode
  local new_node = { technology = technology, level = level, duration = "[img=infinity]", key = key }
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
  research_queue.update_research_state_reqs(self.force_table, technology)
  if self.head.technology == technology and self.head.level == level then
    research_queue.update_active_research(self)
  end
end

--- @param to_research TechnologyAndLevel[]
--- @param technology LuaTechnology
--- @param level uint?
--- @param queue ResearchQueue?
local function add_tech(to_research, technology, level, queue)
  local lower = technology.level
  if queue then
    lower = math.max(research_queue.get_highest_level(queue, technology) + 1, lower)
  end
  for i = lower, level or technology.prototype.max_level do
    table.insert(to_research, { technology = technology, level = i })
  end
end

--- Add a technology and its prerequisites to the queue.
--- @param self ResearchQueue
--- @param technology LuaTechnology
--- @param level uint
--- @param to_front boolean?
--- @return LocalisedString?
function research_queue.push(self, technology, level, to_front)
  local research_state = self.force_table.research_states[technology.name]
  if research_state == constants.research_state.researched then
    return { "message.urq-already-researched" }
  elseif research_queue.contains(self, technology, level) then
    return { "message.urq-already-in-queue" }
  end
  --- @type TechnologyAndLevel[]
  local to_research = {}
  if research_state == constants.research_state.not_available then
    -- Add all prerequisites to research this tech ASAP
    local technologies = self.force.technologies
    local technology_prerequisites = global.technology_prerequisites[technology.name]
    for i = 1, #technology_prerequisites do
      local prerequisite_name = technology_prerequisites[i]
      local prerequisite = technologies[prerequisite_name]
      local prerequisite_research_state = self.force_table.research_states[prerequisite_name]
      if
        not research_queue.contains(self, prerequisite, true)
        and prerequisite_research_state ~= constants.research_state.researched
      then
        add_tech(to_research, prerequisite)
      end
    end
  end
  add_tech(to_research, technology, level, self.force_table.queue)
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
    push(self, to_research.technology, to_research.level, to_front)
  end
end

--- @param self ResearchQueue
--- @param technology LuaTechnology
--- @param level uint
--- @param is_recursive boolean?
--- @return boolean?
function research_queue.remove(self, technology, level, is_recursive)
  local key = util.get_queue_key(technology, level)
  if not self.lookup[key] then
    return
  end
  -- Remove from linked list
  local node, prev = self.head, nil
  while node and (node.technology ~= technology or node.level ~= level) do
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
  research_queue.update_research_state(self.force_table, technology)
  -- Remove requisites
  local technologies = self.force.technologies
  local force_table = self.force_table
  local research_states = force_table.research_states
  local requisites = global.technology_requisites[technology.name]
  if requisites then
    for _, requisite_name in pairs(requisites) do
      local requisite = technologies[requisite_name]
      research_queue.update_research_state(force_table, requisite)
      local level = requisite.level
      if util.is_multilevel(technology) then
        level = level + 1
      end
      if
        research_queue.contains(self, requisite, level)
        and research_states[requisite_name] == constants.research_state.not_available
      then
        research_queue.remove(self, requisite, level, true)
      end
    end
  end
  -- Remove all levels above this one
  if util.is_multilevel(technology) and technology.level <= level then
    local node = self.head
    while node do
      if node.technology == technology and node.level > level then
        research_queue.remove(self, technology, node.level, true)
      end
      node = node.next
    end
  end
  if not is_recursive then
    research_queue.update_active_research(self)
  end
end

--- @param self ResearchQueue
function research_queue.requeue_infinite(self)
  if not self.requeue_infinite then
    return
  end
  local head = self.head
  if not head then
    return
  end
  local technology = head.technology
  if not util.is_multilevel(technology) or technology.prototype.max_level ~= math.max_uint then
    return
  end
  research_queue.push(self, technology, research_queue.get_highest_level(self, technology) + 1)
end

--- @param self ResearchQueue
function research_queue.toggle_paused(self)
  self.paused = not self.paused
  research_queue.update_active_research(self)
end

--- @param self ResearchQueue
function research_queue.toggle_requeue_infinite(self)
  self.requeue_infinite = not self.requeue_infinite
end

--- @param self ResearchQueue
function research_queue.update_active_research(self)
  local head = self.head
  if not self.paused and head then
    local current_research = self.force.current_research
    if not current_research or head.technology.name ~= current_research.name then
      self.force.add_research(head.technology)
      self.force_table.last_research_progress = util.get_research_progress(head.technology, head.level)
    end
  else
    self.force.cancel_current_research()
    self.force_table.last_research_progress = 0
  end
  self.force_table.last_research_progress_tick = game.tick
end

--- @param self ResearchQueue
function research_queue.update_durations(self)
  local speed = self.force_table.research_speed
  local duration = 0
  local node = self.head
  while node do
    if speed == 0 then
      node.duration = "[img=infinity]"
    else
      local technology, level = node.technology, node.level
      local progress = util.get_research_progress(technology, level)
      duration = duration
        + (1 - progress)
          * util.get_research_unit_count(technology, node.level)
          * technology.research_unit_energy
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
  local technologies = self.force.technologies
  while node do
    local old_technology, old_level = node.technology, node.level
    local technology = technologies[old_technology.name]
    if
      util.is_multilevel(old_technology)
      and (old_level < technology.prototype.level or old_level > technology.prototype.max_level)
    then
      goto continue
    end
    research_queue.push(self, technology, level)
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
    requeue_infinite = false,
  }
  return self
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function research_queue.update_research_state(force_table, technology)
  local order = global.technology_order[technology.name]
  local tech_groups = force_table.technology_groups
  local previous_state = force_table.research_states[technology.name]
  local new_state = research_queue.get_research_state(force_table, technology)
  -- Change research state
  if new_state ~= previous_state then
    tech_groups[previous_state][order] = nil
    tech_groups[new_state][order] = technology
    force_table.research_states[technology.name] = new_state
  end
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function research_queue.update_research_state_reqs(force_table, technology)
  research_queue.update_research_state(force_table, technology)
  local requisites = global.technology_requisites[technology.name]
  if requisites then
    local technologies = force_table.force.technologies
    for _, requisite_name in pairs(requisites) do
      research_queue.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

--- @param technology LuaTechnology
local function are_prereqs_satisfied(technology)
  for _, prereq in pairs(technology.prerequisites) do
    if not prereq.researched then
      return false
    end
  end
  return true
end

--- @param technology LuaTechnology
--- @param force_table ForceTable
local function are_prereqs_satisfied_or_queued(technology, force_table)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched and not research_queue.contains(force_table.queue, prerequisite, true) then
      return false
    end
  end
  return true
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
--- @return ResearchState
function research_queue.get_research_state(force_table, technology)
  if technology.researched then
    return constants.research_state.researched
  end
  if not technology.enabled then
    return constants.research_state.disabled
  end
  if are_prereqs_satisfied(technology) then
    return constants.research_state.available
  end
  if are_prereqs_satisfied_or_queued(technology, force_table) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
end

return research_queue
