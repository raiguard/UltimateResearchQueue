data:extend({
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
