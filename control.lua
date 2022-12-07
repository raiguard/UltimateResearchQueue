require("__UltimateResearchQueue__/debug")

local dictionary = require("__flib__/dictionary")
local migration = require("__flib__/migration")

local constants = require("__UltimateResearchQueue__/constants")
local cache = require("__UltimateResearchQueue__/cache")
local gui = require("__UltimateResearchQueue__/gui")
local migrations = require("__UltimateResearchQueue__/migrations")
local util = require("__UltimateResearchQueue__/util")

local function build_dictionaries()
  dictionary.init()
  -- Each technology should be searchable by its name and the names of recipes it unlocks
  local recipes = dictionary.new("recipe")
  for name, recipe in pairs(game.recipe_prototypes) do
    recipes:add(name, recipe.localised_name)
  end
  local techs = dictionary.new("technology")
  for name, technology in pairs(game.technology_prototypes) do
    techs:add(name, technology.localised_name)
  end
end

script.on_init(function()
  build_dictionaries()
  cache.build_effect_icons()
  cache.build_technology_list()

  --- @type table<uint, integer>
  global.filter_tech_list = {}
  --- @type table<uint, ForceTable>
  global.forces = {}
  --- @type table<uint, PlayerTable>
  global.players = {}
  --- @type table<uint, boolean>
  global.update_force_guis = {}

  -- game.forces is apparently keyed by name, not index
  for _, force in pairs(game.forces) do
    migrations.init_force(force)
    migrations.migrate_force(force)
  end
  for _, player in pairs(game.players) do
    migrations.init_player(player.index)
    migrations.migrate_player(player)
  end
end)

script.on_load(dictionary.load)

script.on_configuration_changed(function(e)
  if migration.on_config_changed(migrations.by_version, e) then
    build_dictionaries()
    cache.build_effect_icons()
    cache.build_technology_list()
    for _, force in pairs(game.forces) do
      migrations.migrate_force(force)
    end
    for _, player in pairs(game.players) do
      migrations.migrate_player(player)
    end
  end
end)

script.on_event(defines.events.on_force_created, function(e)
  migrations.init_force(e.force)
  migrations.migrate_force(e.force)
end)

script.on_event(defines.events.on_player_created, function(e)
  migrations.init_player(e.player_index)
  migrations.migrate_player(game.get_player(e.player_index) --[[@as LuaPlayer]])
end)

script.on_event(defines.events.on_player_joined_game, function(e)
  dictionary.translate(game.get_player(e.player_index) --[[@as LuaPlayer]])
end)

script.on_event(defines.events.on_player_left_game, function(e)
  dictionary.cancel_translation(e.player_index)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting ~= "urq-show-disabled-techs" then
    return
  end
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local gui = util.get_gui(player)
  if gui then
    gui:filter_tech_list()
  end
end)

script.on_event({
  defines.events.on_player_toggled_map_editor,
  defines.events.on_player_cheat_mode_enabled,
  defines.events.on_player_cheat_mode_disabled,
}, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local gui = util.get_gui(player)
  if gui then
    gui:update_tech_info_footer()
  end
end)

gui.handle_events()

if not DEBUG then
  script.on_event(defines.events.on_gui_opened, function(e)
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    if player.opened_gui_type == defines.gui_type.research then
      local gui = util.get_gui(player)
      if gui and not gui.state.opening_graph then
        local opened = player.opened --[[@as LuaTechnology?]]
        player.opened = nil
        gui:show(opened and opened.name or nil)
      end
    end
  end)
end

script.on_event(defines.events.on_gui_closed, function(e)
  if not gui.dispatch(e) and e.gui_type == defines.gui_type.research then
    local gui = util.get_gui(e.player_index)
    if gui and gui.elems.urq_window.visible and not gui.state.pinned then
      gui.player.opened = gui.elems.urq_window
    end
  end
end)

script.on_event("urq-focus-search", function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local gui = util.get_gui(player)
  if gui and player.opened == gui.elems.urq_window then
    gui:toggle_search()
  end
end)

script.on_event("urq-toggle-gui", function(e)
  local gui = util.get_gui(e.player_index)
  if gui then
    gui:toggle_visible()
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name == "urq-toggle-gui" then
    local gui = util.get_gui(e.player_index)
    if gui then
      gui:toggle_visible()
    end
  end
end)

script.on_event(defines.events.on_research_started, function(e)
  local technology = e.research
  local force = technology.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)

  local queue = force_table.queue
  if next(queue.queue) ~= technology.name then
    queue:push_front({ technology.name })
  end
end)

script.on_event(defines.events.on_research_cancelled, function(e)
  local force = e.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)

  local queue = force_table.queue
  if queue.paused then
    return
  end
  for tech_name in pairs(e.research) do
    queue:remove(tech_name)
  end
end)

script.on_event(defines.events.on_research_finished, function(e)
  local technology = e.research
  local force = technology.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)
  if force_table.queue:contains(technology.name) then
    force_table.queue:remove(technology.name)
  else
    -- This was insta-researched
    util.update_research_state_reqs(force_table, technology)
    util.schedule_gui_update(force_table)
  end
  for _, player in pairs(force.players) do
    if player.mod_settings["urq-print-completed-message"].value then
      player.print({ "message.urq-research-completed", technology.name })
    end
  end
end)

script.on_event(defines.events.on_research_reversed, function(e)
  local technology = e.research
  local force = technology.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)
  util.update_research_state_reqs(force_table, e.research)
  util.schedule_gui_update(force_table)
end)

script.on_event(constants.on_research_queue_updated, function(e)
  util.schedule_gui_update(global.forces[e.force.index])
end)

script.on_event(defines.events.on_string_translated, function(e)
  local result = dictionary.process_translation(e)
  if result then
    for _, player_index in pairs(result.players) do
      local player_table = global.players[player_index]
      if player_table then
        player_table.dictionaries = result.dictionaries
      end
    end
  end
end)

script.on_event(defines.events.on_tick, function(e)
  dictionary.check_skipped()
  if next(global.update_force_guis) then
    for force_index in pairs(global.update_force_guis) do
      -- TODO: Update each player's GUI on a separate tick?
      local force = game.forces[force_index]
      util.update_force_guis(force)
    end
    global.update_force_guis = {}
  end
  for player_index, tick in pairs(global.filter_tech_list) do
    if tick <= e.tick then
      local player = game.get_player(player_index) --[[@as LuaPlayer]]
      local gui = util.get_gui(player)
      if gui and gui.elems.urq_window.visible then
        gui:filter_tech_list()
      end
      global.filter_tech_list[player_index] = nil
    end
  end
end)

script.on_nth_tick(60, function()
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
