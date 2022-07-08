local event = require("__flib__.event")
local libgui = require("__flib__.gui")
local on_tick_n = require("__flib__.on-tick-n")

local gui = require("gui.index")
local sort_techs = require("sort-techs")

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

--- @param player_index uint
local function init_player(player_index)
  --- @class PlayerTable
  --- @field gui Gui
  global.players[player_index] = {}

  local gui = gui.new(game.get_player(player_index), global.players[player_index])
  gui:refresh_tech_list()
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

event.on_load(function()
  for _, player_table in pairs(global.players) do
    if player_table.gui then
      gui.load(player_table.gui)
    end
  end
end)

event.on_force_created(function(e)
  init_force(e.force)
end)

event.on_player_created(function(e)
  init_player(e.player_index)
end)

libgui.hook_events(function(e)
  local action = libgui.read_action(e)
  if action then
    --- @type PlayerTable
    local player_table = global.players[e.player_index]
    if player_table.gui then
      player_table.gui:dispatch(action, e)
    end
  end
end)

event.register("urq-focus-search", function(e)
  local player = game.get_player(e.player_index)
  if player.opened_gui_type == defines.gui_type.custom and player.opened and player.opened.name == "urq-window" then
    local player_table = global.players[e.player_index]
    if player_table and player_table.gui then
      player_table.gui:toggle_search()
    end
  end
end)

event.register("urq-toggle-gui", function(e)
  local player_table = global.players[e.player_index]
  if player_table and player_table.gui then
    player_table.gui:toggle_visible()
  end
end)

event.on_lua_shortcut(function(e)
  if e.prototype_name == "urq-toggle-gui" then
    local player_table = global.players[e.player_index]
    if player_table and player_table.gui then
      player_table.gui:toggle_visible()
    end
  end
end)

event.register({ defines.events.on_research_finished, defines.events.on_research_reversed }, function(e)
  local force_index = e.research.force.index
  local force_table = global.forces[force_index]
  if force_table and not force_table.sort_techs_job then
    force_table.sort_techs_job = on_tick_n.add(game.tick + 1, { id = "sort_techs", force = force_index })
  end
end)

event.on_tick(function(e)
  for _, job in pairs(on_tick_n.retrieve(e.tick) or {}) do
    if job.id == "sort_techs" then
      --- @type LuaForce
      local force = game.forces[job.force]
      local force_table = global.forces[job.force]
      if force_table then
        force_table.sort_techs_job = nil
        sort_techs(force, force_table)

        for _, player in pairs(force.players) do
          local player_table = global.players[player.index]
          if player_table and player_table.gui then
            player_table.gui:refresh_tech_list()
          end
        end
      end
    elseif job.id == "gui" then
      --- @type PlayerTable
      local player_table = global.players[job.player_index]
      if player_table and player_table.gui then
        player_table.gui:dispatch(job, e)
      end
    end
  end
end)
