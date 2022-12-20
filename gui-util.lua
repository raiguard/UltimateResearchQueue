local flib_gui = require("__flib__/gui-lite")
local math = require("__flib__/math")
local table = require("__flib__/table")

local constants = require("__UltimateResearchQueue__/constants")
local util = require("__UltimateResearchQueue__/util")

local gui_util = {}

--- @param technology_name string
--- @param upgrade_group LuaTechnologyPrototype[]
--- @param research_states table<string, ResearchState>
function gui_util.check_upgrade_group(technology_name, upgrade_group, research_states)
  if research_states[technology_name] == constants.research_state.researched then
    -- Show if highest researched
    for i = #upgrade_group, 1, -1 do
      local other_tech_name = upgrade_group[i].name
      if research_states[other_tech_name] == constants.research_state.researched then
        return other_tech_name == technology_name
      end
    end
  else
    -- Show if lowest unresearched
    for i = 1, #upgrade_group do
      local other_tech_name = upgrade_group[i].name
      if research_states[other_tech_name] ~= constants.research_state.researched then
        return other_tech_name == technology_name
      end
    end
  end
end

--- @param effect TechnologyModifier
--- @param show_controls boolean
function gui_util.effect_button(effect, show_controls)
  local sprite, tooltip

  if effect.type == "ammo-damage" then
    sprite = global.effect_icons[effect.ammo_category]
    tooltip =
      { "modifier-description." .. effect.ammo_category .. "-damage-bonus", tostring(effect.modifier * 100) .. "%" }
  elseif effect.type == "give-item" then
    sprite = "item/" .. effect.item
    tooltip = {
      "gui.urq-tooltip-title",
      {
        "",
        effect.count .. " × ",
        game.item_prototypes[effect.item].localised_name,
      },
    }
    if show_controls and script.active_mods["RecipeBook"] then
      table.insert(tooltip, { "gui.urq-tooltip-view-in-recipe-book" })
    end
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

    local prototype = game.recipe_prototypes[effect.recipe]
    tooltip = {
      "",
      {
        "gui.urq-tooltip-title",
        {
          "",
          prototype.localised_name,
          " (",
          { "description.recipe" },
          ")",
        },
      },
      { "?", { "", "\n", prototype.localised_description }, "" },
    }
    if show_controls and script.active_mods["RecipeBook"] then
      table.insert(tooltip, { "gui.urq-tooltip-view-in-recipe-book" })
    end
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
function gui_util.frame_action_button(name, sprite, tooltip, action)
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
--- @param is_selected boolean?
--- @return TechnologySlotProperties
function gui_util.get_technology_slot_properties(technology, research_state, is_selected)
  local research_state_str = table.find(constants.research_state, research_state)
  local max_level_str = technology.prototype.max_level == math.max_uint and "[img=infinity]"
    or tostring(technology.prototype.max_level)
  local style = "urq_technology_slot_"
    .. research_state_str
    .. ((technology.upgrade or util.is_multilevel(technology) or technology.prototype.level > 1) and "_leveled" or "")
    .. (is_selected and "_selected" or "")

  --- @class TechnologySlotProperties
  return { max_level_str = max_level_str, research_state_str = research_state_str, style = style }
end

--- @param elem LuaGuiElement
function gui_util.is_double_click(elem)
  local tags = elem.tags
  local last_click_tick = tags.last_click_tick or 0
  local is_double_click = game.ticks_played - last_click_tick < 12
  if is_double_click then
    tags.last_click_tick = nil
  else
    tags.last_click_tick = game.ticks_played
  end
  elem.tags = tags
  return is_double_click
end

