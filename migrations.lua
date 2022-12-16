local cache = require("__UltimateResearchQueue__/cache")
local gui = require("__UltimateResearchQueue__/gui")
local research_queue = require("__UltimateResearchQueue__/research-queue")
local util = require("__UltimateResearchQueue__/util")

local migrations = {}

function migrations.generic()
  cache.build_dictionaries()
  cache.build_effect_icons()
  cache.sort_technologies()
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
  local force_table = {
    force = force,
    last_research_progress = 0,
    last_research_progress_tick = 0,
    research_speed = 0,
    --- @type table<string, ResearchState>
    research_states = {},
    --- @type table<ResearchState, table<uint, LuaTechnology>>
    technology_groups = {},
  }
  force_table.queue = research_queue.new(force, force_table)
  global.forces[force.index] = force_table
end

--- @param force LuaForce
function migrations.migrate_force(force)
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  cache.build_force_technologies(force)
  util.ensure_queue_disabled(force)
  research_queue.verify_integrity(force_table.queue)
end

--- @param player LuaPlayer
function migrations.migrate_player(player)
  gui.destroy(player.index)
  gui.new(player)
end

migrations.by_version = {}

return migrations
