local dictionary = require("__flib__/dictionary-lite")
local format = require("__flib__/format")
local flib_gui = require("__flib__/gui-lite")
local math = require("__flib__/math")
local table = require("__flib__/table")

local constants = require("__UltimateResearchQueue__/constants")
local gui_util = require("__UltimateResearchQueue__/gui-util")
local research_queue = require("__UltimateResearchQueue__/research-queue")
local util = require("__UltimateResearchQueue__/util")

--- @class TechnologyAndLevel
--- @field technology LuaTechnology
--- @field level uint

--- @class GuiElems
--- @field urq_window LuaGuiElement
--- @field titlebar_flow LuaGuiElement
--- @field search_button LuaGuiElement
--- @field search_textfield LuaGuiElement
--- @field pin_button LuaGuiElement
--- @field close_button LuaGuiElement
--- @field techs_scroll_pane LuaGuiElement
--- @field techs_table LuaGuiElement
--- @field queue_population_label LuaGuiElement
--- @field queue_requeue_multilevel_button LuaGuiElement
--- @field queue_pause_button LuaGuiElement
--- @field queue_trash_button LuaGuiElement
--- @field queue_scroll_pane LuaGuiElement
--- @field queue_table LuaGuiElement
--- @field tech_info_tutorial_flow LuaGuiElement
--- @field tech_info_name_label LuaGuiElement
--- @field tech_info_main_slot_frame LuaGuiElement
--- @field tech_info_description_label LuaGuiElement
--- @field tech_info_ingredients_table LuaGuiElement
--- @field tech_info_ingredients_count_label LuaGuiElement
--- @field tech_info_ingredients_time_label LuaGuiElement
--- @field tech_info_effects_table LuaGuiElement
--- @field tech_info_prerequisites_table LuaGuiElement
--- @field tech_info_requisites_table LuaGuiElement
--- @field tech_info_upgrade_group_table LuaGuiElement
--- @field tech_info_footer_frame LuaGuiElement
--- @field tech_info_footer_progressbar LuaGuiElement
--- @field tech_info_footer_pusher LuaGuiElement
--- @field tech_info_footer_cancel_button LuaGuiElement
--- @field tech_info_footer_start_button LuaGuiElement
--- @field tech_info_footer_unresearch_button LuaGuiElement

--- @class GuiMod
local gui = {}

--- @param self Gui
--- @param e EventData.on_gui_click
function gui.cancel_research(self, e)
  local tags = e.element.tags
  local tech_name, level = tags.tech_name --[[@as string]], tags.level --[[@as uint]]
  local technology = self.force.technologies[tech_name]
  research_queue.remove(self.force_table.queue, technology, level)
  gui.schedule_update(self.force_table)
end

--- @param self Gui
function gui.cancel_selected_research(self)
  local selected = self.state.selected
  if not selected then
    return
  end
  research_queue.remove(self.force_table.queue, selected.technology, selected.level)
  gui.schedule_update(self.force_table)
end

--- @param self Gui
function gui.clear_queue(self)
  research_queue.clear(self.force_table.queue)
  gui.schedule_update(self.force_table)
end

--- @param force_table ForceTable
--- @param technology LuaTechnology
--- @param upgrade_group LuaTechnologyPrototype[]
local function check_upgrade_group(force_table, technology, upgrade_group)
  local research_states = force_table.research_states
  local technologies = force_table.force.technologies
  if research_states[technology.name] == constants.research_state.researched then
    -- Show if highest researched
    for i = #upgrade_group, 1, -1 do
      local other_tech = technologies[upgrade_group[i].name]
      if research_states[other_tech.name] == constants.research_state.researched then
        return other_tech == technology
      end
    end
  else
    -- Show if lowest unresearched
    for i = 1, #upgrade_group do
      local other_tech = technologies[upgrade_group[i].name]
      if research_states[other_tech.name] ~= constants.research_state.researched then
        return other_tech == technology
      end
    end
  end
end

