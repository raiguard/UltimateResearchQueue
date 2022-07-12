local table = require("__flib__.table")
local constants = require("constants")

local templates = {}

--- @return GuiBuildStructure
function templates.base()
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
        on_click = "recenter_if_middle",
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
          style = "urq_tech_list_scroll_pane",
          style_mods = { horizontally_stretchable = true, height = 100 * 7, width = 72 * 8 + 12 },
          vertical_scroll_policy = "auto-and-reserve-space",
          { type = "table", style = "technology_slot_table", column_count = 8, ref = { "techs_table" } },
        },
      },
      {
        type = "flow",
        style_mods = { vertical_spacing = 12 },
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
            style_mods = { width = 72 * 7 + 12, height = 100 * 2 },
            vertical_scroll_policy = "auto-and-reserve-space",
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
          },
          {
            type = "flow",
            style_mods = {
              horizontally_stretchable = true,
              vertically_stretchable = true,
              horizontal_align = "center",
              vertical_align = "center",
            },
            { type = "label", caption = "Technology info here..." },
          },
        },
      },
    },
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

--- @param tech ToShow
--- @param selected_name string?
--- @return GuiBuildStructure
function templates.tech_button(tech, selected_name)
  local state = table.find(constants.research_state, tech.state)
  local selected = selected_name == tech.tech.name
  local leveled = tech.tech.upgrade or tech.tech.level > 1
  return {
    type = "sprite-button",
    name = tech.tech.name,
    style = "urq_technology_slot_" .. (selected and "selected_" or "") .. (leveled and "leveled_" or "") .. state,
    tooltip = tech.tech.localised_name,
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
  }
end

--- @param tech ToShow
--- @param selected_name string?
--- @return GuiBuildStructure
function templates.tech_button_with_controls(tech, selected_name)
  local base = templates.tech_button(tech, selected_name)
  table.insert(base, {
    type = "frame",
    style = "urq_technology_slot_overlay",
    { type = "label", style = "urq_technology_slot_eta_label", caption = "0:42" },
    {
      type = "sprite-button",
      name = tech.tech.name,
      style = "urq_technology_slot_cancel_button",
      sprite = "urq-technology-slot-close",
      hovered_sprite = "urq-technology-slot-close-hovered",
      clicked_sprite = "urq-technology-slot-close-hovered",
      actions = {
        on_click = "cancel_research",
      },
    },
  })
  return base
end

return templates
