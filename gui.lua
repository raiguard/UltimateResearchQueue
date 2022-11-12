local gui = require("__flib__.gui-lite")
local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("__UltimateResearchQueue__.constants")
local util = require("__UltimateResearchQueue__.util")

--- @param elem LuaGuiElement
--- @param sprite_base string
--- @param value boolean
local function toggle_frame_action_button(elem, sprite_base, value)
  if value then
    elem.style = "flib_selected_frame_action_button"
    elem.sprite = sprite_base .. "_black"
  else
    elem.style = "frame_action_button"
    elem.sprite = sprite_base .. "_white"
  end
end

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
--- @field tech_info_footer_frame LuaGuiElement
--- @field tech_info_footer_progressbar LuaGuiElement
--- @field tech_info_footer_pusher LuaGuiElement
--- @field tech_info_footer_cancel_button LuaGuiElement
--- @field tech_info_footer_start_button LuaGuiElement
--- @field tech_info_footer_unresearch_button LuaGuiElement

--- @class Gui
local root = {}
local root_mt = { __index = root }
script.register_metatable("UltimateResearchQueue_main_gui", root_mt)

--- @param effect TechnologyModifier
local function effect_button(effect)
  local sprite, tooltip

  if effect.type == "ammo-damage" then
    sprite = global.effect_icons[effect.ammo_category]
    tooltip =
      { "modifier-description." .. effect.ammo_category .. "-damage-bonus", tostring(effect.modifier * 100) .. "%" }
  elseif effect.type == "give-item" then
    sprite = "item/" .. effect.item
    tooltip = { "", effect.count .. "x  ", game.item_prototypes[effect.item].localised_name }
  elseif effect.type == "gun-speed" then
    sprite = global.effect_icons[effect.ammo_category]
    tooltip = {
      "modifier-description." .. effect.ammo_category .. "-shooting-speed-bonus",
      tostring(effect.modifier * 100) .. "%",
    }
  elseif effect.type == "nothing" then
    tooltip = effect.effect_description
  elseif effect.type == "turret-attack" then
    sprite = "entity/" .. effect.turret_id
    tooltip = {
      "modifier-description." .. effect.turret_id .. "-attack-bonus",
      tostring(effect.modifier * 100) .. "%",
    }
  elseif effect.type == "unlock-recipe" then
    sprite = "recipe/" .. effect.recipe
    tooltip = game.recipe_prototypes[effect.recipe].localised_name
  else
    sprite = global.effect_icons[effect.type] or ("utility/" .. string.gsub(effect.type, "%-", "_") .. "_modifier_icon")
    local modifier = effect.modifier
    --- @type LocalisedString
    local formatted = tostring(modifier)
    local format = constants.effect_display_type[effect.type]
    if format then
      if format == "float" then
        formatted = tostring(math.round(modifier, 0.01))
      elseif format == "float_percent" then
        formatted = { "format-percent", tostring(math.round(modifier * 100, 0.01)) }
      elseif format == "signed" or format == "unsigned" then
        formatted = tostring(math.round(modifier))
      elseif format == "ticks" then
        formatted = util.format_time_short(effect.modifier)
      end
    end
    tooltip = { "modifier-description." .. effect.type, formatted }
  end

  local overlay_constant = constants.overlay_constant[effect.type]
  --- @type GuiElemDef?
  local overlay_elem
  if overlay_constant then
    overlay_elem =
      { type = "sprite-button", style = "transparent_slot", sprite = overlay_constant, ignored_by_interaction = true }
  end

  if DEBUG then
    if tooltip then
      tooltip = { "", tooltip, "\n", serpent.block(effect) }
    else
      tooltip = serpent.block(effect)
    end
  end

  return {
    type = "sprite-button",
    style = "transparent_slot",
    sprite = sprite or "utility/nothing_modifier_icon",
    number = effect.count,
    tooltip = tooltip,
    overlay_elem,
  }
end