--- @param self Gui
-- Updates tech list button visibility based on search query and other settings
function gui.filter_tech_list(self)
  local query = self.state.search_query
  local dictionaries = dictionary.get_all(self.player.index)
  local technologies = self.force.technologies
  local research_states = self.force_table.research_states
  local show_disabled = self.player.mod_settings["urq-show-disabled-techs"].value
  for _, button in pairs(self.elems.techs_table.children) do
    local technology_name = button.name
    local technology = technologies[technology_name]
    local research_state = research_states[technology_name]
    -- Show/hide disabled
    local research_state_matched = true
    if research_state == constants.research_state.disabled and not show_disabled then
      research_state_matched = false
    end
    -- Show/hide upgrade techs
    local upgrade_matched = true
    if technology.upgrade and research_state ~= constants.research_state.conditionally_available then
      upgrade_matched = check_upgrade_group(
        self.force_table,
        technology,
        global.technology_upgrade_groups[util.get_base_name(technology)]
      )
    end
    -- Search query
    local search_matched = #query == 0 -- Automatically pass search on empty query
    if research_state_matched and not search_matched then
      local to_search = {}
      if dictionaries then
        table.insert(to_search, dictionaries.technology[technology_name])
        for _, effect in pairs(technology.effects) do
          if effect.type == "unlock-recipe" then
            table.insert(to_search, dictionaries.recipe[effect.recipe])
          end
        end
      else
        table.insert(to_search, technology_name)
      end
      for _, str in pairs(to_search) do
        if string.find(string.lower(str), query, 1, true) then
          search_matched = true
          break
        end
      end
    end
    button.visible = research_state_matched and upgrade_matched and search_matched
  end
end

--- @param self Gui
function gui.hide(self)
  if self.state.opening_graph then
    return
  end
  if self.player.opened_gui_type == defines.gui_type.custom and self.player.opened == self.elems.urq_window then
    self.player.opened = nil
  end
  self.elems.urq_window.visible = false
end

--- @param self Gui
--- @param e EventData.on_gui_click
function gui.on_start_research_click(self, e)
  local selected = self.state.selected
  if not selected then
    return
  end
  gui.start_research(self, selected.technology, selected.level, e.shift, e.control and util.is_cheating(self.player))
end

--- @param self Gui
--- @param e EventData.on_gui_click
function gui.on_tech_slot_click(self, e)
  if DEBUG then
    log("tech clicked: " .. e.element.name)
  end
  local tags = e.element.tags
  local tech_name, level = tags.tech_name --[[@as string]], tags.level --[[@as uint]]
  local technology = self.force.technologies[tech_name]
  if e.button == defines.mouse_button_type.right then
    research_queue.remove(self.force_table.queue, technology, level)
    gui.schedule_update(self.force_table)
    return
  end
  if gui_util.is_double_click(e.element) then
    gui.start_research(self, technology, level, e.shift, e.control and util.is_cheating(self.player))
    return
  end
  gui.select_tech(self, technology, level)
end

--- @param self Gui
--- @param e EventData.on_gui_click
function gui.on_titlebar_click(self, e)
  if e.button == defines.mouse_button_type.middle then
    self.elems.urq_window.force_auto_center()
  end
end

--- @param self Gui
function gui.on_window_closed(self)
  if self.state.pinned then
    return
  end
  if self.state.search_open then
    gui.toggle_search(self)
    self.player.opened = self.elems.urq_window
    return
  end
  gui.hide(self)
end

--- @param self Gui
function gui.open_in_graph(self)
  local selected = self.state.selected
  if selected then
    self.state.opening_graph = true
    self.player.open_technology_gui(selected.technology)
    self.state.opening_graph = false
  end
end

--- @param self Gui
--- @param technology LuaTechnology
function gui.select_tech(self, technology, level)
  local former_selected = self.state.selected
  if former_selected and former_selected.technology == technology and former_selected.level == level then
    return
  end
  self.state.selected = { technology = technology, level = level }

  gui.update_queue(self)
  gui.update_tech_list(self)
  gui.update_tech_info(self)
end

