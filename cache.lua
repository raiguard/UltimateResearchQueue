local dictionary = require("__flib__/dictionary-lite")
local table = require("__flib__/table")

local constants = require("__UltimateResearchQueue__/constants")
local research_queue = require("__UltimateResearchQueue__/research-queue")

--- @class Cache
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

  for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "land-mine" } })) do
    local ammo_category = prototype.ammo_category
    if ammo_category and not icons[ammo_category] then
      icons[ammo_category] = "entity/" .. prototype.name
    end
  end

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

function cache.build_dictionaries()
  -- Build dictionaries
  dictionary.on_init()
  dictionary.new("recipe")
  for name, recipe in pairs(game.recipe_prototypes) do
    dictionary.add("recipe", name, { "?", recipe.localised_name, name })
  end
  dictionary.new("technology")
  for name, technology in pairs(game.technology_prototypes) do
    dictionary.add("technology", name, { "?", technology.localised_name, name })
  end
end

function cache.build_technologies()
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

  -- Create order lookup and assemble upgrade groups
  --- @type table<string, LuaTechnologyPrototype[]>
  local upgrade_groups = {}
  --- @type table<string, number>
  local order = {}
  for i = 1, #technologies do
    local technology = technologies[i]
    order[technology.name] = i
    if technology.upgrade then
      local base_name = string.match(technology.name, "^(.*)%-%d*$") or technology.name
      local group = table.get_or_insert(upgrade_groups, base_name, {})
      group[#group + 1] = technology
    end
  end
  -- Sort upgrade groups
  for _, group in pairs(upgrade_groups) do
    table.sort(group, function(a, b)
      return a.level < b.level
    end)
  end

  profiler.stop()
  log({ "", "Tech Sorting ", profiler })

  local profiler = game.create_profiler()
  -- Build all prerequisites and direct requisites of each technology
  --- @type table<string, string[]>
  local prerequisites = {}
  --- @type table<string, string[]>
  local requisites = {}
  --- @type LuaTechnologyPrototype[]
  local base_techs = {}
  -- Step 1: Assemble requisites for each tech and determine base technologies
  for i = 1, #technologies do
    local technology = technologies[i]
    local prerequisites = technology.prerequisites
    if next(prerequisites) then
      local technology_name = technology.name
      for prerequisite_name in pairs(prerequisites) do
        local requisite_prerequisites = requisites[prerequisite_name]
        if not requisite_prerequisites then
          requisite_prerequisites = {}
          requisites[prerequisite_name] = requisite_prerequisites
        end
        requisite_prerequisites[#requisite_prerequisites + 1] = technology_name
      end
    else
      base_techs[#base_techs + 1] = technology
    end
  end
  -- Step 2: Recursively assemble prerequisites for each tech
  local tech_prototypes = game.technology_prototypes
  local checked = {}
  --- @param tbl {[string]: boolean, [integer]: string}
  --- @param obj string
  local function unique_insert(tbl, obj)
    if not tbl[obj] then
      tbl[obj] = true
      tbl[#tbl + 1] = obj
    end
  end
  --- @param technology LuaTechnologyPrototype
  local function propagate(technology)
    -- If not all of the prerequisites have been checked, then the list would be incomplete
    for prerequisite_name in pairs(technology.prerequisites) do
      if not checked[prerequisite_name] then
        return
      end
    end
    local technology_name = technology.name
    local technology_prerequisites = prerequisites[technology_name] or {}
    local technology_requisites = requisites[technology_name] or {}
    for i = 1, #technology_requisites do
      local requisite_name = technology_requisites[i]
      -- Create the requisite's prerequisite table
      local requisite_prerequisites = prerequisites[requisite_name]
      if not requisite_prerequisites then
        requisite_prerequisites = {}
        prerequisites[requisite_name] = requisite_prerequisites
      end
      -- Add all of this technology's prerequisites to the requisite's prerequisites
      for i = 1, #technology_prerequisites do
        unique_insert(requisite_prerequisites, technology_prerequisites[i])
      end
      -- Add this technology to the requisite's prerequisites
      unique_insert(requisite_prerequisites, technology_name)
    end
    checked[technology_name] = true
    for i = 1, #technology_requisites do
      propagate(tech_prototypes[technology_requisites[i]])
    end
  end
  for _, technology in pairs(base_techs) do
    propagate(technology)
  end
  -- Profiling
  profiler.stop()
  log({ "", "Prerequisite Generation ", profiler })

  global.num_technologies = #technologies
  global.technology_order = order
  global.technology_prerequisites = prerequisites
  global.technology_requisites = requisites
  global.technology_upgrade_groups = upgrade_groups
end

--- @param force LuaForce
function cache.init_force(force)
  local force_table = global.forces[force.index]
  --- @type table<ResearchState, table<uint, LuaTechnology>>
  local technology_groups = {}
  for _, research_state in pairs(constants.research_state) do
    technology_groups[research_state] = {}
  end
  force_table.technology_groups = technology_groups
  --- @type table<string, ResearchState>
  local research_states = {}
  force_table.research_states = research_states
  for name, technology in pairs(force.technologies) do
    local research_state = research_queue.get_research_state(force_table, technology)
    research_states[name] = research_state
    technology_groups[research_state][global.technology_order[technology.name]] = technology
  end
end

return cache