--- @param name string
--- @param sprite string
--- @param tooltip LocalisedString
--- @param action function
--- @return GuiElemDef
local function frame_action_button(name, sprite, tooltip, action)
  return {
    type = "sprite-button",
    name = name,
    style = "frame_action_button",
    tooltip = tooltip,
    sprite = sprite .. "_white",
    hovered_sprite = sprite .. "_black",
    clicked_sprite = sprite .. "_black",
    handler = { [defines.events.on_gui_click] = action },
  }
end

--- @param technology LuaTechnology
--- @param research_state ResearchState
--- @param selected_name string?
--- @param is_tech_info boolean?
--- @return GuiElemDef
local function tech_button(technology, research_state, selected_name, is_tech_info)
  local properties = util.get_technology_slot_properties(technology, research_state, selected_name)
  local progress = util.get_research_progress(technology)

  local ingredients = {}
  local ingredients_len = 0
  for i, ingredient in pairs(technology.research_unit_ingredients) do
    ingredients_len = i
    table.insert(ingredients, {
      type = "sprite",
      style = "urq_technology_slot_ingredient",
      sprite = ingredient.type .. "/" .. ingredient.name,
      ignored_by_interaction = true,
    })
  end

  -- TODO: Add remainder to always fill available space
  local ingredients_spacing = math.clamp((68 - 16) / (ingredients_len - 1) - 16, -15, -5)

  local tooltip = technology.localised_name
  if DEBUG then
    tooltip = { "", tooltip, "\norder=" .. global.technology_order[technology.name] }
  end

  return {
    type = "sprite-button",
    name = technology.name,
    style = properties.style,
    tooltip = tooltip,
    ignored_by_interaction = is_tech_info,
    tags = {
      research_state = research_state,
    },
    handler = { [defines.events.on_gui_click] = root.on_tech_slot_click },
    {
      type = "flow",
      style = "urq_technology_slot_sprite_flow",
      ignored_by_interaction = true,
      {
        type = "sprite",
        style = "urq_technology_slot_sprite",
        sprite = "technology/" .. technology.name,
      },
    },
    properties.leveled and {
      type = "label",
      name = "level_label",
      style = "urq_technology_slot_level_label_" .. properties.research_state_str,
      caption = technology.level,
      ignored_by_interaction = true,
    } or {},
    properties.ranged and {
      type = "label",
      name = "level_range_label",
      style = "urq_technology_slot_level_range_label_" .. properties.research_state_str,
      caption = technology.prototype.level .. " - " .. properties.max_level_str,
      ignored_by_interaction = true,
    } or {},
    {
      type = "flow",
      style = "urq_technology_slot_ingredients_flow",
      style_mods = { horizontal_spacing = ingredients_spacing },
      children = ingredients,
      ignored_by_interaction = true,
    },
    {
      type = "label",
      name = "duration_label",
      style = "urq_technology_slot_duration_label",
      ignored_by_interaction = true,
    },
    {
      type = "progressbar",
      name = "progressbar",
      style = "urq_technology_slot_progressbar",
      value = progress,
      visible = not is_tech_info and progress > 0,
      ignored_by_interaction = true,
    },
  }
end

-- METHODS

function root:cancel_research(_, e)
  local tech_name = e.element.name
  self.force_table.queue:remove(tech_name)
  self:update_tech_info_footer()
end

function root:clear_queue()
  local queue = self.force_table.queue
  local tech_name = next(queue.queue)
  while tech_name do
    queue:remove(tech_name)
    tech_name = next(queue.queue)
  end
  self:update_tech_info_footer()
end

function root:destroy()
  if self.elems.urq_window.valid then
    self.elems.urq_window.destroy()
  end
  self.player_table.gui = nil
end