--- @param self Gui
--- @param select_tech string?
function gui.show(self, select_tech)
  if select_tech then
    local select_data = self.force.technologies[select_tech]
    gui.select_tech(self, select_data)
  end
  self.elems.urq_window.visible = true
  self.elems.urq_window.bring_to_front()
  if not self.state.pinned then
    self.player.opened = self.elems.urq_window
  end
end

--- @param self Gui
--- @param technology LuaTechnology
--- @param level uint
--- @param to_front boolean?
--- @param instant_research boolean?
function gui.start_research(self, technology, level, to_front, instant_research)
  if instant_research then
    local prerequisites = global.technology_prerequisites[technology.name] or {}
    local technologies = self.force.technologies
    for i = 1, #prerequisites do
      local prerequisite = technologies[prerequisites[i]]
      if not prerequisite.researched then
        prerequisite.researched = true
      end
    end
    technology.researched = true
  else
    local push_error
    if to_front then
      push_error = research_queue.push_front(self.force_table.queue, technology, level)
    else
      push_error = research_queue.push(self.force_table.queue, technology, level)
    end
    if push_error then
      util.flying_text(self.player, push_error)
      return
    end
  end
  gui.schedule_update(self.force_table)
end

--- @param self Gui
function gui.toggle_pinned(self)
  self.state.pinned = not self.state.pinned
  gui_util.toggle_frame_action_button(self.elems.pin_button, "flib_pin", self.state.pinned)
  if self.state.pinned then
    self.player.opened = nil
    self.elems.search_button.tooltip = { "gui.search" }
    self.elems.close_button.tooltip = { "gui.close" }
  else
    self.player.opened = self.elems.urq_window
    self.elems.urq_window.force_auto_center()
    self.elems.search_button.tooltip = { "gui.urq-search-instruction" }
    self.elems.close_button.tooltip = { "gui.close-instruction" }
  end
end

--- @param self Gui
function gui.toggle_search(self)
  self.state.search_open = not self.state.search_open
  gui_util.toggle_frame_action_button(self.elems.search_button, "utility/search", self.state.search_open)
  self.elems.search_textfield.visible = self.state.search_open
  if self.state.search_open then
    self.elems.search_textfield.focus()
  else
    self.state.search_query = ""
    self.elems.search_textfield.text = ""
    gui.filter_tech_list(self)
  end
end

--- @param self Gui
function gui.toggle_queue_paused(self)
  research_queue.toggle_paused(self.force_table.queue)
  gui.schedule_update(self.force_table)
end

--- @param self Gui
function gui.toggle_queue_requeue_multilevel(self)
  research_queue.toggle_requeue_multilevel(self.force_table.queue)
  gui.schedule_update(self.force_table)
end

--- @param self Gui
function gui.toggle_visible(self)
  if self.elems.urq_window.visible then
    gui.hide(self)
  else
    gui.show(self)
  end
end

--- @param self Gui
function gui.unresearch(self)
  local selected = self.state.selected
  if not selected then
    return
  end
  local technologies = self.force.technologies
  local research_states = self.force_table.research_states

  --- @param technology LuaTechnology
  local function propagate(technology)
    local requisites = global.technology_requisites[technology.name]
    if requisites then
      for _, requisite_name in pairs(requisites) do
        local requisite_data = technologies[requisite_name]
        if research_states[requisite_name] == constants.research_state.researched then
          propagate(requisite_data)
        end
      end
    end
    technology.researched = false
  end

  propagate(selected.technology)
end

--- @param self Gui
function gui.update_durations_and_progress(self)
  local queue_table = self.elems.queue_table
  local techs_table = self.elems.techs_table
  local queue = self.force_table.queue
  local node = queue.head
  while node do
    local technology, level = node.technology, node.level
    local progress = math.floored(util.get_research_progress(technology, level), 0.01)
    local queue_button = queue_table[util.get_queue_key(technology, level)]
    if queue_button then
      queue_button.duration_label.caption = node.duration
      queue_button.progressbar.value = progress
      queue_button.progressbar.visible = progress > 0
    end
    local techs_button = techs_table[technology.name]
    if techs_button then
      techs_button.duration_label.caption = node.duration
      techs_button.progressbar.value = progress
      techs_button.progressbar.visible = progress > 0
    end
    node = node.next
  end
  gui.update_tech_info_footer(self, true)
