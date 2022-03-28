local event = require("__flib__.event")
-- local gui = require("__flib__.gui")

local Gui = require("urq-gui")

--- @param force_index number
local function init_force(force_index)
  --- @class ForceTable
  global.forces[force_index] = {}
end

--- @param player_index number
local function init_player(player_index)
  --- @class PlayerTable
  global.players[player_index] = {}

  Gui.new(game.get_player(player_index), global.players[player_index])
end

event.on_init(function()
  global.forces = {}
  global.players = {}

  for force_index in pairs(game.forces) do
    init_force(force_index)
  end
  for player_index in pairs(game.players) do
    init_player(player_index)
  end
end)

event.on_force_created(function(e)
  init_force(e.force.index)
end)

event.on_player_created(function(e)
  init_player(e.player_index)
end)

-- gui.hook_events(function(e)
--   local action = gui.get_action(e)
--   if action then
--     -- TODO: GUI actions
--   end
-- end)
