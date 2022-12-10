local cache = require("__UltimateResearchQueue__/cache")
local gui = require("__UltimateResearchQueue__/gui")
local queue = require("__UltimateResearchQueue__/queue")
local util = require("__UltimateResearchQueue__/util")

local migrations = {}

function migrations.generic()
  cache.build_effect_icons()
  cache.build_dictionaries()
  cache.build_technology_list()
  for _, force in pairs(game.forces) do
    migrations.migrate_force(force)
  end
  for _, player in pairs(game.players) do
    migrations.migrate_player(player)
  end
end

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

--- @param force LuaForce
function migrations.migrate_force(force)
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  cache.build_research_states(force)
  util.ensure_queue_disabled(force)
  queue.verify_integrity(force_table.queue)
end

--- @param player LuaPlayer
function migrations.migrate_player(player)
  gui.destroy(player.index)
  gui.new(player)
end

migrations.by_version = {}

return migrations
