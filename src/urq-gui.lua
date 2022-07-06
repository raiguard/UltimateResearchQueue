local gui = require("__flib__.gui")

local constants = require("constants")

--- @class GuiRefs
--- @field window LuaGuiElement
--- @field titlebar_flow LuaGuiElement
--- @field techs_table LuaGuiElement
--- @field queue_table LuaGuiElement

--- @class UrqGui
local UrqGui = {}

function UrqGui:update()
  --- @type LuaGuiElement[]
  local buttons = {}
  local force_table = global.forces[self.player.force.index]
  for _, tech in pairs(force_table.technologies) do
    local style = "button"
    if tech.state == constants.research_state.researched then
      style = "green_button"
    elseif tech.state == constants.research_state.not_available then
      style = "red_button"
    end
    table.insert(buttons, {
      type = "choose-elem-button",
      name = tech.tech.name,
      style = style,
      style_mods = { width = 72, height = 100 },
      elem_type = "technology",
      technology = tech.tech.name,
      elem_mods = { locked = true },
    })
  end

  local techs_table = self.refs.techs_table
  techs_table.clear()
  gui.build(techs_table, buttons)
end

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
--- @return UrqGui
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
            type = "frame",
            style = "subheader_frame",
            style_mods = { horizontally_stretchable = true },
            { type = "label", style = "subheader_caption_label", caption = "List of technologies" },
          },
          {
            type = "scroll-pane",
            style = "flib_naked_scroll_pane_no_padding",
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
              { type = "label", style = "subheader_caption_label", caption = "Research queue" },
            },
            {
              type = "scroll-pane",
              style = "flib_naked_scroll_pane_no_padding",
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
              { type = "label", style = "subheader_caption_label", caption = "No technology selected" },
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
    },
  })

  refs.titlebar_flow.drag_target = refs.window
  refs.window.force_auto_center()

  --- @class UrqGui
  local self = {
    player = player,
    player_table = player_table,
    refs = refs,
    state = {},
  }
  M.load(self)
  player_table.gui = self

  return self
end

function M.load(self)
  setmetatable(self, { __index = UrqGui })
end

return M
