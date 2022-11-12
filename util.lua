local gui = require("__flib__.gui")
local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("__UltimateResearchQueue__.constants")

local util = {}

--- @param tech LuaTechnology
--- @param queue Queue?
function util.are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not queue.queue[name] then
        return false
      end
    end
  end
  return true
end

--- Ensure that the vanilla research queue is disabled
--- @param force LuaForce
function util.ensure_queue_disabled(force)
  if force.research_queue_enabled then
    force.print({ "message.urq-vanilla-queue-disabled" })
    force.research_queue_enabled = false
  end
end

--- @param player LuaPlayer
--- @param text LocalisedString
function util.flying_text(player, text)
  player.create_local_flying_text({
    text = text,
    create_at_cursor = true,
  })
  player.play_sound({ path = "utility/cannot_build" })
end

--- @param ticks number
--- @return LocalisedString
function util.format_time_short(ticks)
  if ticks == 0 then
    return { "time-symbol-seconds-short", 0 }
  end

  local hours = math.floor(ticks / 60 / 60 / 60)
  local minutes = math.floor(ticks / 60 / 60) % 60
  local seconds = math.floor(ticks / 60) % 60
  local result = { "" }
  if hours ~= 0 then
    table.insert(result, { "time-symbol-hours-short", hours })
  end
  if minutes ~= 0 then
    table.insert(result, { "time-symbol-minutes-short", minutes })
  end
  if seconds ~= 0 then
    table.insert(result, { "time-symbol-seconds-short", seconds })
  end
  return result
end

--- @param player LuaPlayer|uint
--- @return Gui?
function util.get_gui(player)
  if type(player) == "table" then
    player = player.index
  end
  --- @type PlayerTable?
  local player_table = global.players[player]
  if player_table then
    local gui = player_table.gui
    if gui then
      if not gui.elems.urq_window.valid then
        gui:destroy()
        gui = gui.new(gui.player, gui.player_table)
        gui.player.print({ "message.urq-recreated-gui" })
      end
      return gui
    end
  end
end

--- @param tech LuaTechnology
--- @return double
function util.get_research_progress(tech)
  local force = tech.force
  local current_research = force.current_research
  if current_research and current_research.name == tech.name then
    return force.research_progress
    -- TODO: Handle infinite researches
  else
    return force.get_saved_technology_progress(tech) or 0
  end
end

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return ResearchState
function util.get_research_state(force_table, tech)
  if tech.researched then
    return constants.research_state.researched
  end
  if not tech.enabled then
    return constants.research_state.disabled
  end
  if util.are_prereqs_satisfied(tech) then
    return constants.research_state.available
  end
  if util.are_prereqs_satisfied(tech, force_table.queue) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
end

--- @param tech LuaTechnology
--- @return double
function util.get_research_unit_count(tech)
  local formula = tech.research_unit_count_formula
  if formula then
    local level = tech.level --[[@as double]]
    return game.evaluate_expression(formula, { l = level, L = level })
  else
    return tech.research_unit_count --[[@as double]]
  end
end

--- @param force_table ForceTable
function util.schedule_gui_update(force_table)
  if game.tick_paused then
    util.update_force_guis(force_table.force)
  else
    global.update_force_guis[force_table.force.index] = true
  end
end

--- @param technology LuaTechnology
--- @param research_state ResearchState
--- @param selected_name string?
function util.get_technology_slot_properties(technology, research_state, selected_name)
  local selected = selected_name == technology.name
  local max_level = technology.prototype.max_level
  local ranged = technology.prototype.level ~= max_level
  local leveled = technology.upgrade or technology.level > 1 or ranged

  local research_state_str = table.find(constants.research_state, research_state)
  local max_level_str = max_level == math.max_uint and "[img=infinity]" or tostring(max_level)
  local style = "urq_technology_slot_"
    .. (selected and "selected_" or "")
    .. (leveled and "leveled_" or "")
    .. research_state_str
  local unselected_style = "urq_technology_slot_" .. (leveled and "leveled_" or "") .. research_state_str

  return {
    leveled = leveled,
    max_level = max_level,
    max_level_str = max_level_str,
    research_state_str = research_state_str,
    selected = selected,
    style = style,
    unselected_style = unselected_style,
  }