end

--- @param self Gui
function gui.update_queue(self)
  local profiler = game.create_profiler()

  local queue = self.force_table.queue

  local requeue_multilevel = queue.requeue_multilevel
  local requeue_multilevel_button = self.elems.queue_requeue_multilevel_button
  if requeue_multilevel then
    requeue_multilevel_button.style = "flib_selected_tool_button"
  else
    requeue_multilevel_button.style = "tool_button"
  end

  local paused = queue.paused
  local pause_button = self.elems.queue_pause_button
  if paused then
    pause_button.style = "flib_selected_tool_button"
    pause_button.tooltip = { "gui.urq-resume-queue" }
  else
    pause_button.style = "tool_button"
    pause_button.tooltip = { "gui.urq-pause-queue" }
  end

  self.elems.queue_trash_button.enabled = queue.len > 0

  self.elems.queue_population_label.caption =
    { "gui.urq-queue-population", self.force_table.queue.len, constants.queue_limit }

  local selected = self.state.selected or {}

  local research_states = self.force_table.research_states

  local show_controls = self.player.mod_settings["urq-show-control-hints"].value --[[@as boolean]]

  local queue_table = self.elems.queue_table
  local i = 0
  local node = queue.head
  while node do
    i = i + 1
    local technology, level = node.technology, node.level
    local name = util.get_queue_key(technology, level)
    local button = queue_table[name]
    local is_selected = selected.technology == technology and selected.level == level
    if button then
      gui_util.move_to(button, queue_table, i)
      gui_util.update_tech_slot(
        button,
        technology,
        node.level,
        research_states[technology.name],
        research_queue.contains(queue, technology, level),
        is_selected
      )
    else
      local button_template = gui_util.technology_slot(
        gui.on_tech_slot_click,
        technology,
        level,
        research_states[technology.name],
        show_controls,
        is_selected
      )
      button_template.index = i
      button_template.name = util.get_queue_key(technology, level)
      flib_gui.add(queue_table, button_template)
    end
    node = node.next
  end
  local children = queue_table.children
  for i = i + 1, #children do
    children[i].destroy()
  end
  profiler.stop()
  if DEBUG then
    log({ "", "update_queue ", profiler })
  end
end

--- @param self Gui
function gui.update_search_query(self)
  self.state.search_query = self.elems.search_textfield.text

  if game.tick_paused or #self.state.search_query == 0 then
    global.filter_tech_list[self.player.index] = nil
    gui.filter_tech_list(self)
  else
    global.filter_tech_list[self.player.index] = game.tick + 30
  end
end

