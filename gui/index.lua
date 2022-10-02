local libgui = require("__flib__.gui")
local math = require("__flib__.math")
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
  local research_state = self.force_table.research_states[tech_name]
  if research_state == util.research_state.researched then
    util.flying_text(self.player, { "message.urq-already-researched" })
    return
  end
  if research_state == util.research_state.not_available then
    -- Add all prerequisites to research this tech ASAP
    local to_research = util.get_unresearched_prerequisites(self.force_table, self.force.technologies[tech_name])
    for i = #to_research, 1, -1 do
      self.force_table.queue:add(to_research[i])
    end
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

-- Updates tech list button visibility based on search query and science pack filters
function gui:filter_tech_list()
  local science_pack_filters = self.state.science_pack_filters
  local query = self.state.search_query
  local dictionaries = self.player_table.dictionaries
  local technologies = game.technology_prototypes
  for _, button in pairs(self.refs.techs_table.children) do
    local tech_name = button.name
    local technology = technologies[tech_name]
    local science_packs_matched = true
    local search_matched = #query == 0
    -- Science pack filters
    for _, ingredient in pairs(technology.research_unit_ingredients) do
      if not science_pack_filters[ingredient.name] then
        science_packs_matched = false
        break
      end
    end
    -- Search query
    if science_packs_matched and not search_matched then
      local to_search = {}
      if dictionaries then
        table.insert(to_search, dictionaries.technology[tech_name])
        for _, effect in pairs(technology.effects) do
          if effect.type == "unlock-recipe" then
            table.insert(to_search, dictionaries.recipe[effect.recipe])
          end
        end
      else
        table.insert(to_search, tech_name)
      end
      for _, str in pairs(to_search) do
        if string.find(string.lower(str), query, 1, true) then
          search_matched = true
          break
        end
      end
    end
    button.visible = science_packs_matched and search_matched
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

function gui:open_in_graph()
  local selected_technology = self.state.selected
  if selected_technology then
    self.state.opening_graph = true
    self.player.open_technology_gui(selected_technology)
    self.state.opening_graph = false
  end
end

