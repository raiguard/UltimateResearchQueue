local libgui = require("__flib__.gui")
local math = require("__flib__.math")
local on_tick_n = require("__flib__.on-tick-n")
local table = require("__flib__.table")

local constants = require("__UltimateResearchQueue__.constants")
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
--- @field queue_population_label LuaGuiElement
--- @field queue_pause_button LuaGuiElement
--- @field queue_trash_button LuaGuiElement
--- @field queue_scroll_pane LuaGuiElement
--- @field queue_table LuaGuiElement
--- @field tech_info TechInfoRefs
--- @field tech_info_footer TechInfoFooterRefs
--- @class TechInfoRefs
--- @field tutorial_flow LuaGuiElement
--- @field name_label LuaGuiElement
--- @field main_slot_frame LuaGuiElement
--- @field description_label LuaGuiElement
--- @field ingredients_table LuaGuiElement
--- @field ingredients_count_label LuaGuiElement
--- @field ingredients_time_label LuaGuiElement
--- @field effects_table LuaGuiElement
--- @class TechInfoFooterRefs
--- @field frame LuaGuiElement
--- @field progressbar LuaGuiElement
--- @field pusher LuaGuiElement
--- @field cancel_button LuaGuiElement
--- @field start_button LuaGuiElement
--- @field unresearch_button LuaGuiElement

--- @class Gui
local gui = {}
gui.templates = require("__UltimateResearchQueue__.gui.templates")

function gui:cancel_research(_, e)
  local tech_name = e.element.name
  self.force_table.queue:remove(tech_name)
  self:update_tech_info_footer()
end

function gui:clear_queue()
  local queue = self.force_table.queue
  local tech_name = next(queue.queue)
  while tech_name do
    queue:remove(tech_name)
    tech_name = next(queue.queue)
  end
  self:update_tech_info_footer()
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

-- Updates tech list button visibility based on search query and other settings
function gui:filter_tech_list()
  local query = self.state.search_query
  local dictionaries = self.player_table.dictionaries
  local technologies = game.technology_prototypes
  local research_states = self.force_table.research_states
  local show_disabled = self.player.mod_settings["urq-show-disabled-techs"].value
  for _, button in pairs(self.refs.techs_table.children) do
    local tech_name = button.name
    local technology = technologies[tech_name]
    -- Show/hide disabled
    local research_state_matched = true
    local research_state = research_states[tech_name]
    if research_state == constants.research_state.disabled and not show_disabled then
      research_state_matched = false
    end
    -- Search query
    local search_matched = #query == 0 -- Automatically pass search on empty query
    if research_state_matched and not search_matched then
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
    button.visible = research_state_matched and search_matched
  end
end

function gui:handle_start_research_click(_, e)
  local selected = self.state.selected
  if not selected then
    return
  end
  self:start_research(selected, e.control and util.is_cheating(self.player))
end

function gui:handle_tech_slot_click(_, e)
  if DEBUG then
    log("tech clicked: " .. e.element.name)
  end
  local tech_name = e.element.name
  if e.button == defines.mouse_button_type.right then
    self.force_table.queue:remove(tech_name)
    return
  end
  if util.is_double_click(e.element) then
    self:start_research(tech_name)
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
  if self.state.opening_graph then
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
        table.parent.scroll_to_element(former_slot)
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
  -- Footer
  self:update_tech_info_footer()
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

--- @param tech_name string
--- @param instant_research boolean?
function gui:start_research(tech_name, instant_research)
  local research_state = self.force_table.research_states[tech_name]
  if research_state == constants.research_state.researched then
    util.flying_text(self.player, { "message.urq-already-researched" })
    return
  end
  local to_research
  if research_state == constants.research_state.not_available then
    -- Add all prerequisites to research this tech ASAP
    to_research = util.get_unresearched_prerequisites(self.force_table, self.force.technologies[tech_name])
  else
    to_research = { tech_name }
  end
  if instant_research then
    local technologies = self.force.technologies
    for _, tech_name in pairs(to_research) do
      local technology = technologies[tech_name]
      if not technology.researched then
        technology.researched = true
      end
    end
  else
    local push_error = self.force_table.queue:push(to_research)
    if push_error == constants.queue_push_error.already_in_queue then
      util.flying_text(self.player, { "message.urq-already-in-queue" })
    elseif push_error == constants.queue_push_error.queue_full then
      util.flying_text(self.player, { "message.urq-queue-is-full" })
    elseif push_error == constants.queue_push_error.too_many_prerequisites then
      util.flying_text(self.player, { "message.urq-too-many-unresearched-prerequisites" })
    elseif push_error == constants.queue_push_error.too_many_prerequisites_queue_full then
      util.flying_text(self.player, { "message.urq-too-many-prerequisites-queue-full" })
    end
  end
  self:update_tech_info_footer()
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

function gui:toggle_queue_paused()
  self.force_table.queue:toggle_paused()
end

function gui:toggle_visible()
  if self.refs.window.visible then
    self:hide({})
  else
    self:show()
  end
end