-- Updates tech list button visibility based on search query and other settings
function root:filter_tech_list()
  local query = self.state.search_query
  local dictionaries = self.player_table.dictionaries
  local technologies = game.technology_prototypes
  local research_states = self.force_table.research_states
  local show_disabled = self.player.mod_settings["urq-show-disabled-techs"].value
  for _, button in pairs(self.elems.techs_table.children) do
    local tech_name = button.name
    local technology = technologies[tech_name]
    -- Show/hide disabled
    local research_state_matched = true
    local research_state = research_states[tech_name]
    if research_state == constants.research_state.disabled and not show_disabled then
      research_state_matched = false
    end
    -- Search query
    local search_matched = #query == 0 -- Automatically pass search on empty query
    if research_state_matched and not search_matched then
      local to_search = {}
      if dictionaries then
        table.insert(to_search, dictionaries.technology[tech_name])
        for _, effect in pairs(technology.effects) do
          if effect.type == "unlock-recipe" then
            table.insert(to_search, dictionaries.recipe[effect.recipe])
          end
        end
      else
        table.insert(to_search, tech_name)
      end
      for _, str in pairs(to_search) do
        if string.find(string.lower(str), query, 1, true) then
          search_matched = true
          break
        end
      end
    end
    button.visible = research_state_matched and search_matched
  end
end

function root:hide()
  if self.state.opening_graph then
    return
  end
  if self.player.opened_gui_type == defines.gui_type.custom and self.player.opened == self.elems.urq_window then
    self.player.opened = nil
  end
  self.elems.urq_window.visible = false
end

--- @param e on_gui_click
function root:on_start_research_click(e)
  local selected = self.state.selected
  if not selected then
    return
  end
  self:start_research(selected, e.control and util.is_cheating(self.player))
end

--- @param e on_gui_click
function root:on_tech_slot_click(e)
  if DEBUG then
    log("tech clicked: " .. e.element.name)
  end
  local tech_name = e.element.name
  if e.button == defines.mouse_button_type.right then
    self.force_table.queue:remove(tech_name)
    return
  end
  if util.is_double_click(e.element) then
    self:start_research(tech_name)
    return
  end
  self:select_tech(tech_name)
end

--- @param e on_gui_click
function root:on_titlebar_click(e)
  if e.button == defines.mouse_button_type.middle then
    self.elems.urq_window.force_auto_center()
  end
end

function root:on_window_closed()
  if self.state.pinned then
    return
  end
  if self.state.search_open then
    self:toggle_search()
    self.player.opened = self.elems.urq_window
    return
  end
  self:hide()
end

function root:open_in_graph()
  local selected_technology = self.state.selected
  if selected_technology then
    self.state.opening_graph = true
    self.player.open_technology_gui(selected_technology)
    self.state.opening_graph = false
  end
end

--- @param tech_name string
function root:select_tech(tech_name)
  local former_selected = self.state.selected
  if former_selected == tech_name then
    return
  end
  self.state.selected = tech_name

  -- Queue and techs list
  for _, table in pairs({ self.elems.queue_table, self.elems.techs_table }) do
    if former_selected then
      local former_slot = table[former_selected]
      if former_slot then
        former_slot.style = string.gsub(former_slot.style.name, "selected_", "")
        table.parent.scroll_to_element(former_slot)
      end
    end
    local new_slot = table[tech_name]
    if new_slot then
      new_slot.style = string.gsub(new_slot.style.name, "urq_technology_slot_", "urq_technology_slot_selected_")
      table.parent.scroll_to_element(new_slot)
    end
  end

  -- Tech information

  local technology = self.force.technologies[tech_name]
  local research_state = self.force_table.research_states[tech_name]
  -- Slot
  local main_slot_frame = self.elems.tech_info_main_slot_frame
  main_slot_frame.clear() -- The best thing to do is clear it, otherwise we'd need to diff all the sub-elements
  if tech_name then
    gui.add(main_slot_frame, { tech_button(technology, research_state, nil, true) })
  end
  -- Name and description
  self.elems.tech_info_name_label.caption = technology.localised_name
  self.elems.tech_info_description_label.caption = technology.localised_description
  -- Ingredients
  local ingredients_table = self.elems.tech_info_ingredients_table
  ingredients_table.clear()
  local ingredients_children = table.map(technology.research_unit_ingredients, function(ingredient)
    return {
      type = "sprite-button",
      style = "transparent_slot",
      sprite = "item/" .. ingredient.name,
      number = ingredient.amount,
      tooltip = game.item_prototypes[ingredient.name].localised_name,
    }
  end)
  gui.add(ingredients_table, ingredients_children)
  self.elems.tech_info_ingredients_time_label.caption = "[img=quantity-time] "
    .. math.round(technology.research_unit_energy / 60, 0.1)
  self.elems.tech_info_ingredients_count_label.caption = "[img=quantity-multiplier] " .. technology.research_unit_count
  -- Effects
  local effects_table = self.elems.tech_info_effects_table
  effects_table.clear()
  gui.add(effects_table, table.map(technology.effects, effect_button))
  -- Footer
  self:update_tech_info_footer()
