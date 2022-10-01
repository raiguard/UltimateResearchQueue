local event = require("__flib__.event")
local gui = require("__flib__.gui")
local table = require("__flib__.table")

local util = {}

--- @param tech LuaTechnology
--- @param queue Queue?
function util.are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not table.find(queue.queue, name) then
        return false
      end
    end
  end
  return true
end

local function first_entity_prototype(type)
  --- LuaCustomTable does not work with next() and is keyed by name, so we must use pairs()
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = type } })) do
    return "entity/" .. name
  end
end
function util.build_effect_icons()
  --- Effect icons for dynamic effects. Key is either an effect type or an ammo category name
  --- @type table<string, string>
  local icons = {
    ["follower-robot-lifetime"] = first_entity_prototype("combat-robot"),
    ["laboratory-productivity"] = first_entity_prototype("lab"),
    ["laboratory-speed"] = first_entity_prototype("lab"),
    ["train-braking-force-bonus"] = first_entity_prototype("locomotive"),
    ["worker-robot-battery"] = first_entity_prototype("logistic-robot"),
    ["worker-robot-speed"] = first_entity_prototype("logistic-robot"),
    ["worker-robot-storage"] = first_entity_prototype("logistic-robot"),
  }

  for _, prototype in pairs(game.get_filtered_item_prototypes({ { filter = "type", type = "ammo" } })) do
    if not prototype.has_flag("hide-from-bonus-gui") then
      local category = prototype.get_ammo_type().category
      if not icons[category] then
        icons[category] = "item/" .. prototype.name
      end
    end
  end

  for _, prototype in pairs(game.get_filtered_item_prototypes({ { filter = "type", type = "capsule" } })) do
    if not prototype.has_flag("hide-from-bonus-gui") then
      local attack_parameters = prototype.capsule_action.attack_parameters
      if attack_parameters then
        for _, category in pairs(attack_parameters.ammo_categories or { attack_parameters.ammo_type.category }) do
          if not icons[category] then
            icons[category] = "item/" .. prototype.name
          end
        end
      end
    end
  end

  for _, prototype in
    pairs(game.get_filtered_equipment_prototypes({ { filter = "type", type = "active-defense-equipment" } }))
  do
    local attack_parameters = prototype.attack_parameters --[[@as AttackParameters]]
    for _, category in pairs(attack_parameters.ammo_categories or { attack_parameters.ammo_type.category }) do
      if not icons[category] then
        icons[category] = "equipment/" .. prototype.name
      end
    end
  end

  for _, turret_type in pairs({ "electric-turret", "ammo-turret", "artillery-turret", "fluid-turret" }) do
    for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = turret_type } })) do
      local attack_parameters = prototype.attack_parameters
      if attack_parameters then
        for _, category in pairs(attack_parameters.ammo_categories or { attack_parameters.ammo_type.category }) do
          if not icons[category] then
            icons[category] = "entity/" .. prototype.name
          end
        end
      end
    end
  end

  for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "combat-robot" } })) do
    local attack_parameters = prototype.attack_parameters --[[@as AttackParameters]]
    for _, category in pairs(attack_parameters.ammo_categories or { attack_parameters.ammo_type.category }) do
      if not icons[category] then
        icons[category] = "entity/" .. prototype.name
      end
    end
  end

  -- XXX: It is currently impossible to get a land mine's ammo category at runtime
  -- for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "land-mine" } })) do
  --   if not icons[prototype.ammo_category] then
  --     icons[prototype.ammo_category] = "entity/" .. prototype.name
  --   end
  -- end

  for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "unit" } })) do
    local attack_parameters = prototype.attack_parameters --[[@as AttackParameters]]
    for _, category in pairs(attack_parameters.ammo_categories or { attack_parameters.ammo_type.category }) do
      if not icons[category] then
        icons[category] = "entity/" .. prototype.name
      end
    end
  end

  global.effect_icons = icons
end

--- @param force LuaForce
function util.build_research_states(force)
  local force_table = global.forces[force.index]
  local counts = {}
  local states = {}
  for _, research_state in pairs(util.research_state) do
    counts[research_state] = 0
  end
  for name, technology in pairs(force.technologies) do
    local state = util.get_research_state(force_table, technology)
    states[name] = state
    counts[state] = (counts[state] or 0) + 1
  end
  force_table.research_state_counts = counts
  force_table.research_states = states
end

