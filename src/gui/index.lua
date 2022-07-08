local libgui = require("__flib__.gui")
local constants = require("constants")

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

--- @class GuiRefs
--- @field window LuaGuiElement
--- @field titlebar_flow LuaGuiElement
--- @field search_button LuaGuiElement
--- @field search_textfield LuaGuiElement
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
  if msg.by_closed_event then
    if self.state.pinned then
      return
    end
    if self.state.search_open then
      self:toggle_search()
      self.player.opened = self.refs.window
      return
    end
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
  toggle_frame_action_button(self.refs.pin_button, "flib_pin", self.state.pinned)
  if self.state.pinned then
    self.player.opened = nil
  else
    self.player.opened = self.refs.window
    self.refs.window.force_auto_center()
  end
end

function gui:toggle_search()
  self.state.search_open = not self.state.search_open
  toggle_frame_action_button(self.refs.search_button, "utility/search", self.state.search_open)
  self.refs.search_textfield.visible = self.state.search_open
  if self.state.search_open then
    self.refs.search_textfield.focus()
  else
    self.state.search_query = ""
    self.refs.search_textfield.text = ""
    self:update_list()
  end
end

function gui:toggle_visible()
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:update_list()
  --- @type LuaGuiElement[]
  local buttons = {}
  local force_table = global.forces[self.player.force.index]
  local query = self.state.search_query
  for _, tech in pairs(force_table.technologies) do
    -- TODO: Localised search
    if string.find(tech.tech.name, query, 1, true) then
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
  end

  -- TODO: Don't clear it every time
  local techs_table = self.refs.techs_table
  techs_table.clear()
  libgui.build(techs_table, buttons)
end

function gui:update_search_query()
  self.state.search_query = self.refs.search_textfield.text
  self:update_list()
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
    state = {
      pinned = false,
      search_open = false,
      search_query = "",
    },
  }
  m.load(self)
  player_table.gui = self

  return self
end

function m.load(self)
  setmetatable(self, { __index = gui })
end

return m