function gui:refresh()
  self:refresh_queue()
  -- Tech list
  local technologies = self.force.technologies
  local research_states = self.force_table.research_states
  local selected_technology = self.state.selected
  local groups_by_state = {
    [util.research_state.available] = {},
    [util.research_state.conditionally_available] = {},
    [util.research_state.not_available] = {},
    [util.research_state.researched] = {},
    [util.research_state.disabled] = {},
  }
  for _, prototype in pairs(global.technologies) do
    local research_state = research_states[prototype.name]
    table.insert(groups_by_state[research_state], prototype)
    self.state.research_state_counts[research_state] = (self.state.research_state_counts[research_state] or 0) + 1
  end
  local ordered = {}
  for _, techs in pairs(groups_by_state) do
    for _, tech in pairs(techs) do
      ordered[#ordered + 1] = tech
    end
  end
  --- @type LuaGuiElement[]
  local buttons = {}
  for _, prototype in pairs(ordered) do
    local tech_name = prototype.name
    local research_state = research_states[prototype.name]
    if research_state ~= util.research_state.disabled or prototype.visible_when_disabled then
      table.insert(buttons, self.templates.tech_button(technologies[tech_name], research_state, selected_technology))
    end
  end
  local techs_table = self.refs.techs_table
  techs_table.clear()
  libgui.build(techs_table, buttons)

  self:update_durations_and_progress()
  self:filter_tech_list()
end

function gui:refresh_queue()
  local technologies = self.force.technologies
  local research_states = self.force_table.research_states
  local selected_technology = self.state.selected
  --- @type LuaGuiElement[]
  local queue_buttons = {}
  for _, tech_name in pairs(self.force_table.queue.queue) do
    table.insert(
      queue_buttons,
      self.templates.tech_button(technologies[tech_name], research_states[tech_name], selected_technology)
    )
  end
  local queue_table = self.refs.queue_table
  queue_table.clear()
  libgui.build(queue_table, queue_buttons)
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
      table.parent.scroll_to_element(new_slot)
    end
  end

  -- Tech information

  local technology = self.force.technologies[tech_name]
  local research_state = self.force_table.research_states[tech_name]
  -- Slot
  local main_slot_frame = self.refs.tech_info.main_slot_frame
  main_slot_frame.clear() -- The best thing to do is clear it, otherwise we'd need to diff all the sub-elements
  if tech_name then
    libgui.add(main_slot_frame, self.templates.tech_button(technology, research_state, nil, true))
  end
  -- Name and description
  self.refs.tech_info.name_label.caption = technology.localised_name
  self.refs.tech_info.description_label.caption = technology.localised_description
  -- Ingredients
  local ingredients_table = self.refs.tech_info.ingredients_table
  ingredients_table.clear()
  local ingredients_children = table.map(technology.research_unit_ingredients, function(ingredient)
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
    .. math.round(technology.research_unit_energy / 60, 0.1)
  self.refs.tech_info.ingredients_count_label.caption = "[img=quantity-multiplier] " .. technology.research_unit_count
  -- Effects
  local effects_table = self.refs.tech_info.effects_table
  effects_table.clear()
  libgui.build(effects_table, table.map(technology.effects, self.templates.effect_button))
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

function gui:toggle_science_pack_filter(msg, e)
  local science_pack_name = msg.science_pack
  local science_pack_filters = self.state.science_pack_filters
  science_pack_filters[science_pack_name] = not science_pack_filters[science_pack_name]
  if science_pack_filters[science_pack_name] then
    e.element.style = "flib_slot_button_green"
  else
    e.element.style = "flib_slot_button_default"
  end
  e.element.style.size = 28
  self:filter_tech_list()
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

    local duration = self.force_table.queue.durations[tech_name] or "[img=infinity]"
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
      on_tick_n.add(game.tick + 30, { id = "gui", player_index = self.player.index, action = "filter_tech_list" })
  end
end

--- @param technology LuaTechnology
function gui:update_tech_slot(technology)
  local button = self.refs.techs_table[technology.name]
  if not button then
    gui:refresh()
    return
  end
  local research_state = self.force_table.research_states[technology.name]
  -- Style
  local properties = util.get_technology_slot_properties(technology, research_state, self.state.selected)
  button.style = properties.style
  if properties.leveled then
    button.level_label.style = "urq_technology_slot_level_label_" .. properties.research_state_str
  end
  if properties.ranged then
    button.level_range_label.style = "urq_technology_slot_level_range_label_" .. properties.research_state_str
  end
  -- Position
  local techs_table = self.refs.techs_table
  local order = global.technology_order[technology.name]
  local index = 1
  local group_count = 0
  for state, count in pairs(self.force_table.research_state_counts) do
    if state < research_state then
      index = index + count
    else
      group_count = count
      break
    end
  end
  util.move_to(button, techs_table, #techs_table.children_names + 1)
  local children_names = techs_table.children_names
  for i = index, index + group_count - 1 do
    local tech_name = children_names[i]
    if i == index + group_count - 1 then
      util.move_to(button, techs_table, i)
      break
    elseif order < global.technology_order[tech_name] then
      util.move_to(button, techs_table, i)
      break
    end
  end
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
--- @return Gui
function gui.new(player, player_table)
  --- @type table<string, boolean>
  local science_pack_filters = table.map(
    game.get_filtered_item_prototypes({ { filter = "type", type = "tool" } }),
    function()
      return true
    end
  )

  --- @type GuiRefs
  local refs = libgui.build(player.gui.screen, { gui.templates.base(science_pack_filters) })

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
      opening_graph = false,
      pinned = false,
      research_state_counts = {},
      search_open = false,
      search_query = "",
      science_pack_filters = science_pack_filters,
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