function util.build_technology_list()
  -- game.technology_prototypes is a LuaCustomTable, so we need to convert it to an array
  --- @type LuaTechnologyPrototype[]
  local technologies = {}
  for _, prototype in pairs(game.technology_prototypes) do
    table.insert(technologies, prototype)
  end
  -- Sort the technologies array
  local prototypes = {
    fluid = game.fluid_prototypes,
    item = game.item_prototypes,
  }
  table.sort(technologies, function(tech_a, tech_b)
    local ingredients_a = tech_a.research_unit_ingredients
    local ingredients_b = tech_b.research_unit_ingredients
    local len_a = #ingredients_a
    local len_b = #ingredients_b
    -- Always put technologies with zero ingredients at the front
    if (len_a == 0) ~= (len_b == 0) then
      return len_a == 0
    end
    if #ingredients_a > 0 then
      -- Compare ingredient order strings
      -- Check the most expensive packs first, and sort based on the first difference
      for i = 0, math.min(len_a, len_b) - 1 do
        local ingredient_a = ingredients_a[len_a - i]
        local ingredient_b = ingredients_b[len_b - i]
        local order_a = prototypes[ingredient_a.type][ingredient_a.name].order
        local order_b = prototypes[ingredient_b.type][ingredient_b.name].order
        -- Cheaper pack goes in front
        if order_a ~= order_b then
          return order_a < order_b
        end
      end
      -- Sort the tech with fewer ingredients in front
      if len_a ~= len_b then
        return len_a < len_b
      end
    end
    -- Compare technology order strings
    local order_a = tech_a.order
    local order_b = tech_b.order
    if order_a ~= order_b then
      return order_a < order_b
    end
    -- Compare prototype names
    return tech_a.name < tech_b.name
  end)
  -- Create lookup for the order of a given technology
  --- @type table<string, number>
  local order = {}
  for i, prototype in pairs(technologies) do
    order[prototype.name] = i
  end
  -- Build all prerequisites and direct requisites for all technologies
  --- @type table<string, LuaTechnologyPrototype[]>
  local prerequisites = {}
  --- @type table<string, LuaTechnologyPrototype[]>
  local requisites = {}
  for _, prototype in pairs(technologies) do
    if not requisites[prototype.name] then
      requisites[prototype.name] = {}
    end
    -- TODO: Recursively assemble prerequisites for queueing
    local prereqs = {}
    for _, prerequisite in pairs(prototype.prerequisites) do
      prereqs[#prereqs + 1] = prerequisite
      local reqs = requisites[prerequisite.name]
      if not reqs then
        requisites[prerequisite.name] = { prototype }
      else
        reqs[#reqs + 1] = prototype
      end
    end
    -- Sort prerequisites table
    table.sort(prereqs, function(tech_a, tech_b)
      return order[tech_a.name] < order[tech_b.name]
    end)
    prerequisites[prototype.name] = prereqs
  end
  -- Sort requisite tables
  for _, requisites in pairs(requisites) do
    table.sort(requisites, function(tech_a, tech_b)
      return order[tech_a.name] < order[tech_b.name]
    end)
  end

  global.technologies = technologies
  global.technology_order = order
  global.technology_prerequisites = prerequisites
  global.technology_requisites = requisites
end

--- @alias EffectDisplayType
--- | "float"
--- | "float_percent"
--- | "signed"
--- | "unsigned"
--- | "ticks"
--- @type table<string, EffectDisplayType>
util.effect_display_type = {
  ["artillery-range"] = "float_percent",
  ["character-build-distance"] = "float",
  ["character-crafting-speed"] = "float_percent",
  ["character-health-bonus"] = "float",
  ["character-inventory-slots-bonus"] = "signed",
  ["character-item-drop-distance"] = "float",
  ["character-item-pickup-distance"] = "float",
  ["character-logistic-trash-slots"] = "unsigned",
  ["character-loot-pickup-distance"] = "float",
  ["character-mining-speed"] = "float_percent",
  ["character-reach-distance"] = "float",
  ["character-resource-reach-distance"] = "float",
  ["character-running-speed"] = "float_percent",
  ["deconstruction-time-to-live"] = "ticks",
  ["dummy-character-logistic-slots"] = "unsigned",
  ["following-robots-lifetime"] = "float_percent",
  ["ghost-time-to-live"] = "ticks",
  ["inserter-stack-size-bonus"] = "unsigned",
  ["laboratory-productivity"] = "float_percent",
  ["laboratory-speed"] = "float_percent",
  ["max-failed-attempts-per-tick-per-construction-queue"] = "float_percent",
  ["maximum-following-robots-count"] = "unsigned",
  ["max-successful-attemps-per-tick-per-construction-queue"] = "float_percent",
  ["mining-drill-productivity-bonus"] = "float_percent",
  ["stack-inserter-capacity-bonus"] = "unsigned",
  ["train-braking-force-bonus"] = "float_percent",
  ["worker-robot-battery"] = "float_percent",
  ["worker-robot-speed"] = "float_percent",
  ["worker-robot-storage"] = "unsigned",
}

--- Ensure that the vanilla research queue is disabled
--- @param force LuaForce
function util.ensure_queue_disabled(force)
  if force.research_queue_enabled then
    force.print({ "message.urq-vanilla-queue-disabled" })
    force.research_queue_enabled = false
  end
end

--- @param player LuaPlayer
--- @param text LocalisedString
--- @param options FlyingTextOptions?
function util.flying_text(player, text, options)
  options = options or {}
  player.create_local_flying_text({
    text = text,
    create_at_cursor = not options.position,
    position = options.position,
    color = options.color,
  })
  -- Default sound
  if options.sound == nil then
    options.sound = "utility/cannot_build"
  end
  -- Will not play if sound is explicitly set to false
  if options.sound then
    player.play_sound({ path = options.sound })
  end
end

--- @param ticks number
--- @return LocalisedString
function util.format_time_short(ticks)
  if ticks == 0 then
    return { "time-symbol-seconds-short", 0 }
  end

  local hours = math.floor(ticks / 60 / 60 / 60)
  local minutes = math.floor(ticks / 60 / 60) % 60
  local seconds = math.floor(ticks / 60) % 60
  local result = { "" }
  if hours ~= 0 then
    table.insert(result, { "time-symbol-hours-short", hours })
  end
  if minutes ~= 0 then
    table.insert(result, { "time-symbol-minutes-short", minutes })
  end
  if seconds ~= 0 then
    table.insert(result, { "time-symbol-seconds-short", seconds })
  end
  return result
end

--- @class FlyingTextOptions
--- @field position MapPosition?
--- @field color Color?
--- @field sound SoundPath|boolean?

--- @param player LuaPlayer|uint
--- @return Gui?
function util.get_gui(player)
  if type(player) == "table" then
    player = player.index
  end
  --- @type PlayerTable?
  local player_table = global.players[player]
  if player_table then
    local gui = player_table.gui
    if gui then
      if not gui.refs.window.valid then
        gui:destroy()
        gui = gui.new(gui.player, gui.player_table)
        gui.player.print({ "message.urq-recreated-gui" })
      end
      return gui
    end
  end
end

--- @param tech LuaTechnology
--- @return double
function util.get_research_progress(tech)
  local force = tech.force
  local current_research = force.current_research
  if current_research and current_research.name == tech.name then
    return force.research_progress
    -- TODO: Handle infinite researches
  else
    return force.get_saved_technology_progress(tech) or 0
  end
end

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return ResearchState
function util.get_research_state(force_table, tech)
  if tech.researched then
    return util.research_state.researched
  end
  if not tech.enabled then
    return util.research_state.disabled
  end
  if util.are_prereqs_satisfied(tech) then
    return util.research_state.available
  end
  if util.are_prereqs_satisfied(tech, force_table.queue) then
    return util.research_state.conditionally_available
  end
  return util.research_state.not_available
end

--- @param tech LuaTechnology
--- @return double
function util.get_research_unit_count(tech)
  local formula = tech.research_unit_count_formula
  if formula then
    local level = tech.level --[[@as double]]
    return game.evaluate_expression(formula, { l = level, L = level })
  else
    return tech.research_unit_count --[[@as double]]
  end
end

--- Get all unreearched prerequisites. Note that the table is returned in reverse order and must be iterated in
--- reverse.
--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return string[]
function util.get_unresearched_prerequisites(force_table, tech)
  local added = {}
  local to_research = { tech.name }
  local to_iterate = { tech }
  local i, next_tech = next(to_iterate)
  local research_states = force_table.research_states
  while next_tech do
    for prereq_name, prereq in pairs(next_tech.prerequisites) do
      local research_state = research_states[prereq_name]
      if research_state ~= util.research_state.researched then
        if added[prereq_name] then
          table.remove(to_research, table.find(to_research, prereq_name))
        else
          table.insert(to_iterate, prereq)
        end
        table.insert(to_research, prereq_name)
      end
    end
    i, next_tech = next(to_iterate, i)
  end
  return to_research
end

--- @param elem LuaGuiElement
function util.is_double_click(elem)
  local tags = gui.get_tags(elem)
  local last_click_tick = tags.last_click_tick or 0
  local is_double_click = game.ticks_played - last_click_tick < 12
  if is_double_click then
    tags.last_click_tick = nil
  else
    tags.last_click_tick = game.ticks_played
  end
  gui.set_tags(elem, tags)
  return is_double_click
end

--- @param element LuaGuiElement
--- @param parent LuaGuiElement
--- @param index number
function util.move_to(element, parent, index)
  --- @cast index uint
  local dummy = parent.add({ type = "empty-widget", index = index })
  parent.swap_children(element.get_index_in_parent(), index)
  dummy.destroy()
end

--- The overlay constant for a given TechnologyModifier type
util.overlay_constant = {
  ["ammo-damage"] = "utility/ammo_damage_modifier_constant",
  ["artillery-range"] = "utility/artillery_range_modifier_constant",
  ["character-build-distance"] = "utility/character_build_distance_modifier_constant",
  ["character-crafting-speed"] = "utility/character_crafting_speed_modifier_constant",
  ["character-health-bonus"] = "utility/character_health_bonus_modifier_constant",
  ["character-inventory-slots-bonus"] = "utility/character_inventory_slots_bonus_modifier_constant",
  ["character-item-drop-distance"] = "utility/character_item_drop_distance_modifier_constant",
  ["character-item-pickup-distance"] = "utility/character_item_pickup_distance_modifier_constant",
  ["character-logistic-trash-slots"] = "utility/character_logistic_trash_slots_modifier_constant",
  ["character-loot-pickup-distance"] = "utility/character_loot_pickup_distance_modifier_constant",
  ["character-mining-speed"] = "utility/character_mining_speed_modifier_constant",
  ["character-reach-distance"] = "utility/character_reach_distance_modifier_constant",
  ["character-resource-reach-distance"] = "utility/character_resource_reach_distance_modifier_constant",
  ["character-running-speed"] = "utility/character_running_speed_modifier_constant",
  ["deconstruction-time-to-live"] = "utility/deconstruction_time_to_live_modifier_constant",
  ["follower-robot-lifetime"] = "utility/follower_robot_lifetime_modifier_constant",
  ["ghost-time-to-live"] = "utility/ghost_time_to_live_modifier_constant",
  ["gun-speed"] = "utility/gun_speed_modifier_constant",
  ["inserter-stack-size-bonus"] = "utility/inserter_stack_size_bonus_modifier_constant",
  ["laboratory-productivity"] = "utility/laboratory_productivity_modifier_constant",
  ["laboratory-speed"] = "utility/laboratory_speed_modifier_constant",
  ["max-failed-attempts-per-tick-per-construction-queue"] = "utility/max_failed_attempts_per_tick_per_construction_queue_modifier_constant",
  ["maximum-following-robots-count"] = "utility/maximum_following_robots_count_modifier_constant",
  ["max-successful-attempts-per-tick-per-construction-queue"] = "utility/max_successful_attempts_per_tick_per_construction_queue_modifier_constant",
  ["mining-drill-productivity-bonus"] = "utility/mining_drill_productivity_bonus_modifier_constant",
  ["stack-inserter-capacity-bonus"] = "utility/stack_inserter_capacity_bonus_modifier_constant",
  ["train-braking-force-bonus"] = "utility/train_braking_force_bonus_modifier_constant",
  ["turret-attack"] = "utility/turret_attack_modifier_constant",
  ["worker-robot-battery"] = "utility/worker_robot_battery_modifier_constant",
  ["worker-robot-speed"] = "utility/worker_robot_speed_modifier_constant",
  ["worker-robot-storage"] = "utility/worker_robot_storage_modifier_constant",
  ["zoom-to-world-blueprint-enabled"] = "utility/zoom_to_world_blueprint_enabled_modifier_constant",
  ["zoom-to-world-deconstruction-planner-enabled"] = "utility/zoom_to_world_deconstruction_planner_enabled_modifier_constant",
  ["zoom-to-world-ghost-building-enabled"] = "utility/zoom_to_world_ghost_building_enabled_modifier_constant",
  ["zoom-to-world-selection-tool-enabled"] = "utility/zoom_to_world_selection_tool_enabled_modifier_constant",
  ["zoom-to-world-upgrade-planner-enabled"] = "utility/zoom_to_world_upgrade_planner_enabled_modifier_constant",
}

util.research_queue_updated_event = event.generate_id()

--- @enum ResearchState
util.research_state = {
  available = 1,
  conditionally_available = 2,
  not_available = 3,
  researched = 4,
  disabled = 5,
}

--- @param force_table ForceTable
--- @param technology LuaTechnology
--- @return boolean? updated
function util.update_research_state(force_table, technology)
  local previous_state = force_table.research_states[technology.name]
  local new_state = util.get_research_state(force_table, technology)
  if new_state ~= previous_state then
    force_table.research_state_counts[previous_state] = force_table.research_state_counts[previous_state] - 1
    force_table.research_state_counts[new_state] = force_table.research_state_counts[new_state] + 1
    force_table.research_states[technology.name] = new_state
    return true
  end
end

return util