--- @param self Gui
function gui.update_tech_info(self)
  local selected = self.state.selected
  if not selected then
    return
  end
  local technology, level = selected.technology, selected.level

  -- Slot
  local main_slot_frame = self.elems.tech_info_main_slot_frame
  main_slot_frame.clear() -- The best thing to do is clear it, otherwise we'd need to diff all the sub-elements
  if technology then
    local button_template = gui_util.technology_slot(
      gui.on_tech_slot_click,
      technology,
      level,
      self.force_table.research_states[technology.name],
      self.player.mod_settings["urq-show-control-hints"].value --[[@as boolean]]
    )
    button_template.ignored_by_interaction = true
    button_template[5].visible = false
    button_template[6].visible = false
    flib_gui.add(main_slot_frame, button_template)
  end
  -- Name and description
  local caption = technology.localised_name
  if util.is_multilevel(technology) then
    caption = { "", caption, " ", level }
  end
  self.elems.tech_info_name_label.caption = caption
  self.elems.tech_info_description_label.caption = technology.localised_description
  -- Ingredients
  local ingredients_table = self.elems.tech_info_ingredients_table
  ingredients_table.clear()
  local ingredients_children = table.map(technology.research_unit_ingredients, function(ingredient)
    local prototype = game.item_prototypes[ingredient.name]
    return {
      type = "sprite-button",
      style = "transparent_slot",
      sprite = "item/" .. ingredient.name,
      number = ingredient.amount,
      tooltip = {
        "",
        { "gui.urq-tooltip-title", { "?", prototype.localised_name, prototype.name } },
        { "?", { "", "\n", prototype.localised_description }, "" },
      },
    }
  end)
  flib_gui.add(ingredients_table, ingredients_children)
  self.elems.tech_info_ingredients_time_label.caption = "[img=quantity-time] "
    .. math.round(technology.research_unit_energy / 60, 0.1)
  local research_unit_count = util.get_research_unit_count(technology, level)
  self.elems.tech_info_ingredients_count_label.caption = "[img=quantity-multiplier] "
    .. format.number(research_unit_count, research_unit_count > 9999)
  -- Effects
  local effects_table = self.elems.tech_info_effects_table
  effects_table.clear()
  flib_gui.add(effects_table, table.map(technology.effects, gui_util.effect_button))
  -- Prerequisites
  local prerequisites = {}
  for _, prerequisite in pairs(technology.prerequisites) do
    table.insert(prerequisites, prerequisite)
  end
  gui_util.update_tech_info_sublist(
    self,
    self.elems.tech_info_prerequisites_table,
    gui.on_tech_slot_click,
    prerequisites
  )
  -- Requisites
  local technologies = self.force.technologies
  gui_util.update_tech_info_sublist(
    self,
    self.elems.tech_info_requisites_table,
    gui.on_tech_slot_click,
    table.map(global.technology_requisites[technology.name] or {}, function(requisite_name)
      return technologies[requisite_name]
    end)
  )
  -- Upgrade group
  local technologies = self.force.technologies
  gui_util.update_tech_info_sublist(
    self,
    self.elems.tech_info_upgrade_group_table,
    gui.on_tech_slot_click,
    table.map(global.technology_upgrade_groups[util.get_base_name(technology)] or {}, function(prototype)
      return technologies[prototype.name]
    end)
  )
  -- Footer
  gui.update_tech_info_footer(self)
end

--- @param self Gui
--- @param progress_only boolean?
function gui.update_tech_info_footer(self, progress_only)
  local selected = self.state.selected
  if not selected then
    return
  end
  local technology, level = selected.technology, selected.level
  local research_state = self.force_table.research_states[technology.name]
  local selected_name = util.get_queue_key(technology, level)

  local elems = self.elems
  local is_researched = research_state == constants.research_state.researched
  local in_queue = research_queue.contains(self.force_table.queue, technology, level)
  local progress = util.get_research_progress(technology, level)
  local is_cheating = util.is_cheating(self.player)

  elems.tech_info_footer_frame.visible = not (is_researched and not is_cheating)

  local progressbar = elems.tech_info_footer_progressbar
  progressbar.visible = progress > 0
  elems.tech_info_footer_pusher.visible = progress == 0
  if in_queue then
    progressbar.value = progress
    progressbar.caption = {
      "",
      self.force_table.queue.lookup[selected_name].duration,
      " - ",
      { "format-percent", math.round(progress * 100) },
    }
  end

  if not progress_only then
    elems.tech_info_footer_start_button.visible = not is_researched and not in_queue
    elems.tech_info_footer_cancel_button.visible = not is_researched and in_queue
    elems.tech_info_footer_unresearch_button.visible = is_researched and is_cheating
  end
end

