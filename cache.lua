local constants = require("__UltimateResearchQueue__.constants")
local util = require("__UltimateResearchQueue__.util")

local cache = {}

local function first_entity_prototype(type)
  --- LuaCustomTable does not work with next() and is keyed by name, so we must use pairs()
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = type } })) do
    return "entity/" .. name
  end
end

function cache.build_effect_icons()
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
function cache.build_research_states(force)
  local force_table = global.forces[force.index]
  local groups = {}
  local research_states = {}
  local upgrade_states = {}
  for _, research_state in pairs(constants.research_state) do
    groups[research_state] = {}
  end
  local order = global.technology_order
  for name, technology in pairs(force.technologies) do
    local state = util.get_research_state(force_table, technology)
    research_states[name] = state
    groups[state][order[name]] = technology
    if technology.upgrade then
      local base_name = string.gsub(technology.name, "%-%d*$", "")
      local upgrade_level = technology.level
      local current_level = upgrade_states[base_name] or 0
      if
        upgrade_level > current_level
        and (state == constants.research_state.researched or force_table.queue:contains(technology.name))
      then
        upgrade_states[base_name] = upgrade_level
      elseif upgrade_level <= current_level then
        upgrade_states[base_name] = upgrade_level - 1
      end
    end
  end
  force_table.grouped_technologies = groups
  force_table.research_states = research_states
  force_table.upgrade_states = upgrade_states
end

function cache.build_technology_list()
  local profiler = game.create_profiler()
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
  profiler.stop()
  if DEBUG then
    log({ "", "Tech Sorting ", profiler })
  end

  local profiler = game.create_profiler()
  -- Build all prerequisites and direct requisites of each technology
  --- @type table<string, table<string, LuaTechnologyPrototype>>
  local prerequisites = {}
  --- @type table<string, table<string, LuaTechnologyPrototype>>
  local requisites = {}
  --- @type LuaTechnologyPrototype[]
  local base_techs = {}
  -- Step 1: Assemble requisites for each tech and determine base technologies
  for _, prototype in pairs(technologies) do
    local prerequisites = prototype.prerequisites
    if next(prerequisites) then
      for prerequisite_name in pairs(prerequisites) do
        if not requisites[prerequisite_name] then
          requisites[prerequisite_name] = {}
        end
        requisites[prerequisite_name][prototype.name] = prototype
      end
    else
      table.insert(base_techs, prototype)
    end
  end
  -- Step 2: Recursively assemble prerequisites for each tech
  local checked = {}
  --- @param technology LuaTechnologyPrototype
  local function propagate(technology)
    -- If not all of the prerequisites have been checked, then the list would be incomplete
    for prerequisite_name in pairs(technology.prerequisites) do
      if not checked[prerequisite_name] then
        return
      end
    end
    local technology_name = technology.name
    local technology_prerequisites = prerequisites[technology_name]
    local requisites = requisites[technology_name]
    if requisites then
      for _, requisite in pairs(requisites) do
        local requisite_name = requisite.name
        -- Create the requisite's prerequisite table
        local requisite_prerequisites = prerequisites[requisite_name]
        if not requisite_prerequisites then
          requisite_prerequisites = {}
          prerequisites[requisite_name] = requisite_prerequisites
        end
        -- Add all of this technology's prerequisites to the requisite's prerequisites
        if technology_prerequisites then
          for _, prerequisite in pairs(technology_prerequisites) do
            requisite_prerequisites[prerequisite.name] = prerequisite
          end
        end
        -- Add this technology to the requisite's prerequisites
        requisite_prerequisites[technology_name] = technology
      end
      checked[technology_name] = true
      for _, requisite in pairs(requisites) do
        propagate(requisite)
      end
    end
  end
  for _, technology in pairs(base_techs) do
    propagate(technology)
  end
  -- Profiling
  profiler.stop()
  if DEBUG then
    log({ "", "Prerequisite Generation ", profiler })
  end

  global.num_technologies = #technologies
  global.technologies = technologies
  global.technology_order = order
  global.technology_prerequisites = prerequisites
  global.technology_requisites = requisites
end

return cache