end

--- Get all unreearched prerequisites. Note that the table is returned in reverse order and must be iterated in
--- reverse.
--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return string[]
function util.get_unresearched_prerequisites(force_table, tech)
  local research_states = force_table.research_states
  local to_research = {}
  for prerequisite_name, prerequisite in pairs(global.technology_prerequisites[tech.name]) do
    if
      research_states[prerequisite.name] ~= constants.research_state.researched
      and not force_table.queue[prerequisite_name]
    then
      table.insert(to_research, prerequisite_name)
    end
  end
  table.insert(to_research, tech.name)
  return to_research
end

--- @param player LuaPlayer
function util.is_cheating(player)
  return player.cheat_mode or player.controller_type == defines.controllers.editor
end

--- @param elem LuaGuiElement
function util.is_double_click(elem)
  local tags = gui.get_tags(elem)
  local last_click_tick = tags.last_click_tick or 0
  local is_double_click = game.ticks_played - last_click_tick < 12
  if is_double_click then
    tags.last_click_tick = nil
  else
    tags.last_click_tick = game.ticks_played
  end
  gui.set_tags(elem, tags)
  return is_double_click
end

--- @param element LuaGuiElement
--- @param parent LuaGuiElement
--- @param index number
function util.move_to(element, parent, index)
  --- @cast index uint
  local dummy = parent.add({ type = "empty-widget", index = index })
  parent.swap_children(element.get_index_in_parent(), index)
  dummy.destroy()
end

--- @param force LuaForce
function util.update_force_guis(force)
  for _, player in pairs(force.players) do
    local gui = util.get_gui(player)
    if gui then
      gui:update_queue()
      gui:update_tech_info_footer()
      gui:update_tech_list()
      gui:filter_tech_list()
    end
  end
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
--- @return boolean? updated
function util.update_research_state(force_table, technology)
  local order = global.technology_order[technology.name]
  local grouped_techs = force_table.grouped_technologies
  local previous_state = force_table.research_states[technology.name]
  local new_state = util.get_research_state(force_table, technology)
  if new_state ~= previous_state then
    grouped_techs[previous_state][order] = nil
    grouped_techs[new_state][order] = technology
    force_table.research_states[technology.name] = new_state
    return true
  end
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
function util.update_research_state_reqs(force_table, technology)
  util.update_research_state(force_table, technology)
  local requisites = global.technology_requisites[technology.name]
  if requisites then
    local technologies = technology.force.technologies
    for requisite_name in pairs(requisites) do
      util.update_research_state(force_table, technologies[requisite_name])
    end
  end
end

--- @param button LuaGuiElement
--- @param technology LuaTechnology
--- @param research_state ResearchState
--- @param selected_tech string?
--- @param in_queue boolean
function util.update_tech_slot_style(button, technology, research_state, selected_tech, in_queue)
  local tags = gui.get_tags(button)
  if tags.research_state ~= research_state then
    local properties = util.get_technology_slot_properties(technology, research_state, selected_tech)
    button.style = properties.style
    if research_state == constants.research_state.researched then
      button.progressbar.visible = false
      button.progressbar.value = 0
    end
    if properties.leveled then
      button.level_label.style = "urq_technology_slot_level_label_" .. properties.research_state_str
    end
    if properties.ranged then
      button.level_range_label.style = "urq_technology_slot_level_range_label_" .. properties.research_state_str
    end
    tags.research_state = research_state
    gui.set_tags(button, tags)
  end
  local duration_label = button.duration_label --[[@as LuaGuiElement]]
  if in_queue and not duration_label.visible then
    duration_label.visible = true
  elseif not in_queue and duration_label.visible then
    duration_label.visible = false
  end
end

return util