--- @param self Gui
function gui.update_tech_list(self)
  local profiler = game.create_profiler()
  local techs_table = self.elems.techs_table
  local queue = self.force_table.queue
  local selected = self.state.selected or {}
  local research_states = self.force_table.research_states
  local i = 0
  for _, group in pairs(self.force_table.technology_groups) do
    for j = 1, global.num_technologies do
      --- @cast j uint
      local technology = group[j]
      if not technology then
        goto continue
      end
      local level = technology.prototype.level
      if util.is_multilevel(technology) then
        level = math.clamp(
          research_queue.get_highest_level(self.force_table.queue, technology) + 1,
          technology.level,
          technology.prototype.max_level
        ) --[[@as uint]]
      end
      i = i + 1
      local button = techs_table[technology.name] --[[@as LuaGuiElement]]
      if i ~= button.get_index_in_parent() then
        gui_util.move_to(button, techs_table, i)
      end
      gui_util.update_tech_slot(
        button,
        technology,
        level,
        research_states[technology.name],
        research_queue.contains(queue, technology, level),
        selected.technology == technology and selected.level == level
      )
      ::continue::
    end
  end
  profiler.stop()
  if DEBUG then
    log({ "", "update_tech_list ", profiler })
  end
end

flib_gui.add_handlers(gui, function(e, handler)
  local gui = gui.get(e.player_index)
  if gui then
    handler(gui, e)
  end
end)

--- Bootstrap

