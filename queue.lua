local event = require("__flib__.event")
local misc = require("__flib__.misc")
local table = require("__flib__.table")

local sort_techs = require("__UltimateResearchQueue__.sort-techs")
local util = require("__UltimateResearchQueue__.util")

--- @class Queue
local queue = {}

--- @param tech_name string
--- @param position integer?
function queue:add(tech_name, position)
  if not table.find(self.queue, tech_name) then
    position = position or #self.queue + 1
    table.insert(self.queue, position, tech_name)
    self:update()
    return position
  end
end

--- @param tech_name string
--- @param position integer
function queue:move(tech_name, position)
  local index = self:remove(tech_name)
  if position > index then
    position = position - 1
  end
  self:add(tech_name, position)
  self:update()
end

--- @param tech_name string
function queue:remove(tech_name)
  local index = table.find(self.queue, tech_name)
  table.remove(self.queue, index)
  self:update()
  return index
end

function queue:update()
  local i = next(self.queue)
  while i do
    local tech_name = self.queue[i]
    if not tech_name then
      break
    end
    local tech_data = self.force_table.technologies[tech_name]
    if sort_techs.are_prereqs_satisfied(tech_data.tech, self) and tech_data.state ~= sort_techs.research_state.researched then
      i = next(self.queue, i)
    else
      table.remove(self.queue, i)
    end
  end

  local first_tech = self.queue[1]
  if first_tech then
    self.force.add_research(first_tech)
  else
    self.force.cancel_current_research()
  end

  event.raise(util.research_queue_updated_event, { force = self.force })
end

--- @param speed number
function queue:update_durations(speed)
  self.durations = {}
  local duration = 0
  for _, tech_name in pairs(self.queue) do
    if speed == 0 then
      self.durations[tech_name] = "[img=infinity]"
    else
      local tech = self.force.technologies[tech_name]
      local progress = util.get_research_progress(tech)
      duration = duration + (1 - progress) * util.get_research_unit_count(tech) * tech.research_unit_energy / speed
      self.durations[tech_name] = misc.ticks_to_timestring(duration)
    end
  end
end

function queue:verify_integrity()
  local new_queue = {}
  for _, tech_name in pairs(self.queue) do
    if self.force.technologies[tech_name] then
      table.insert(new_queue, tech_name)
    end
  end
  self.queue = new_queue
  self:update()
end

--- @param force LuaForce
--- @param force_table ForceTable
--- @return Queue
function queue.new(force, force_table)
  --- @class Queue
  local self = {
    --- @type table<string, string>
    durations = {},
    force = force,
    force_table = force_table,
    --- @type string[]
    queue = {},
  }
  queue.load(self)
  return self
end

function queue.load(self)
  setmetatable(self, { __index = queue })
end

return queue