--- @param technology LuaTechnology
--- @param query string
--- @param dictionaries table<string, TranslatedDictionary>?
--- @return boolean
function gui_util.match_search_strings(technology, query, dictionaries)
  local to_search = {}
  if dictionaries then
    to_search[#to_search + 1] = dictionaries.technology[technology.name]
    local effects = technology.effects
    for i = 1, #effects do
      local effect = effects[i]
      if effect.type == "unlock-recipe" then
        to_search[#to_search + 1] = dictionaries.recipe[effect.recipe]
      end
    end
  else
    to_search[#to_search + 1] = technology.name
  end
  for _, str in pairs(to_search) do
    if string.find(string.lower(str), query, 1, true) then
      return true
    end
  end
  return false
end

--- @param element LuaGuiElement
--- @param parent LuaGuiElement
--- @param index number
function gui_util.move_to(element, parent, index)
  --- @cast index uint
  local dummy = parent.add({ type = "empty-widget", index = index })
  parent.swap_children(element.get_index_in_parent(), index)
  dummy.destroy()
end

--- @param caption LocalisedString
--- @param table_name string
function gui_util.tech_info_sublist(caption, table_name)
  return {
    type = "flow",
    direction = "vertical",
    {
      type = "line",
      direction = "horizontal",
      style_mods = { left_margin = -2, right_margin = -2, top_margin = 4 },
    },
    { type = "label", style = "heading_2_label", caption = caption },
    {
      type = "frame",
      style = "urq_tech_list_frame",
      { type = "table", name = table_name, style = "slot_table", column_count = 6 },
    },
  }
end

--- @param technology LuaTechnology
--- @param level uint
--- @param research_state ResearchState
--- @param show_controls boolean
--- @param is_selected boolean?
--- @return GuiElemDef
function gui_util.technology_slot(technology, level, research_state, show_controls, is_selected)
  local properties = gui_util.get_technology_slot_properties(technology, research_state, is_selected)
  local progress = util.get_research_progress(technology, level)

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

  local ingredients_spacing = math.clamp((68 - 16) / (ingredients_len - 1) - 16, -15, -5)

  local tooltip = { "" }
  -- Title
  local name = technology.localised_name
  if util.is_multilevel(technology) then
    name = { "", name, " ", level }
  end
  table.insert(tooltip, { "gui.urq-tooltip-title", name })
  -- Description
  table.insert(tooltip, { "?", { "", "\n", technology.localised_description }, "" })
  -- Cost
  local ingredients_tt = ""
  for _, ingredient in pairs(technology.research_unit_ingredients) do
    ingredients_tt = ingredients_tt .. "[img=item/" .. ingredient.name .. "]" .. ingredient.amount
  end
  table.insert(tooltip, {
    "",
    "\n[",
    ingredients_tt,
    " [img=quantity-time][font=default-semibold]",
    math.round(technology.research_unit_energy / 60, 0.1),
    "[/font]] × ",
    technology.research_unit_count,
  })
  -- Controls
  if show_controls then
    table.insert(tooltip, { "gui.urq-tooltip-view-details" })
    table.insert(tooltip, { "gui.urq-tooltip-add-to-queue" })
    table.insert(tooltip, { "gui.urq-tooltip-add-to-queue-front" })
    table.insert(tooltip, { "gui.urq-tooltip-remove-from-queue" })
    if script.active_mods["RecipeBook"] then
      table.insert(tooltip, { "gui.urq-tooltip-view-in-recipe-book" })
    end
  end

  return {
    type = "sprite-button",
    name = technology.name,
    style = properties.style,
    tooltip = tooltip,
    tags = { research_state = research_state, tech_name = technology.name, level = level },
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
    (technology.upgrade or util.is_multilevel(technology) or technology.prototype.level > 1) and {
      type = "label",
      name = "level_label",
      style = "urq_technology_slot_level_label_" .. properties.research_state_str,
      caption = level,
      ignored_by_interaction = true,
    } or {},
    util.is_multilevel(technology) and {
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
      visible = progress > 0,
      ignored_by_interaction = true,
    },
  }
end

--- @param elem LuaGuiElement
--- @param value boolean
--- @param sprite_base string
function gui_util.toggle_frame_action_button(elem, sprite_base, value)
  if value then
    elem.style = "flib_selected_frame_action_button"
    elem.sprite = sprite_base .. "_black"
  else
    elem.style = "frame_action_button"
    elem.sprite = sprite_base .. "_white"
  end
end

--- @param self Gui
--- @param elem_table LuaGuiElement
--- @param handler function
--- @param technologies LuaTechnology[]
function gui_util.update_technology_info_sublist(self, elem_table, handler, technologies)
  local selected = self.state.selected or {}
  local research_states = self.force_table.research_states
  local show_controls = self.player.mod_settings["urq-show-control-hints"].value --[[@as boolean]]
  elem_table.clear()
  if #technologies > 0 then
    elem_table.parent.parent.visible = true
    local group_buttons = {}
    for _, technology in pairs(technologies) do
      local button_template = gui_util.technology_slot(
        technology,
        technology.level,
        research_states[technology.name],
        show_controls,
        selected.technology == technology and selected.level == technology.level
      )
      button_template.handler = handler

      table.insert(group_buttons, button_template)
    end
    flib_gui.add(elem_table, group_buttons)
  else
    elem_table.parent.parent.visible = false
  end
end

--- @param button LuaGuiElement
--- @param technology LuaTechnology
--- @param level uint
--- @param research_state ResearchState
--- @param in_queue boolean
--- @param is_selected boolean?
function gui_util.update_technology_slot(button, technology, level, research_state, in_queue, is_selected)
  local properties = gui_util.get_technology_slot_properties(technology, research_state, is_selected)
  local tags = button.tags
  button.style = properties.style
  if tags.research_state ~= research_state then
    if research_state == constants.research_state.researched then
      button.progressbar.visible = false
      button.progressbar.value = 0
    end
    if technology.upgrade or util.is_multilevel(technology) or technology.prototype.level > 1 then
      button.level_label.style = "urq_technology_slot_level_label_" .. properties.research_state_str
    end
    if util.is_multilevel(technology) then
      button.level_range_label.style = "urq_technology_slot_level_range_label_" .. properties.research_state_str
    end
    tags.research_state = research_state --[[@as AnyBasic]]
    button.tags = tags
  end
  if util.is_multilevel(technology) then
    if tags.level ~= level then
      tags.level = level
      button.tags = tags
    end
    local level_label = button.level_label
    if level_label then
      level_label.caption = tostring(level)
    end
  end
  button.duration_label.visible = in_queue
end

return gui_util