--- @param player LuaPlayer
--- @return Gui
function gui.new(player)
  gui.destroy(player.index)

  --- @type GuiElems
  local elems = flib_gui.add(player.gui.screen, {
    {
      type = "frame",
      name = "urq_window",
      direction = "vertical",
      visible = false,
      elem_mods = { auto_center = true },
      handler = { [defines.events.on_gui_closed] = gui.on_window_closed },
      {
        type = "flow",
        name = "titlebar_flow",
        style = "flib_titlebar_flow",
        drag_target = "urq_window",
        handler = { [defines.events.on_gui_click] = gui.on_titlebar_click },
        {
          type = "label",
          style = "frame_title",
          caption = { "gui-technology-progress.title" },
          ignored_by_interaction = true,
        },
        { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
        {
          type = "textfield",
          name = "search_textfield",
          style = "urq_search_textfield",
          visible = false,
          clear_and_focus_on_right_click = true,
          handler = { [defines.events.on_gui_text_changed] = gui.update_search_query },
        },
        gui_util.frame_action_button(
          "search_button",
          "utility/search",
          { "gui.urq-search-instruction" },
          gui.toggle_search
        ),
        gui_util.frame_action_button("pin_button", "flib_pin", { "gui.flib-keep-open" }, gui.toggle_pinned),
        gui_util.frame_action_button("close_button", "utility/close", { "gui.close-instruction" }, gui.hide),
      },
      {
        type = "flow",
        style_mods = { horizontal_spacing = 12 },
        {
          type = "flow",
          style_mods = { vertical_spacing = 12, width = 72 * 7 + 12 },
          direction = "vertical",
          {
            type = "frame",
            style = "inside_deep_frame",
            direction = "vertical",
            {
              type = "frame",
              style = "subheader_frame",
              style_mods = { horizontally_stretchable = true },
              { type = "label", style = "subheader_caption_label", caption = { "gui-technology-queue.title" } },
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              {
                type = "label",
                name = "queue_population_label",
                caption = { "gui.urq-queue-population", 0, constants.queue_limit },
              },
              { type = "line", direction = "vertical" },
              {
                type = "sprite-button",
                name = "queue_requeue_multilevel_button",
                style = "tool_button",
                sprite = "utility/variations_tool_icon",
                tooltip = { "gui.urq-requeue-multilevel-technologies" },
                handler = { [defines.events.on_gui_click] = gui.toggle_queue_requeue_multilevel },
              },
              {
                type = "sprite-button",
                name = "queue_pause_button",
                style = "tool_button",
                sprite = "utility/pause",
                tooltip = { "gui.urq-pause-queue" },
                handler = { [defines.events.on_gui_click] = gui.toggle_queue_paused },
              },
              {
                type = "sprite-button",
                name = "queue_trash_button",
                style = "tool_button_red",
                sprite = "utility/trash",
                tooltip = { "gui.urq-clear-queue" },
                enabled = false,
                handler = { [defines.events.on_gui_click] = gui.clear_queue },
              },
            },
            {
              type = "scroll-pane",
              name = "queue_scroll_pane",
              style = "urq_tech_list_scroll_pane",
              style_mods = { height = 100 * 2, horizontally_stretchable = true },
              vertical_scroll_policy = "auto-and-reserve-space",
              {
                type = "table",
                name = "queue_table",
                style = "technology_slot_table",
                column_count = 7,
              },
            },
          },
          {
            type = "frame",
            style = "inside_shallow_frame",
            direction = "vertical",
            {
              type = "frame",
              style = "subheader_frame",
              style_mods = { horizontally_stretchable = true },
              {
                type = "label",
                name = "tech_info_name_label",
                style = "subheader_caption_label",
                caption = { "gui.urq-no-technology-selected" },
              },
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              {
                type = "sprite-button",
                style = "tool_button",
                sprite = "urq_open_in_graph",
                tooltip = { "gui.urq-open-in-graph" },
                handler = { [defines.events.on_gui_click] = gui.open_in_graph },
              },
            },
            {
              type = "scroll-pane",
              style = "flib_naked_scroll_pane",
              style_mods = { horizontally_stretchable = true, vertically_stretchable = true },
              direction = "vertical",
              vertical_scroll_policy = "always",
              {
                type = "flow",
                style_mods = { horizontal_spacing = 12 },
                {
                  type = "frame",
                  name = "tech_info_main_slot_frame",
                  style = "deep_frame_in_shallow_frame",
                },
                {
                  type = "flow",
                  direction = "vertical",
                  {
                    type = "label",
                    name = "tech_info_description_label",
                    style_mods = { single_line = false, horizontally_stretchable = true },
                    caption = "",
                  },
                },
              },
              {
                type = "line",
                direction = "horizontal",
                style_mods = { left_margin = -2, right_margin = -2, top_margin = 4 },
              },
              { type = "label", style = "heading_2_label", caption = { "gui-technology-preview.unit-ingredients" } },
              {
                type = "flow",
                style = "centering_horizontal_flow",
                {
                  type = "frame",
                  style = "slot_group_frame",
                  {
                    type = "table",
                    name = "tech_info_ingredients_table",
                    column_count = 11,
                  },
                },
                {
                  type = "flow",
                  style_mods = { vertical_spacing = -2, padding = 0, top_padding = -4 },
                  direction = "vertical",
                  { type = "label", name = "tech_info_ingredients_count_label", style = "count_label" },
                  { type = "label", name = "tech_info_ingredients_time_label", style = "count_label" },
                },
              },
              {
                type = "line",
                direction = "horizontal",
                style_mods = { left_margin = -2, right_margin = -2, top_margin = 4 },
              },
              { type = "label", style = "heading_2_label", caption = { "gui-technology-preview.effects" } },
              {
                type = "table",
                name = "tech_info_effects_table",
                style_mods = { horizontal_spacing = 8 },
                column_count = 12,
              },
              gui_util.tech_info_sublist({ "gui.urq-prerequisites" }, "tech_info_prerequisites_table"),
              gui_util.tech_info_sublist({ "gui.urq-requisites" }, "tech_info_requisites_table"),
              gui_util.tech_info_sublist({ "gui.urq-upgrade-group" }, "tech_info_upgrade_group_table"),
            },
            {
              type = "frame",
              name = "tech_info_footer_frame",
              style = "subfooter_frame",
              {
                type = "progressbar",
                name = "tech_info_footer_progressbar",
                style = "production_progressbar",
                style_mods = { horizontally_stretchable = true },
                caption = { "format-percent", 0 },
              },
              { type = "empty-widget", name = "tech_info_footer_pusher", style = "flib_horizontal_pusher" },
              {
                type = "button",
                name = "tech_info_footer_unresearch_button",
                caption = { "gui-technology-preview.un-research" },
                tooltip = { "gui-technology-preview.un-research-tooltip" },
                visible = false,
                handler = { [defines.events.on_gui_click] = gui.unresearch },
              },
              {
                type = "button",
                name = "tech_info_footer_cancel_button",
                style = "red_button",
                caption = { "gui.urq-cancel-research" },
                tooltip = { "gui.urq-cancel-research" },
                visible = false,
                handler = { [defines.events.on_gui_click] = gui.cancel_selected_research },
              },
              {
                type = "button",
                name = "tech_info_footer_start_button",
                style = "green_button",
                caption = { "gui-technology-preview.start-research" },
                tooltip = { "gui-technology-preview.start-research" },
                handler = { [defines.events.on_gui_click] = gui.on_start_research_click },
              },
            },
          },
        },
        {
          type = "frame",
          style = "inside_deep_frame",
          direction = "vertical",
          {
            type = "frame",
            style = "subheader_frame",
            style_mods = { horizontally_stretchable = true },
            { type = "label", style = "subheader_caption_label", caption = { "gui-technologies-list.title" } },
          },
          {
            type = "scroll-pane",
            name = "techs_scroll_pane",
            style = "urq_tech_list_scroll_pane",
            style_mods = { horizontally_stretchable = true, height = 100 * 7, width = 72 * 8 + 12 },
            vertical_scroll_policy = "auto-and-reserve-space",
            { type = "table", name = "techs_table", style = "technology_slot_table", column_count = 8 },
          },
        },
      },
    },
  })

  -- Build techs list
  local show_controls = player.mod_settings["urq-show-control-hints"].value --[[@as boolean]]
  local force_table = global.forces[player.force.index]
  local buttons = {}
  for _, technology in pairs(player.force.technologies) do
    table.insert(
      buttons,
      gui_util.technology_slot(
        gui.on_tech_slot_click,
        technology,
        technology.prototype.level,
        force_table.research_states[technology.name],
        show_controls
      )
    )
  end
  flib_gui.add(elems.techs_table, buttons)

  local force = player.force --[[@as LuaForce]]

  --- @class Gui
  local self = {
    elems = elems,
    force = force,
    force_table = force_table,
    player = player,
    state = {
      opening_graph = false,
      pinned = false,
      research_state_counts = {},
      search_open = false,
      search_query = "",
      --- @type TechnologyAndLevel?
      selected = nil,
    },
  }
  global.guis[player.index] = self

  gui.update_queue(self)
  gui.update_tech_list(self)
  gui.update_durations_and_progress(self)
  gui.filter_tech_list(self)

  return self
end

--- @param player_index uint
function gui.destroy(player_index)
  local self = global.guis[player_index]
  if not self then
    return
  end
  if self.elems.urq_window.valid then
    self.elems.urq_window.destroy()
  end
  global.guis[self.player.index] = nil
end

--- @param player_index uint
--- @return Gui?
function gui.get(player_index)
  local self = global.guis[player_index]
  if not self or not self.elems.urq_window.valid then
    if self then
      self.player.print({ "message.urq-recreated-gui" })
    end
    gui.destroy(player_index)
    self = gui.new(game.get_player(player_index) --[[@as LuaPlayer]])
  end
  return self
end

--- @param force LuaForce
function gui.update_force(force)
  for _, player in pairs(force.players) do
    local player_gui = gui.get(player.index)
    -- TODO: Only update when open
    if player_gui then
      gui.update_queue(player_gui)
      gui.update_tech_info(player_gui)
      gui.update_tech_list(player_gui)
      gui.filter_tech_list(player_gui)
      gui.update_durations_and_progress(player_gui)
    end
  end
end

--- @param force LuaForce
function gui.update_force_progress(force)
  for _, player in pairs(force.players) do
    local player_gui = gui.get(player.index)
    if player_gui and player_gui.elems.urq_window.visible then
      gui.update_durations_and_progress(player_gui)
    end
  end
end

--- @param force_table ForceTable
function gui.schedule_update(force_table)
  if game.tick_paused then
    gui.update_force(force_table.force)
  else
    global.update_force_guis[force_table.force.index] = true
  end
end

gui.dispatch = flib_gui.dispatch
gui.handle_events = flib_gui.handle_events

return gui