end

--- @param select_tech string?
function root:show(select_tech)
  if select_tech then
    self:select_tech(select_tech)
  end
  self.elems.urq_window.visible = true
  self.elems.urq_window.bring_to_front()
  if not self.state.pinned then
    self.player.opened = self.elems.urq_window
  end
end

--- @param tech_name string
--- @param instant_research boolean?
function root:start_research(tech_name, instant_research)
  local research_state = self.force_table.research_states[tech_name]
  if research_state == constants.research_state.researched then
    util.flying_text(self.player, { "message.urq-already-researched" })
    return
  end
  local to_research
  if research_state == constants.research_state.not_available then
    -- Add all prerequisites to research this tech ASAP
    to_research = util.get_unresearched_prerequisites(self.force_table, self.force.technologies[tech_name])
  else
    to_research = { tech_name }
  end
  if instant_research then
    local technologies = self.force.technologies
    for _, tech_name in pairs(to_research) do
      local technology = technologies[tech_name]
      if not technology.researched then
        technology.researched = true
      end
    end
  else
    local push_error = self.force_table.queue:push(to_research)
    if push_error == constants.queue_push_error.already_in_queue then
      util.flying_text(self.player, { "message.urq-already-in-queue" })
    elseif push_error == constants.queue_push_error.queue_full then
      util.flying_text(self.player, { "message.urq-queue-is-full" })
    elseif push_error == constants.queue_push_error.too_many_prerequisites then
      util.flying_text(self.player, { "message.urq-too-many-unresearched-prerequisites" })
    elseif push_error == constants.queue_push_error.too_many_prerequisites_queue_full then
      util.flying_text(self.player, { "message.urq-too-many-prerequisites-queue-full" })
    end
  end
  self:update_tech_info_footer()
end

function root:toggle_pinned()
  self.state.pinned = not self.state.pinned
  toggle_frame_action_button(self.elems.pin_button, "flib_pin", self.state.pinned)
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

function root:toggle_search()
  self.state.search_open = not self.state.search_open
  toggle_frame_action_button(self.elems.search_button, "utility/search", self.state.search_open)
  self.elems.search_textfield.visible = self.state.search_open
  if self.state.search_open then
    self.elems.search_textfield.focus()
  else
    self.state.search_query = ""
    self.elems.search_textfield.text = ""
    self:filter_tech_list()
  end
end

function root:toggle_queue_paused()
  self.force_table.queue:toggle_paused()
end

function root:toggle_visible()
  if self.elems.urq_window.visible then
    self:hide()
  else
    self:show()
  end
end

function root:unresearch()
  local selected = self.state.selected
  if not selected then
    return
  end

  local function propagate(technologies, technology)
    local requisites = global.technology_requisites[technology.name]
    if requisites then
      for requisite_name in pairs(requisites) do
        local requisite = technologies[requisite_name]
        if requisite.researched then
          propagate(technologies, requisite)
        end
      end
    end
    technology.researched = false
  end

  propagate(self.force.technologies, self.force.technologies[selected])
end

