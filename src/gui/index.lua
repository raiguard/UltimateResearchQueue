local libgui = require("__flib__.gui")
local on_tick_n = require("__flib__.on-tick-n")
local table = require("__flib__.table")

local util = require("util")

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
--- @field close_button LuaGuiElement
--- @field techs_table LuaGuiElement
--- @field queue_table LuaGuiElement
--- @field tech_info TechInfoRefs
--- @class TechInfoRefs
--- @field name_label LuaGuiElement

--- @class Gui
local gui = {}
gui.templates = require("gui.templates")

--- @param tech_name string
--- @param position integer?
function gui:add_to_queue(tech_name, position)
  local tech_data = self.force_table.technologies[tech_name]
  if tech_data.state == util.research_state.researched then
    util.flying_text(self.player, { "message.urq-already-researched" })
    return
  end
  if tech_data.state == util.research_state.not_available then
    util.flying_text(self.player, "Not yet implemented")
    return
  end
  if not self.force_table.queue:add(tech_name, position) then
    util.flying_text(self.player, { "message.urq-already-in-queue" })
    return
  end
end

function gui:cancel_research(_, e)
  local tech_name = e.element.name
  self.force_table.queue:remove(tech_name)
end

function gui:destroy()
  if self.refs.window.valid then
    self.refs.window.destroy()
  end
  self.player_table.gui = nil
end

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

function gui:handle_tech_click(_, e)
  local tech_name = e.element.name
  if e.button == defines.mouse_button_type.right then
    self.force_table.queue:remove(tech_name)
    return
  end
  if e.shift then
    self:add_to_queue(tech_name)
    return
  end
  self.state.selected = tech_name
  self:refresh()
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
  end
  if self.player.opened_gui_type == defines.gui_type.custom and self.player.opened == self.refs.window then
    self.player.opened = nil
  end
  self.refs.window.visible = false
end

function gui:refresh()
  -- Queue

  --- @type LuaGuiElement[]
  local queue_buttons = {}
  for _, tech_name in pairs(self.force_table.queue.queue) do
    table.insert(
      queue_buttons,
      self.templates.tech_button(self.force_table.technologies[tech_name], self.state.selected)
    )
  end
  -- TODO: Don't clear it every time
  local queue_table = self.refs.queue_table
  queue_table.clear()
  libgui.build(queue_table, queue_buttons)

  -- Tech list

  --- @type LuaGuiElement[]
  local buttons = {}
  local force_table = global.forces[self.player.force.index]
  for _, tech in pairs(force_table.technologies) do
    if tech.state ~= util.research_state.disabled or tech.tech.visible_when_disabled then
      table.insert(buttons, self.templates.tech_button(tech, self.state.selected))
    end
  end
  -- TODO: Don't clear it every time
  local techs_table = self.refs.techs_table
  techs_table.clear()
  libgui.build(techs_table, buttons)

  self:update_tech_list()

  -- Tech information

  local name_label = { "gui.urq-no-technology-selected" }
  local selected_tech = self.state.selected
  if selected_tech then
    name_label = self.force_table.technologies[self.state.selected].tech.localised_name
  end
  self.refs.tech_info.name_label.caption = name_label
end

function gui:show()
  self:refresh()
  self.refs.window.visible = true
  self.refs.window.bring_to_front()
  if not self.state.pinned then
    self.player.opened = self.refs.window
  end
end

function gui:toggle_pinned()
  self.state.pinned = not self.state.pinned
  toggle_frame_action_button(self.refs.pin_button, "flib_pin", self.state.pinned)
  if self.state.pinned then
    self.player.opened = nil
    self.refs.search_button.tooltip = { "gui.search" }
    self.refs.close_button.tooltip = { "gui.close" }
  else
    self.player.opened = self.refs.window
    self.refs.window.force_auto_center()
    self.refs.search_button.tooltip = { "gui.urq-search-instruction" }
    self.refs.close_button.tooltip = { "gui.close-instruction" }
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
    self:update_tech_list()
  end
end

function gui:toggle_visible()
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:update_search_query()
  self.state.search_query = self.refs.search_textfield.text

  local update_job = self.state.update_job
  if update_job then
    on_tick_n.remove(update_job)
  end

  if game.tick_paused or #self.state.search_query == 0 then
    self:update_tech_list()
  else
    self.state.update_job =
      on_tick_n.add(game.tick + 30, { id = "gui", player_index = self.player.index, action = "update_tech_list" })
  end
end

-- Updates tech list button visibility based on search query
function gui:update_tech_list()
  local query = self.state.search_query
  local is_empty = #query == 0
  for _, button in pairs(self.refs.techs_table.children) do
    -- TODO: Search by effect names
    -- TODO: Filter by science pack
    local tech_name = button.name
    if self.player_table.dictionaries then
      tech_name = self.player_table.dictionaries.technology_search[tech_name]
    end
    button.visible = is_empty or string.find(string.lower(tech_name), query, 1, true)
  end
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
--- @return Gui
function gui.new(player, player_table)
  --- @type GuiRefs
  local refs = libgui.build(player.gui.screen, { gui.templates.base() })

  refs.titlebar_flow.drag_target = refs.window
  refs.window.force_auto_center()

  local force = player.force --[[@as LuaForce]]

  --- @class Gui
  local self = {
    force = force,
    force_table = global.forces[player.force.index],
    player = player,
    player_table = player_table,
    refs = refs,
    state = {
      pinned = false,
      search_open = false,
      search_query = "",
      --- @type string?
      selected = nil,
    },
  }
  gui.load(self)
  player_table.gui = self

  self:refresh()

  return self
end

function gui.load(self)
  setmetatable(self, { __index = gui })
end

return gui
