local math = require("__flib__.math")
local table = require("__flib__.table")

local sort_techs = require("__UltimateResearchQueue__.sort-techs")
local util = require("__UltimateResearchQueue__.util")

local templates = {}

--- @param science_pack_filters table<string, boolean>
--- @return GuiBuildStructure
function templates.base(science_pack_filters)
  local science_pack_table = {
    type = "table",
    column_count = 9,
  }
  for name, enabled in pairs(science_pack_filters) do
    table.insert(science_pack_table, {
      type = "sprite-button",
      style = enabled and "flib_slot_button_green" or "flib_slot_button_default",
      style_mods = { size = 28 },
      sprite = "item/" .. name,
      tooltip = game.item_prototypes[name].localised_name,
      actions = {
        on_click = { action = "toggle_science_pack_filter", science_pack = name },
      },
    })
  end
  local multi_row_header = #science_pack_table > 9
  if multi_row_header then
    science_pack_table.column_count = 17
  end
  return {
    type = "frame",
    name = "urq-window",
    direction = "vertical",
    visible = false,
    ref = { "window" },
    actions = { on_closed = { action = "hide", by_closed_event = true } },
    {
      type = "flow",
      style = "flib_titlebar_flow",
      ref = { "titlebar_flow" },
      actions = {
        on_click = "handle_titlebar_click",
      },
      {
        type = "label",
        style = "frame_title",
        caption = { "gui-technology-progress.title" },
        ignored_by_interaction = true,
      },
      { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
      {
        type = "textfield",
        style = "urq_search_textfield",
        visible = false,
        clear_and_focus_on_right_click = true,
        ref = { "search_textfield" },
        actions = {
          on_text_changed = "update_search_query",
        },
      },
      templates.frame_action_button(
        "utility/search",
        "toggle_search",
        { "gui.urq-search-instruction" },
        { "search_button" }
      ),
      templates.frame_action_button("flib_pin", "toggle_pinned", { "gui.flib-keep-open" }, { "pin_button" }),
      templates.frame_action_button("utility/close", "hide", { "gui.close-instruction" }, { "close_button" }),
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
          },
          {
            type = "scroll-pane",
            style = "urq_tech_list_scroll_pane",
            style_mods = { height = 100 * 2, horizontally_stretchable = true },
            vertical_scroll_policy = "auto-and-reserve-space",
            refs = { "queue_scroll_pane" },
            {
              type = "table",
              style = "technology_slot_table",
              column_count = 7,
              ref = { "queue_table" },
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
              style = "subheader_caption_label",
              caption = { "gui.urq-no-technology-selected" },
              ref = { "tech_info", "name_label" },
            },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "button", style = "tool_button", actions = { on_click = "open_in_graph" } },
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
                style = "deep_frame_in_shallow_frame",
                ref = { "tech_info", "main_slot_frame" },
              },
              {
                type = "flow",
                direction = "vertical",
                {
                  type = "label",
                  style_mods = { single_line = false, horizontally_stretchable = true },
                  caption = "",
                  ref = { "tech_info", "description_label" },
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
                { type = "table", column_count = 12, ref = { "tech_info", "ingredients_table" } },
              },
              {
                type = "flow",
                style_mods = { vertical_spacing = -2, padding = 0, top_padding = -4 },
                direction = "vertical",
                { type = "label", style = "count_label", ref = { "tech_info", "ingredients_count_label" } },
                { type = "label", style = "count_label", ref = { "tech_info", "ingredients_time_label" } },
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
              style_mods = { horizontal_spacing = 8 },
              column_count = 12,
              ref = { "tech_info", "effects_table" },
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
          style_mods = { horizontally_stretchable = true, height = 0 },
          direction = "vertical",
          multi_row_header and {
            type = "flow",
            science_pack_table,
            { type = "line", direction = "vertical" },
            { type = "sprite-button", style = "tool_button" },
          } or {},
          multi_row_header and { type = "line", style = "flib_subheader_horizontal_line" } or {},
          {
            type = "flow",
            style = "centering_horizontal_flow",
            { type = "label", style = "subheader_caption_label", caption = { "gui-technologies-list.title" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            not multi_row_header and science_pack_table or {},
            not multi_row_header and { type = "line", direction = "vertical" } or {},
            { type = "sprite-button", style = "tool_button" },
            { type = "sprite-button", style = "flib_tool_button_light_green" },
          },
        },
        {
          type = "scroll-pane",
          style = "urq_tech_list_scroll_pane",
          style_mods = { horizontally_stretchable = true, height = 100 * 7, width = 72 * 8 + 12 },
          ref = { "techs_scroll_pane" },
          vertical_scroll_policy = "auto-and-reserve-space",
          { type = "table", style = "technology_slot_table", column_count = 8, ref = { "techs_table" } },
        },
      },
    },
  }
end

--- @param effect TechnologyModifier
function templates.effect_button(effect)
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
    local format = util.effect_display_type[effect.type]
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

  --- @type string|GuiBuildStructure
  local overlay_constant = util.overlay_constant[effect.type]
  if overlay_constant then
    overlay_constant =
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
    overlay_constant,
  }
end

--- @param sprite string
--- @param action string?
--- @param tooltip LocalisedString?
--- @return GuiBuildStructure
function templates.frame_action_button(sprite, action, tooltip, ref)
  return {
    type = "sprite-button",
    style = "frame_action_button",
    tooltip = tooltip,
    sprite = sprite .. "_white",
    hovered_sprite = sprite .. "_black",
    clicked_sprite = sprite .. "_black",
    ref = ref,
    actions = {
      on_click = action,
    },
  }
end

--- @param tech TechnologyWithResearchState
--- @param selected_name string?
--- @param ignored_by_interaction boolean?
--- @return GuiBuildStructure
function templates.tech_button(tech, selected_name, ignored_by_interaction)
  local state = table.find(sort_techs.research_state, tech.state)
  local selected = selected_name == tech.tech.name
  local leveled = tech.tech.upgrade or tech.tech.level > 1

  local max_level = tech.tech.prototype.max_level
  local ranged = tech.tech.prototype.level ~= max_level
  local leveled = leveled or ranged
  local max_level_str = max_level == math.max_uint and "[img=infinity]" or tostring(max_level)

  local progress = util.get_research_progress(tech.tech)

  local ingredients = {}
  local ingredients_len = 0
  for i, ingredient in pairs(tech.tech.research_unit_ingredients) do
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

  return {
    type = "sprite-button",
    name = tech.tech.name,
    style = "urq_technology_slot_" .. (selected and "selected_" or "") .. (leveled and "leveled_" or "") .. state,
    tooltip = tech.tech.localised_name,
    ignored_by_interaction = ignored_by_interaction,
    actions = {
      on_click = "handle_tech_click",
    },
    {
      type = "flow",
      style = "urq_technology_slot_sprite_flow",
      ignored_by_interaction = true,
      {
        type = "sprite",
        style = "urq_technology_slot_sprite",
        sprite = "technology/" .. tech.tech.name,
      },
    },
    leveled and {
      type = "label",
      style = "urq_technology_slot_level_label_" .. state,
      caption = tech.tech.level,
      ignored_by_interaction = true,
    } or {},
    ranged and {
      type = "label",
      style = "urq_technology_slot_level_range_label_" .. state,
      caption = tech.tech.prototype.level .. " - " .. max_level_str,
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

return templates
