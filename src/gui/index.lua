local libgui = require("__flib__.gui")
local constants = require("constants")

--- @class GuiRefs
--- @field window LuaGuiElement
--- @field titlebar_flow LuaGuiElement
--- @field pin_button LuaGuiElement
--- @field techs_table LuaGuiElement
--- @field queue_table LuaGuiElement

--- @class Gui
local gui = {}
gui.templates = require("gui.templates")

function gui:dispatch(msg, e)
  if type(msg) == "string" then
    msg = { action = msg }
  end
  local handler = self[msg.action]
  if handler then
    handler(self, msg, e)
  else
    log("Unknown GUI event handler: " .. msg.action)
  end
end

function gui:hide(msg)
  if msg.by_closed_event and self.state.pinned then
    return
  elseif not msg.by_closed_event then
    self.player.opened = nil
  end
  self.refs.window.visible = false
  self.player.set_shortcut_toggled("urq-toggle-gui", false)
end

function gui:show()
  self.refs.window.visible = true
  if not self.state.pinned then
    self.player.opened = self.refs.window
  end
  self.player.set_shortcut_toggled("urq-toggle-gui", true)
end

function gui:toggle_pinned()
  self.state.pinned = not self.state.pinned
  if self.state.pinned then
    self.player.opened = nil
    self.refs.pin_button.style = "flib_selected_frame_action_button"
    self.refs.pin_button.sprite = "flib_pin_black"
  else
    self.player.opened = self.refs.window
    self.refs.pin_button.style = "frame_action_button"
    self.refs.pin_button.sprite = "flib_pin_white"
    self.refs.window.force_auto_center()
  end
end

function gui:toggle_visible()
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:update()
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
  libgui.build(techs_table, buttons)
end

local m = {}

--- @param player LuaPlayer
--- @param player_table PlayerTable
--- @return Gui
function m.new(player, player_table)
  --- @type GuiRefs
  local refs = libgui.build(player.gui.screen, { gui.templates.base() })

  refs.titlebar_flow.drag_target = refs.window
  refs.window.force_auto_center()

  --- @class Gui
  local self = {
    player = player,
    player_table = player_table,
    refs = refs,
    state = {},
  }
  m.load(self)
  player_table.gui = self

  return self
end

function m.load(self)
  setmetatable(self, { __index = gui })
end

return m
