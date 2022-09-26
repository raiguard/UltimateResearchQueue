require("__UltimateResearchQueue__.debug")

local dictionary = require("__flib__.dictionary")
local event = require("__flib__.event")
local libgui = require("__flib__.gui")
local migration = require("__flib__.migration")
local on_tick_n = require("__flib__.on-tick-n")

local gui = require("__UltimateResearchQueue__.gui.index")
local queue = require("__UltimateResearchQueue__.queue")
local util = require("__UltimateResearchQueue__.util")

local function build_dictionaries()
  dictionary.init()

  -- Each technology will be searchable by its name, and the names of the recipes it unlocks
  -- What could possibly go wrong here?
  local dict = dictionary.new("technology_search")
  for name, technology in pairs(game.technology_prototypes) do
    local ref = { "", technology.localised_name, " " }
    local str = { "", ref }
    for _, effect in pairs(technology.effects) do
      -- TODO: Search by all effects
      -- TODO: Prevent absurd amounts of nesting somehow
      if effect.type == "unlock-recipe" then
        local name = { "", game.recipe_prototypes[effect.recipe].localised_name, " " }
        table.insert(ref, name)
        ref = name
      end
    end
    dict:add(name, str)
  end
end

--- @param force LuaForce
local function init_force(force)
  --- @class ForceTable
  --- @field queue Queue
  local force_table = {
    --- @type ProgressSample[]
    research_progress_samples = {},
    --- @type table<string, ToShow>
    technologies = {},
  }
  force_table.queue = queue.new(force, force_table)
  global.forces[force.index] = force_table
end

--- @param force LuaForce
local function migrate_force(force)
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)
  force_table.queue:verify_integrity()
  util.sort_techs(force, force_table)
end

--- @param player_index uint
local function init_player(player_index)
  --- @class PlayerTable
  --- @field gui Gui?
  --- @field dictionaries table<string, table<string, string>>?
  global.players[player_index] = {}
end

--- @param player LuaPlayer
local function migrate_player(player)
  local player_table = global.players[player.index]
  if not player_table then
    return
  end
  if player_table.gui then
    player_table.gui:destroy()
  end
  player_table.dictionaries = nil
  local gui = gui.new(player, player_table)
  gui:refresh()
  if player.connected then
    dictionary.translate(player)
  end
end

event.on_init(function()
  build_dictionaries()
  util.build_effect_icons()
  on_tick_n.init()

  --- @type table<uint, ForceTable>
  global.forces = {}
  --- @type table<uint, PlayerTable>
  global.players = {}

  -- game.forces is apparently keyed by name, not index
  for _, force in pairs(game.forces) do
    init_force(force)
    migrate_force(force)
  end
  for _, player in pairs(game.players) do
    init_player(player.index)
    migrate_player(player)
  end
end)

event.on_load(function()
  dictionary.load()
  for _, force_table in pairs(global.forces) do
    queue.load(force_table.queue)
  end
  for _, player_table in pairs(global.players) do
    if player_table.gui then
      gui.load(player_table.gui)
    end
  end
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed({}, e) then
    build_dictionaries()
    util.build_effect_icons()
    for _, force in pairs(game.forces) do
      migrate_force(force)
    end
    for _, player in pairs(game.players) do
      migrate_player(player)
    end
  end
end)

event.on_force_created(function(e)
  init_force(e.force)
  migrate_force(e.force)
end)

event.on_player_created(function(e)
  init_player(e.player_index)
  migrate_player(
    game.get_player(e.player_index) --[[@as LuaPlayer]]
  )
end)

event.on_player_joined_game(function(e)
  dictionary.translate(
    game.get_player(e.player_index) --[[@as LuaPlayer]]
  )
end)

event.on_player_left_game(function(e)
  dictionary.cancel_translation(e.player_index)
end)

libgui.hook_events(function(e)
  local action = libgui.read_action(e)
  if action then
    local gui = util.get_gui(e.player_index)
    if gui then
      gui:dispatch(action, e)
    end
  end
end)

