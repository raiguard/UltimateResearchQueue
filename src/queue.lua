local table = require("__flib__.table")

--- @class Queue
local queue = {}

--- @param tech_name string
--- @param position integer?
function queue:add(tech_name, position)
  if not table.find(self.queue, tech_name) then
    position = position or #self.queue + 1
    table.insert(self.queue, position, tech_name)
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
end

--- @param tech_name string
function queue:remove(tech_name)
  local index = table.find(self.queue, tech_name)
  table.remove(self.queue, index)
  return index
end

function queue:verify_integrity()
  local new_queue = {}
  for _, tech_name in pairs(self.queue) do
    if self.force.technologies[tech_name] then
      table.insert(new_queue, tech_name)
    end
  end
  self.queue = new_queue
end

--- @param force LuaForce
--- @return Queue
function queue.new(force)
  --- @class Queue
  local self = {
    force = force,
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