function root:update_durations_and_progress()
  local queue_table = self.elems.queue_table
  local techs_table = self.elems.techs_table
  for tech_name, duration in pairs(self.force_table.queue.queue) do
    local queue_button = queue_table[tech_name]
    local techs_button = techs_table[tech_name]
    if not queue_button or not techs_button then
      goto continue
    end
    queue_button.duration_label.caption = duration
    techs_button.duration_label.caption = duration

    local progress = util.get_research_progress(self.force.technologies[tech_name])
    queue_button.progressbar.value = progress
    queue_button.progressbar.visible = progress > 0
    techs_button.progressbar.value = progress
    techs_button.progressbar.visible = progress > 0

    ::continue::
  end
  self:update_tech_info_footer(true)
end

function root:update_queue()
  local profiler = game.create_profiler()

  local paused = self.force_table.queue.paused
  local pause_button = self.elems.queue_pause_button
  if paused then
    pause_button.style = "flib_selected_tool_button"
    pause_button.tooltip = { "gui.urq-resume-queue" }
  else
    pause_button.style = "tool_button"
    pause_button.tooltip = { "gui.urq-pause-queue" }
  end

  self.elems.queue_trash_button.enabled = next(self.force_table.queue.queue) and true or false

  self.elems.queue_population_label.caption =
    { "gui.urq-queue-population", self.force_table.queue.len, constants.queue_limit }

  local queue = self.force_table.queue.queue
  local queue_table = self.elems.queue_table
  local research_states = self.force_table.research_states
  local technologies = self.force.technologies
  local i = 0
  for tech_name in pairs(queue) do
    i = i + 1
    local button = queue_table[tech_name]
    if button then
      util.move_to(button, queue_table, i)
      util.update_tech_slot_style(
        button,
        technologies[tech_name],
        research_states[tech_name],
        self.state.selected,
        true
      )
    else
      local button_template = tech_button(technologies[tech_name], research_states[tech_name], self.state.selected)
      button_template.index = i
      gui.add(queue_table, { button_template })
    end
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

function root:update_search_query()
  self.state.search_query = self.elems.search_textfield.text

  if game.tick_paused or #self.state.search_query == 0 then
    global.filter_tech_list[self.player.index] = nil
    self:filter_tech_list()
  else
    global.filter_tech_list[self.player.index] = game.tick + 30
  end
end

--- @param progress_only boolean?
function root:update_tech_info_footer(progress_only)
  local selected = self.state.selected
  if not selected then
    return
  end

  local elems = self.elems
  local research_state = self.force_table.research_states[selected]
  local researched = research_state == constants.research_state.researched
  local in_queue = self.force_table.queue:contains(selected)
  local progress = util.get_research_progress(self.force.technologies[selected])
  local is_cheating = util.is_cheating(self.player)

  elems.tech_info_footer_frame.visible = not (researched and not is_cheating)

  local progressbar = elems.tech_info_footer_progressbar
  progressbar.visible = progress > 0
  elems.tech_info_footer_pusher.visible = progress == 0
  if in_queue then
    progressbar.value = progress
    progressbar.caption =
      { "", self.force_table.queue.queue[selected], " - ", { "format-percent", math.round(progress * 100) } }
  end

  if not progress_only then
    elems.tech_info_footer_start_button.visible = not researched and not in_queue
    elems.tech_info_footer_cancel_button.visible = not researched and in_queue
    elems.tech_info_footer_cancel_button.name = selected
    elems.tech_info_footer_unresearch_button.visible = researched and is_cheating
  end
end

function root:update_tech_list()
  local profiler = game.create_profiler()
  local techs_table = self.elems.techs_table
  local research_states = self.force_table.research_states
  local queue = self.force_table.queue
  local i = 0
  for group_state, group in pairs(self.force_table.grouped_technologies) do
    -- FIXME: This will only iterate the first 1024 techs of a group in order. Oh well!
    for _, technology in pairs(group) do
      i = i + 1
      local button = techs_table[technology.name]
      if button then
        util.move_to(button, techs_table, i)
        util.update_tech_slot_style(
          button,
          technology,
          group_state,
          self.state.selected,
          queue:contains(technology.name)
        )
      else
        local button_template = tech_button(technology, research_states[technology.name], self.state.selected)
        button_template.index = i
        gui.add(techs_table, { button_template })
      end
    end
  end
  local children = techs_table.children
  for i = i + 1, #children do
    children[i].destroy()
  end
  profiler.stop()
  if DEBUG then
    log({ "", "update_tech_list ", profiler })
  end
