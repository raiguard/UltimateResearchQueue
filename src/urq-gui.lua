local gui = require("__flib__.gui")

--- @class GuiRefs
--- @field window LuaGuiElement
--- @field titlebar_flow LuaGuiElement

--- @class UrqGui
local UrqGui = {}

local M = {}

--- @param sprite string
--- @param action string?
--- @param tooltip LocalisedString?
local function frame_action_button(sprite, action, tooltip)
  return {
    type = "sprite-button",
    style = "frame_action_button",
    tooltip = tooltip,
    sprite = sprite .. "_white",
    hovered_sprite = sprite .. "_black",
    clicked_sprite = sprite .. "_black",
    actions = {
      on_click = action,
    },
  }
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
function M.new(player, player_table)
  --- @type GuiRefs
  local refs = gui.build(player.gui.screen, {
    {
      type = "frame",
      direction = "vertical",
      ref = { "window" },
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
        frame_action_button("utility/search", "toggle_search"),
        frame_action_button("flib_pin", "toggle_pinned"),
        frame_action_button("flib_settings", "toggle_settings"),
        frame_action_button("utility/close", "close", { "gui.close-instruction" }),
      },
      {
        type = "flow",
        style_mods = { horizontal_spacing = 12 },
        {
          type = "frame",
          style = "inside_deep_frame",
          direction = "vertical",
          {
            type = "scroll-pane",
            style = "flib_naked_scroll_pane_no_padding",
            {
              type = "flow",
              style_mods = { vertical_spacing = 0 },
              direction = "vertical",
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
              { type = "sprite-button", style = "red_button", style_mods = { width = 72, height = 100 } },
            },
          },
        },
        {
          type = "flow",
          style_mods = { width = 700, vertical_spacing = 12 },
          direction = "vertical",
          {
            type = "frame",
            style = "inside_shallow_frame",
            direction = "vertical",
            {
              type = "frame",
              style = "subheader_frame",
              {
                type = "label",
                style = "subheader_caption_label",
                caption = "Select a research to show its details",
              },
              { type = "empty-widget", style = "flib_horizontal_pusher" },
            },
            {
              type = "flow",
              style_mods = { padding = 12 },
              { type = "empty-widget", style_mods = { horizontally_stretchable = true, height = 200 } },
            },
          },
          {
            type = "frame",
            style = "inside_deep_frame",
            style_mods = { horizontally_stretchable = true, vertically_stretchable = true },
          },
        },
      },
    },
  })

  refs.titlebar_flow.drag_target = refs.window
  refs.window.force_auto_center()

  --- @type UrqGui
  local self = {
    player = player,
    player_table = player_table,
    refs = refs,
    state = {},
  }
  M.load(self)
  player_table.gui = self
end

function M.load(self)
  setmetatable(self, { __index = UrqGui })
end

return M
