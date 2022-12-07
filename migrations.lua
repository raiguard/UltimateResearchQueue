local dictionary = require("__flib__/dictionary")

local cache = require("__UltimateResearchQueue__/cache")
local gui = require("__UltimateResearchQueue__/gui")
local queue = require("__UltimateResearchQueue__/queue")
local util = require("__UltimateResearchQueue__/util")

local migrations = {}

--- @param force LuaForce
function migrations.init_force(force)
  --- @class ForceTable
  --- @field queue Queue
  local force_table = {
    force = force,
    --- @type table<ResearchState, LuaTechnology[]>
    grouped_technologies = {},
    --- @type ProgressSample[]
    research_progress_samples = {},
    --- @type table<string, ResearchState>
    research_states = {},
    --- @type table<string, number>
    upgrade_states = {},
  }
  force_table.queue = queue.new(force, force_table)
  global.forces[force.index] = force_table
end

--- @param player_index uint
function migrations.init_player(player_index)
  --- @class PlayerTable
  --- @field gui Gui?
  --- @field dictionaries table<string, table<string, string>>?
  global.players[player_index] = {}
end

--- @param force LuaForce
function migrations.migrate_force(force)
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  cache.build_research_states(force)
  util.ensure_queue_disabled(force)
  force_table.queue:verify_integrity()
end

--- @param player LuaPlayer
function migrations.migrate_player(player)
  local player_table = global.players[player.index]
  if not player_table then
    return
  end
  if player_table.gui then
    player_table.gui:destroy()
  end
  player_table.dictionaries = nil
  gui.new(player, player_table)
  if player.connected then
    dictionary.translate(player)
  end
end

migrations.by_version = {}

return migrations
