local event = require("__flib__.event")
-- local gui = require("__flib__.gui")
local on_tick_n = require("__flib__.on-tick-n")

local sort_techs = require("sort-techs")
local Gui = require("urq-gui")

--- @class UpgradeState
--- @field min_not_researched_level number
--- @field researched_level number
--- @field max_queued_level number

--- @param force LuaForce
local function init_force(force)
  --- @class ForceTable
  local force_table = {
    --- @type string[]
    queue = {},
    --- @type ToShow[]
    technologies = {},
  }
  global.forces[force.index] = force_table

  sort_techs(force, force_table)
end

--- @param player_index number
local function init_player(player_index)
  --- @class PlayerTable
  --- @field gui UrqGui
  global.players[player_index] = {}

  local gui = Gui.new(game.get_player(player_index), global.players[player_index])
  gui:update()
end

event.on_init(function()
  on_tick_n.init()

  --- @type table<uint, ForceTable>
  global.forces = {}
  --- @type table<uint, PlayerTable>
  global.players = {}

  -- game.forces is apparently keyed by name, not index
  for _, force in pairs(game.forces) do
    init_force(force)
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

event.register({ defines.events.on_research_finished, defines.events.on_research_reversed }, function(e)
  local force_index = e.research.force.index
  local force_table = global.forces[force_index]
  if not force_table.sort_techs_job then
    force_table.sort_techs_job = on_tick_n.add(game.tick + 1, { id = "sort_techs", force = force_index })
  end
end)

event.on_tick(function(e)
  for _, job in pairs(on_tick_n.retrieve(e.tick) or {}) do
    if job.id == "sort_techs" then
      --- @type LuaForce
      local force = game.forces[job.force]
      local force_table = global.forces[job.force]
      force_table.sort_techs_job = nil
      sort_techs(force, force_table)

      for _, player in pairs(force.players) do
        local player_table = global.players[player.index]
        if player_table and player_table.gui then
          player_table.gui:update()
        end
      end
    end
  end
end)