if not DEBUG then
  event.on_gui_opened(function(e)
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    if player.opened_gui_type == defines.gui_type.research then
      local gui = util.get_gui(player)
      if gui then
        local opened = player.opened --[[@as LuaTechnology?]]
        player.opened = nil
        gui:show(opened and opened.name or nil)
      end
    end
  end)
end

event.register("urq-focus-search", function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  if player.opened_gui_type == defines.gui_type.custom and player.opened and player.opened.name == "urq-window" then
    local gui = util.get_gui(player)
    if gui then
      gui:toggle_search()
    end
  end
end)

event.register("urq-toggle-gui", function(e)
  local gui = util.get_gui(e.player_index)
  if gui then
    gui:toggle_visible()
  end
end)

event.on_lua_shortcut(function(e)
  if e.prototype_name == "urq-toggle-gui" then
    local gui = util.get_gui(e.player_index)
    if gui then
      gui:toggle_visible()
    end
  end
end)

event.register({
  defines.events.on_research_started,
  defines.events.on_research_cancelled,
  defines.events.on_research_finished,
  defines.events.on_research_reversed,
  util.research_queue_updated_event,
}, function(e)
  local force
  if e.name == defines.events.on_research_cancelled or e.name == util.research_queue_updated_event then
    force = e.force
  else
    force = e.research.force
  end
  util.ensure_queue_disabled(force)
  local force_table = global.forces[force.index]
  if force_table then
    if game.tick_paused then
      -- TODO: This doesn't perform any of the other logic
      util.sort_techs(force, force_table)
    else
      -- Always use the newest version of events
      if force_table.sort_techs_job then
        on_tick_n.remove(force_table.sort_techs_job)
      end
      force_table.sort_techs_job = on_tick_n.add(
        game.tick + 1,
        { id = "sort_techs", force = force.index, update_queue = e.name == defines.events.on_research_finished }
      )
    end
  end
end)

event.on_string_translated(function(e)
  local result = dictionary.process_translation(e)
  if result then
    for _, player_index in pairs(result.players) do
      local player_table = global.players[player_index]
      if player_table then
        player_table.dictionaries = result.dictionaries
        -- TODO: Assemble search strings for each tech
      end
    end
  end
end)

event.on_tick(function(e)
  dictionary.check_skipped()
  for _, job in pairs(on_tick_n.retrieve(e.tick) or {}) do
    if job.id == "sort_techs" then
      --- @type LuaForce
      local force = game.forces[job.force]
      local force_table = global.forces[job.force]
      if force_table then
        force_table.sort_techs_job = nil
        util.sort_techs(force, force_table)
        if job.update_queue then
          force_table.queue:update()
        end

        for _, player in pairs(force.players) do
          local gui = util.get_gui(player)
          if gui and gui.refs.window.visible then
            gui:refresh()
          end
        end
      end
    elseif job.id == "gui" then
      local gui = util.get_gui(job.player_index)
      if gui then
        gui:dispatch(job, e)
      end
    end
  end
end)

event.on_nth_tick(60, function()
  for force_index, force_table in pairs(global.forces) do
    local force = game.forces[force_index]
    local current = force.current_research
    if current then
      local samples = force_table.research_progress_samples
      --- @class ProgressSample
      local sample = { progress = force.research_progress, tech = current.name }
      table.insert(samples, sample)
      if #samples > 3 then
        table.remove(samples, 1)
      end

      local speed = 0
      local num_samples = 0
      if #samples > 1 then
        for i = 2, #samples do
          local previous_sample = samples[i - 1]
          local current_sample = samples[i]
          if previous_sample.tech == current_sample.tech then
            -- How much the progress increased per tick
            local diff = (current_sample.progress - previous_sample.progress) / 60
            -- Don't add if the speed is negative for whatever reason
            if diff > 0 then
              speed = speed + diff * util.get_research_unit_count(current) * current.research_unit_energy
              num_samples = num_samples + 1
            end
          end
        end
        -- Rolling average
        if num_samples > 0 then
          speed = speed / num_samples
        end
      end

      force_table.queue:update_durations(speed)

      for _, player in pairs(force.players) do
        local gui = util.get_gui(player)
        if gui then
          gui:update_durations_and_progress()
        end
      end
    end
  end
end)
