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

local m = {}

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

function gui:ensure_valid()
  if not self.refs.window.valid then
    self:destroy()
    m.new(self.player, self.player_table)
    self.player.print({ "message.urq-recreated-gui" })
    return true
  end
end

function gui:destroy()
  if self.refs.window.valid then
    self.refs.window.destroy()
  end
  self.player.set_shortcut_toggled("urq-toggle-gui", false)
  self.player_table.gui = nil
end

function gui:dispatch(msg, e)
  if self:ensure_valid() then
    return
  end

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
  if self:ensure_valid() then
    return
  end
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

function gui:refresh_tech_list()
  if self:ensure_valid() then
    return
  end
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

  -- TODO: Don't clear it every time
  local techs_table = self.refs.techs_table
  techs_table.clear()
  libgui.build(techs_table, buttons)

  self:update_tech_list()
end

function gui:show()
  if self:ensure_valid() then
    return
  end
  self.refs.window.visible = true
  if not self.state.pinned then
    self.player.opened = self.refs.window
  end
  self.player.set_shortcut_toggled("urq-toggle-gui", true)
end

function gui:toggle_pinned()
  if self:ensure_valid() then
    return
  end
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
  if self:ensure_valid() then
    return
  end
  self.state.search_open = not self.state.search_open
  toggle_frame_action_button(self.refs.search_button, "utility/search", self.state.search_open)
  self.refs.search_textfield.visible = self.state.search_open
  if self.state.search_open then
    self.refs.search_textfield.focus()
  else
    self.state.search_query = ""
    self.refs.search_textfield.text = ""
    self:refresh_tech_list()
  end
end

function gui:toggle_visible()
  if self:ensure_valid() then
    return
  end
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:update_search_query()
  if self:ensure_valid() then
    return
  end
  self.state.search_query = self.refs.search_textfield.text
  self:update_tech_list()
end

-- Updates tech list button visibility based on search query
function gui:update_tech_list()
  if self:ensure_valid() then
    return
  end
  local query = self.state.search_query
  local is_empty = #query == 0
  for _, button in pairs(self.refs.techs_table.children) do
    -- TODO: Localised search
    -- TODO: Search by effect names
    -- TODO: Filter by science pack
    button.visible = is_empty or string.find(button.name, query, 1, true)
  end
end

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

  self:refresh_tech_list()

  return self
end

function m.load(self)
  setmetatable(self, { __index = gui })
end

return m
