require("__UltimateResearchQueue__/debug")

local dictionary = require("__flib__/dictionary-lite")
local migration = require("__flib__/migration")

local gui = require("__UltimateResearchQueue__/gui")
local migrations = require("__UltimateResearchQueue__/migrations")
local research_queue = require("__UltimateResearchQueue__/research-queue")
local util = require("__UltimateResearchQueue__/util")

-- Bootstrap

script.on_init(function()
  --- @type table<uint, integer>
  global.filter_tech_list = {}
  --- @type table<uint, ForceTable>
  global.forces = {}
  --- @type table<uint, Gui>
  global.guis = {}
  --- @type table<uint, boolean>
  global.update_force_guis = {}

  -- game.forces is apparently keyed by name, not index
  for _, force in pairs(game.forces) do
    migrations.init_force(force)
  end
  migrations.generic()
end)

migration.handle_on_configuration_changed(nil, migrations.generic)

-- Dictionaries

dictionary.handle_events()

-- Force and Player

script.on_event(defines.events.on_force_created, function(e)
  migrations.init_force(e.force)
  migrations.migrate_force(e.force)
end)

script.on_event(defines.events.on_player_created, function(e)
  migrations.migrate_player(game.get_player(e.player_index) --[[@as LuaPlayer]])
end)

script.on_event({
  defines.events.on_player_toggled_map_editor,
  defines.events.on_player_cheat_mode_enabled,
  defines.events.on_player_cheat_mode_disabled,
}, function(e)
  local player_gui = gui.get(e.player_index)
  if player_gui then
    gui.update_tech_info_footer(player_gui)
  end
end)

-- Gui

gui.handle_events()

if not DEBUG then
  script.on_event(defines.events.on_gui_opened, function(e)
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    if player.opened_gui_type == defines.gui_type.research then
      local player_gui = gui.get(e.player_index)
      if player_gui and not player_gui.state.opening_graph then
        local opened = player.opened --[[@as LuaTechnology?]]
        player.opened = nil
        gui.show(player_gui, opened and opened.name or nil)
      end
    end
  end)
end

script.on_event(defines.events.on_gui_closed, function(e)
  if not gui.dispatch(e) and e.gui_type == defines.gui_type.research then
    local player_gui = gui.get(e.player_index)
    if player_gui and player_gui.elems.urq_window.visible and not player_gui.state.pinned then
      player_gui.player.opened = player_gui.elems.urq_window
    end
  end
end)

script.on_event("urq-focus-search", function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local player_gui = gui.get(e.player_index)
  if player_gui and player.opened == player_gui.elems.urq_window then
    gui.toggle_search(player_gui)
  end
end)

script.on_event("urq-toggle-gui", function(e)
  local player_gui = gui.get(e.player_index)
  if player_gui then
    gui.toggle_visible(player_gui)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name == "urq-toggle-gui" then
    local player_gui = gui.get(e.player_index)
    if player_gui then
      gui.toggle_visible(player_gui)
    end
  end
end)

-- Research

script.on_event(defines.events.on_research_started, function(e)
  local technology = e.research
  local force = technology.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)

  local level = technology.level
  if research_queue.contains(force_table.queue, technology, level) then
    if force_table.queue.head.technology == technology then
      return
    end
    research_queue.remove(force_table.queue, technology, level)
  end
  research_queue.push(force_table.queue, technology, level)
  gui.schedule_update(force_table)
end)

script.on_event(defines.events.on_research_cancelled, function(e)
  local force = e.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)

  local force_queue = force_table.queue
  if force_queue.paused then
    return
  end
  local technologies = force.technologies
  for tech_name in pairs(e.research) do
    local technology = technologies[tech_name]
    research_queue.remove(force_queue, technology, technology.level)
  end
  gui.schedule_update(force_table)
end)

script.on_event(defines.events.on_research_finished, function(e)
  local technology = e.research
  local force = technology.force
  local force_table = global.forces[force.index]
  if not force_table then
    return
  end
  util.ensure_queue_disabled(force)
  local level = technology.level
  -- For multi-level techs, we want to remove the level that was just finished, not the new level
  if util.is_multilevel(technology) then
    level = level - 1
  end
  if research_queue.contains(force_table.queue, technology, level) then
    research_queue.remove(force_table.queue, technology, level)
  else
    -- This was insta-researched
    research_queue.update_research_state_reqs(force_table, technology)
  end
  gui.schedule_update(force_table)
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
  research_queue.update_research_state_reqs(force_table, technology)
  gui.schedule_update(force_table)
end)

-- Settings

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting ~= "urq-show-disabled-techs" then
    return
  end
  local player_gui = gui.get(e.player_index)
  if player_gui then
    gui.filter_tech_list(player_gui)
  end
end)

-- Tick

script.on_event(defines.events.on_tick, function(e)
  dictionary.on_tick()
  if next(global.update_force_guis) then
    for force_index in pairs(global.update_force_guis) do
      -- TODO: Update each player's GUI on a separate tick?
      local force = game.forces[force_index]
      gui.update_force(force)
    end
    global.update_force_guis = {}
  end
  for player_index, tick in pairs(global.filter_tech_list) do
    if tick <= e.tick then
      local player_gui = gui.get(player_index)
      if player_gui and player_gui.elems.urq_window.visible then
        gui.filter_tech_list(player_gui)
      end
      global.filter_tech_list[player_index] = nil
    end
  end
end)

--- @param force LuaForce
--- @param force_table ForceTable
--- @param current_research LuaTechnology
local function update_force_durations(force, force_table, current_research)
  local current_progress = force.research_progress
  local research_time = current_research.research_unit_energy * util.get_research_unit_count(current_research)

  local progress_delta = current_progress - force_table.last_research_progress
  local tick_delta = game.tick - force_table.last_research_progress_tick

  local normalized_speed = (progress_delta * research_time) / tick_delta

  force_table.last_research_progress = current_progress
  force_table.last_research_progress_tick = game.tick
  force_table.research_speed = normalized_speed

  research_queue.update_durations(force_table.queue)
  gui.update_force_progress(force)
end

script.on_nth_tick(60, function()
  for force_index, force_table in pairs(global.forces) do
    local force = game.forces[force_index]
    local current_research = force.current_research
    if current_research then
      update_force_durations(force, force_table, current_research)
    end
  end
end)
