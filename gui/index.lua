local libgui = require("__flib__.gui")
local math = require("__flib__.math")
local misc = require("__flib__.misc")
local on_tick_n = require("__flib__.on-tick-n")
local table = require("__flib__.table")

local util = require("__UltimateResearchQueue__.util")

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
--- @field techs_scroll_pane LuaGuiElement
--- @field techs_table LuaGuiElement
--- @field queue_scroll_pane LuaGuiElement
--- @field queue_table LuaGuiElement
--- @field tech_info TechInfoRefs
--- @class TechInfoRefs
--- @field tutorial_flow LuaGuiElement
--- @field name_label LuaGuiElement
--- @field main_slot_frame LuaGuiElement
--- @field description_label LuaGuiElement
--- @field ingredients_table LuaGuiElement
--- @field ingredients_count_label LuaGuiElement
--- @field ingredients_time_label LuaGuiElement
--- @field effects_table LuaGuiElement

--- @class Gui
local gui = {}
gui.templates = require("__UltimateResearchQueue__.gui.templates")

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

-- Updates tech list button visibility based on search query
function gui:filter_tech_list()
  local query = self.state.search_query
  local is_empty = #query == 0
  for _, button in pairs(self.refs.techs_table.children) do
    if is_empty then
      button.visible = true
    else
      -- TODO: Filter by science pack
      local tech_name = button.name
      if self.player_table.dictionaries then
        tech_name = self.player_table.dictionaries.technology_search[tech_name]
      end
      button.visible = string.find(string.lower(tech_name), query, 1, true) and true or false
    end
  end
end

function gui:handle_tech_click(_, e)
  local tech_name = e.element.name
  if e.button == defines.mouse_button_type.right then
    self.force_table.queue:remove(tech_name)
    return
  end
  if util.is_double_click(e.element) then
    self:add_to_queue(tech_name)
    return
  end
  self:select_tech(tech_name)
end

--- @param e on_gui_click
function gui:handle_titlebar_click(_, e)
  if e.button == defines.mouse_button_type.middle then
    self.refs.window.force_auto_center()
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
  end
  if self.player.opened_gui_type == defines.gui_type.custom and self.player.opened == self.refs.window then
    self.player.opened = nil
  end
  self.refs.window.visible = false
end

function gui:refresh()
  local force_technologies = self.force_table.technologies
  local selected_technology = self.state.selected
  -- Queue
  --- @type LuaGuiElement[]
  local queue_buttons = {}
  for _, tech_name in pairs(self.force_table.queue.queue) do
    table.insert(queue_buttons, self.templates.tech_button(force_technologies[tech_name], selected_technology))
  end
  local queue_table = self.refs.queue_table
  queue_table.clear()
  libgui.build(queue_table, queue_buttons)
  -- Tech list
  --- @type LuaGuiElement[]
  local buttons = {}
  for _, tech in pairs(force_technologies) do
    if tech.state ~= util.research_state.disabled or tech.tech.visible_when_disabled then
      table.insert(buttons, self.templates.tech_button(tech, selected_technology))
    end
  end
  local techs_table = self.refs.techs_table
  techs_table.clear()
  libgui.build(techs_table, buttons)

  self:update_durations_and_progress()
  self:filter_tech_list()
end

--- @param tech_name string
function gui:select_tech(tech_name)
  local former_selected = self.state.selected
  if former_selected == tech_name then
    return
  end
  self.state.selected = tech_name

  -- Queue and techs list
  for _, table in pairs({ self.refs.queue_table, self.refs.techs_table }) do
    if former_selected then
      local former_slot = table[former_selected]
      if former_slot then
        former_slot.style = string.gsub(former_slot.style.name, "selected_", "")
      end
    end
    local new_slot = table[tech_name]
    if new_slot then
      new_slot.style = string.gsub(new_slot.style.name, "urq_technology_slot_", "urq_technology_slot_selected_")
    end
  end

  -- Tech information

  local tech_data = self.force_table.technologies[tech_name]
  -- Slot
  local main_slot_frame = self.refs.tech_info.main_slot_frame
  main_slot_frame.clear() -- The best thing to do is clear it, otherwise we'd need to diff all the sub-elements
  if tech_name then
    libgui.add(main_slot_frame, self.templates.tech_button(tech_data, nil, true))
  end
  -- Name and description
  self.refs.tech_info.name_label.caption = tech_data.tech.localised_name
  self.refs.tech_info.description_label.caption = tech_data.tech.localised_description
  -- Ingredients
  local ingredients_table = self.refs.tech_info.ingredients_table
  ingredients_table.clear()
  local ingredients_children = table.map(tech_data.tech.research_unit_ingredients, function(ingredient)
    return {
      type = "sprite-button",
      style = "transparent_slot",
      sprite = "item/" .. ingredient.name,
      number = ingredient.amount,
      tooltip = game.item_prototypes[ingredient.name].localised_name,
    }
  end)
  libgui.build(ingredients_table, ingredients_children)
  self.refs.tech_info.ingredients_time_label.caption = "[img=quantity-time] "
    .. math.round(tech_data.tech.research_unit_energy / 60, 0.1)
  self.refs.tech_info.ingredients_count_label.caption = "[img=quantity-multiplier] "
    .. tech_data.tech.research_unit_count
  -- Effects
  local effects_table = self.refs.tech_info.effects_table
  effects_table.clear()
  local effects_children = table.map(tech_data.tech.effects, function(effect)
    --- @cast effect TechnologyModifier
    local sprite = "utility/" .. string.gsub(effect.type, "%-", "_") .. "_modifier_icon"
    if effect.type == "unlock-recipe" then
      sprite = "recipe/" .. effect.recipe
    end
    return {
      type = "sprite-button",
      style = "transparent_slot",
      sprite = sprite,
    }
  end)
  libgui.build(effects_table, effects_children)
end

--- @param select_tech string?
function gui:show(select_tech)
  if select_tech then
    self:select_tech(select_tech)
  end
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
    self:filter_tech_list()
  end
end

function gui:toggle_visible()
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:update_durations_and_progress()
  local queue_table = self.refs.queue_table
  local techs_table = self.refs.techs_table
  for _, tech_name in pairs(self.force_table.queue.queue) do
    local queue_button = queue_table[tech_name]
    local techs_button = techs_table[tech_name]
    if not queue_button or not techs_button then
      goto continue
    end

    local duration = self.force_table.queue.durations[tech_name] or misc.ticks_to_timestring(0)
    if queue_button then
      queue_button.duration_label.caption = duration
    end
    techs_button.duration_label.caption = duration

    local progress = util.get_research_progress(self.force.technologies[tech_name])
    if queue_button then
      queue_button.progressbar.value = progress
      queue_button.progressbar.visible = progress > 0
    end
    techs_button.progressbar.value = progress
    techs_button.progressbar.visible = progress > 0
  end
  ::continue::
end

function gui:update_search_query()
  self.state.search_query = self.refs.search_textfield.text

  local update_job = self.state.update_job
  if update_job then
    on_tick_n.remove(update_job)
  end

  if game.tick_paused or #self.state.search_query == 0 then
    self:filter_tech_list()
  else
    self.state.update_job =
      on_tick_n.add(game.tick + 30, { id = "gui", player_index = self.player.index, action = "update_tech_list" })
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