function gui:unresearch()
  local selected = self.state.selected
  if not selected then
    return
  end

  local function propagate(technologies, technology)
    local requisites = global.technology_requisites[technology.name]
    if requisites then
      for requisite_name in pairs(requisites) do
        local requisite = technologies[requisite_name]
        if requisite.researched then
          propagate(technologies, requisite)
        end
      end
    end
    technology.researched = false
  end

  propagate(self.force.technologies, self.force.technologies[selected])
end

function gui:update_durations_and_progress()
  local queue_table = self.refs.queue_table
  local techs_table = self.refs.techs_table
  for tech_name, duration in pairs(self.force_table.queue.queue) do
    local queue_button = queue_table[tech_name]
    local techs_button = techs_table[tech_name]
    if not queue_button or not techs_button then
      goto continue
    end
    queue_button.duration_label.caption = duration
    techs_button.duration_label.caption = duration

    local progress = util.get_research_progress(self.force.technologies[tech_name])
    queue_button.progressbar.value = progress
    queue_button.progressbar.visible = progress > 0
    techs_button.progressbar.value = progress
    techs_button.progressbar.visible = progress > 0

    ::continue::
  end
  self:update_tech_info_footer(true)
end

function gui:update_queue()
  local profiler = game.create_profiler()

  local paused = self.force_table.queue.paused
  local pause_button = self.refs.queue_pause_button
  if paused then
    pause_button.style = "flib_selected_tool_button"
    pause_button.tooltip = { "gui.urq-resume-queue" }
  else
    pause_button.style = "tool_button"
    pause_button.tooltip = { "gui.urq-pause-queue" }
  end

  self.refs.queue_trash_button.enabled = next(self.force_table.queue.queue) and true or false

  self.refs.queue_population_label.caption =
    { "gui.urq-queue-population", self.force_table.queue.len, constants.queue_limit }

  local queue = self.force_table.queue.queue
  local queue_table = self.refs.queue_table
  local research_states = self.force_table.research_states
  local technologies = self.force.technologies
  local i = 0
  for tech_name in pairs(queue) do
    i = i + 1
    local button = queue_table[tech_name]
    if button then
      util.move_to(button, queue_table, i)
      util.update_tech_slot_style(button, technologies[tech_name], research_states[tech_name], self.state.selected)
    else
      local button_template =
        self.templates.tech_button(technologies[tech_name], research_states[tech_name], self.state.selected)
      button_template.index = i
      libgui.add(queue_table, button_template)
    end
  end
  local children = queue_table.children
  for i = i + 1, #children do
    children[i].destroy()
  end
  profiler.stop()
  if DEBUG then
    log({ "", "update_queue ", profiler })
  end
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

--- @param progress_only boolean?
function gui:update_tech_info_footer(progress_only)
  local selected = self.state.selected
  if not selected then
    return
  end

  local elems = self.refs.tech_info_footer
  local research_state = self.force_table.research_states[selected]
  local researched = research_state == constants.research_state.researched
  local in_queue = self.force_table.queue:contains(selected)
  local progress = util.get_research_progress(self.force.technologies[selected])
  local is_cheating = util.is_cheating(self.player)

  elems.frame.visible = not (researched and not is_cheating)

  local progressbar = elems.progressbar
  progressbar.visible = progress > 0
  elems.pusher.visible = progress == 0
  if in_queue then
    progressbar.value = progress
    progressbar.caption =
      { "", self.force_table.queue.queue[selected], " - ", { "format-percent", math.round(progress * 100) } }
  end

  if not progress_only then
    elems.start_button.visible = not researched and not in_queue
    elems.cancel_button.visible = not researched and in_queue
    elems.cancel_button.name = selected
    elems.unresearch_button.visible = researched and is_cheating
  end
end

function gui:update_tech_list()
  local profiler = game.create_profiler()
  local techs_table = self.refs.techs_table
  local research_states = self.force_table.research_states
  local i = 0
  for group_state, group in pairs(self.force_table.grouped_technologies) do
    -- XXX: This will only iterate the first 1024 techs of a group in order. Oh well!
    for _, technology in pairs(group) do
      i = i + 1
      local button = techs_table[technology.name]
      if button then
        util.move_to(button, techs_table, i)
        util.update_tech_slot_style(button, technology, group_state, self.state.selected)
      else
        local button_template =
          self.templates.tech_button(technology, research_states[technology.name], self.state.selected)
        button_template.index = i
        libgui.add(techs_table, button_template)
      end
    end
  end
  local children = techs_table.children
  for i = i + 1, #children do
    children[i].destroy()
  end
  profiler.stop()
  if DEBUG then
    log({ "", "update_tech_list ", profiler })
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
      opening_graph = false,
      pinned = false,
      research_state_counts = {},
      search_open = false,
      search_query = "",
      --- @type string?
      selected = nil,
    },
  }
  gui.load(self)
  player_table.gui = self

  self:update_queue()
  self:update_tech_list()
  self:update_durations_and_progress()
  self:filter_tech_list()

  return self
end

function gui.load(self)
  setmetatable(self, { __index = gui })
end

return gui
