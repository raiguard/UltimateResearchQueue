local format = require("__flib__/format")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

--- @class ResearchQueueNode
--- @field data TechnologyData
--- @field level uint?
--- @field next ResearchQueueNode?
--- @field prev ResearchQueueNode?

--- @class ResearchQueue
local research_queue = {}

--- @param self ResearchQueue
--- @param tech_data TechnologyDataWithLevel
--- @return boolean
function research_queue.contains(self, tech_data)
  local entry = self.durations[tech_data.data.name]
  if not entry and tech_data.level then
    entry = self.durations[tech_data.data.base_name .. "-" .. tech_data.level]
  end
  return entry and true or false
end

--- Add one or more technologies to the back of the queue
--- @param self ResearchQueue
--- @param tech_data TechnologyDataWithLevel
--- @param front boolean?
--- @return LocalisedString?
function research_queue.push(self, tech_data, front)
  local name = util.get_technology_name(tech_data)
  local tech_data, level = tech_data.data, tech_data.level
  if tech_data.in_queue then
    return { "message.urq-already-in-queue" }
  end
  tech_data.in_queue = true
  -- Add duration and increment length
  self.durations[name] = "[img=infinity]"
  self.len = self.len + 1
  -- Add to linked list
  if front then
    --- @type ResearchQueueNode
    local new_head = { data = tech_data, level = level, next = self.head }
    if self.head then
      self.head.prev = new_head
    end
    self.head = new_head
    if not self.tail then
      self.tail = new_head
    end
  else
    --- @type ResearchQueueNode
    local new_tail = { data = tech_data, level = level, prev = self.tail }
    if self.tail then
      self.tail.next = new_tail
    end
    self.tail = new_tail
    if not self.head then
      self.head = new_tail
    end
  end
  -- Update research states
  research_queue.update_research_state_reqs(self.force_table, tech_data)
  if self.head.data == tech_data then
    research_queue.update_active_research(self)
  end
end

--- @param self ResearchQueue
--- @param tech_data TechnologyDataWithLevel|ResearchQueueNode
--- @return boolean?
function research_queue.remove(self, tech_data)
  local name = util.get_technology_name(tech_data)
  local tech_data, level = tech_data.data, tech_data.level
  if not self.durations[name] then
    return
  end
  tech_data.in_queue = false
  -- Remove duration and decrement length
  self.durations[name] = nil
  self.len = self.len - 1
  -- Remove from linked list
  local node, prev = self.head, nil
  while node and (node.data ~= tech_data or node.level ~= level) do
    prev = node
    node = node.next
  end
  if node then
    if node == self.head then
      self.head = node.next
    end
    if node == self.tail then
      self.tail = node.prev
    end
    if prev then
      prev.next = node.next
    end
  end
  -- Update research states
  research_queue.update_research_state(self.force_table, tech_data)
  -- Remove requisites
  local technologies_lookup = self.force_table.technologies_lookup
  local force_table = self.force_table
  local requisites = global.technology_requisites[tech_data.name]
  if requisites then
    for _, requisite_name in pairs(requisites) do
      local requisite_data = technologies_lookup[requisite_name]
      research_queue.update_research_state(force_table, requisite_data)
      if
        research_queue.contains(self, { data = requisite_data })
        and requisite_data.research_state == constants.research_state.not_available
      then
        research_queue.remove(self, { data = requisite_data })
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
      self.durations[util.get_technology_name(node)] = "[img=infinity]"
    else
      local tech_data = node.data
      local progress = util.get_research_progress(tech_data.technology)
      duration = duration
        + (1 - progress)
          * util.get_research_unit_count(tech_data.technology, node.level)
          * tech_data.technology.research_unit_energy
          / speed
      self.durations[util.get_technology_name(node)] = format.time(duration --[[@as uint]])
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
    --- @type ResearchQueueNode?
    tail = nil,
  }
  return self
end

--- @param force_table ForceTable
--- @param tech_data TechnologyData
function research_queue.update_research_state(force_table, tech_data)
  local order = global.technology_order[tech_data.name]
  local tech_groups = force_table.technology_groups
  local previous_state = tech_data.research_state
  local new_state = util.get_research_state(tech_data)
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
    local technologies = force_table.technologies_lookup
    for _, requisite_name in pairs(requisites) do
      research_queue.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

return research_queue
