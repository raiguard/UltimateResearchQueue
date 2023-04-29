local gui = require("__UltimateResearchQueue__/scripts/gui")
local research_queue = require("__UltimateResearchQueue__/scripts/research-queue")
local util = require("__UltimateResearchQueue__/scripts/util")

--- @class Migrations
local migrations = {}

function migrations.generic()
  for _, force in pairs(game.forces) do
    migrations.migrate_force(force)
  end
  for _, player in pairs(game.players) do
    migrations.migrate_player(player)
  end
end

--- @param force LuaForce
function migrations.migrate_force(force)
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)
  research_queue.verify_integrity(force_table.queue)
end

--- @param player LuaPlayer
function migrations.migrate_player(player)
  gui.new(player)
end

migrations.by_version = {}

return migrations
