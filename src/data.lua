data:extend({
  {
    type = "custom-input",
    name = "urq-focus-search",
    key_sequence = "",
    linked_game_control = "focus-search",
  },
  -- TODO: Make this optional
  {
    type = "custom-input",
    name = "urq-toggle-gui",
    key_sequence = "",
    linked_game_control = "open-technology-gui",
    consuming = "game-only",
  },
  {
    type = "shortcut",
    name = "urq-toggle-gui",
    action = "lua",
    associated_control_input = "urq-toggle-gui",
    icon = { filename = "__core__/graphics/empty.png", size = 1, scale = 32, flags = { "gui-icon" } },
    toggleable = true,
  },
})

local styles = data.raw["gui-style"].default

styles.urq_technology_slot_available = {
  type = "button_style",
  default_graphical_set = {
    filename = "__UltimateResearchQueue__/graphics/technology-slots.png",
    position = { 0, 0 },
    size = { 144, 200 },
  },
  hovered_graphical_set = {
    filename = "__UltimateResearchQueue__/graphics/technology-slots.png",
    position = { 144, 0 },
    size = { 144, 200 },
  },
  clicked_graphical_set = {
    filename = "__UltimateResearchQueue__/graphics/technology-slots.png",
    position = { 144, 0 },
    size = { 144, 200 },
  },
  disabled_graphical_set = {
    filename = "__UltimateResearchQueue__/graphics/technology-slots.png",
    position = { 144, 0 },
    size = { 144, 200 },
  },
  bottom_padding = 32,
  size = { 72, 100 },
  left_click_sound = { filename = "__core__/sound/gui-square-button-large.ogg", volume = 1 },
}

styles.urq_tech_list_scroll_pane = {
  type = "scroll_pane_style",
  parent = "flib_naked_scroll_pane_no_padding",
  background_graphical_set = styles.technology_list_scroll_pane.background_graphical_set,
}

styles.urq_search_textfield = {
  type = "textbox_style",
  top_margin = -3,
  right_padding = 3,
}

styles.urq_invalid_search_textfield = {
  type = "textbox_style",
  parent = "invalid_value_textfield",
  top_margin = -3,
  right_padding = 3,
}