end

gui.add_handlers(root, function(e, handler)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local gui = util.get_gui(player)
  if gui then
    handler(gui, e)
  end
end)

--- BOOTSTRAP

--- @param player LuaPlayer
--- @param player_table PlayerTable
--- @return Gui
function root.new(player, player_table)
  --- @type GuiElems
  local elems = gui.add(player.gui.screen, {
    {
      type = "frame",
      name = "urq_window",
      direction = "vertical",
      visible = false,
      handler = { [defines.events.on_gui_closed] = root.on_window_closed },
      {
        type = "flow",
        name = "titlebar_flow",
        style = "flib_titlebar_flow",
        handler = { [defines.events.on_gui_click] = root.on_titlebar_click },
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
          handler = { [defines.events.on_gui_text_changed] = root.update_search_query },
        },
        frame_action_button("search_button", "utility/search", { "gui.urq-search-instruction" }, root.toggle_search),
        frame_action_button("pin_button", "flib_pin", { "gui.flib-keep-open" }, root.toggle_pinned),
        frame_action_button("close_button", "utility/close", { "gui.close-instruction" }, root.hide),
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
                name = "queue_pause_button",
                style = "tool_button",
                sprite = "utility/pause",
                tooltip = { "gui.urq-pause-queue" },
                handler = { [defines.events.on_gui_click] = root.toggle_queue_paused },
              },
              {
                type = "sprite-button",
                name = "queue_trash_button",
                style = "tool_button_red",
                sprite = "utility/trash",
                tooltip = { "gui.urq-clear-queue" },
                enabled = false,
                handler = { [defines.events.on_gui_click] = root.clear_queue },
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
                handler = { [defines.events.on_gui_click] = root.open_in_graph },
              },
            },
            {
              type = "scroll-pane",
              style = "flib_naked_scroll_pane",
              style_mods = { horizontally_stretchable = true, vertically_stretchable = true, right_padding = 0 },
              direction = "vertical",
              vertical_scroll_policy = "auto-and-reserve-space",
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
                    column_count = 12,
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
                handler = { [defines.events.on_gui_click] = root.unresearch },
              },
              {
                type = "button",
                name = "tech_info_footer_cancel_button",
                style = "red_button",
                caption = { "gui.urq-cancel-research" },
                tooltip = { "gui.urq-cancel-research" },
                visible = false,
                handler = { [defines.events.on_gui_click] = root.cancel_research },
              },
              {
                type = "button",
                name = "tech_info_footer_start_button",
                style = "green_button",
                caption = { "gui-technology-preview.start-research" },
                tooltip = { "gui-technology-preview.start-research" },
                handler = { [defines.events.on_gui_click] = root.on_start_research_click },
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

  elems.titlebar_flow.drag_target = elems.urq_window
  elems.urq_window.force_auto_center()

  local force = player.force --[[@as LuaForce]]

  --- @class Gui
  local self = {
    elems = elems,
    force = force,
    force_table = global.forces[player.force.index],
    player = player,
    player_table = player_table,
    state = {
      opening_graph = false,
      pinned = false,
      research_state_counts = {},
      search_open = false,
      search_query = "",
      --- @type string?
      selected = nil,
    },
  }
  setmetatable(self, root_mt)
  player_table.gui = self

  self:update_queue()
  self:update_tech_list()
  self:update_durations_and_progress()
  self:filter_tech_list()

  return self
end

root.dispatch = gui.dispatch
root.handle_events = gui.handle_events

return root
