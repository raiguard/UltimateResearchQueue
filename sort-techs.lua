local table = require("__flib__.table")

local sort_techs = {}

--- @param tech LuaTechnology
--- @param queue Queue?
function sort_techs.are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not table.find(queue.queue, name) then
        return false
      end
    end
  end
  return true
end

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return ResearchState
function sort_techs.get_research_state(force_table, tech)
  if tech.researched then
    return sort_techs.research_state.researched
  end
  if not tech.enabled then
    return sort_techs.research_state.disabled
  end
  if sort_techs.are_prereqs_satisfied(tech) then
    return sort_techs.research_state.available
  end
  if sort_techs.are_prereqs_satisfied(tech, force_table.queue) then
    return sort_techs.research_state.conditionally_available
  end
  return sort_techs.research_state.not_available
end

--- @enum ResearchState
sort_techs.research_state = {
  available = 0,
  conditionally_available = 1,
  not_available = 2,
  researched = 3,
  disabled = 4,
}

--- @class TechnologyWithResearchState
--- @field tech LuaTechnology
--- @field state ResearchState

--- Rebuild the techs list from scratch - slow!
--- @param force LuaForce
function sort_techs.refresh(force)
  local force_table = global.forces[force.index]

  --- @type TechnologyWithResearchState[]
  local to_show = {}
  for _, technology in pairs(force.technologies) do
    if not technology.prototype.hidden then
      table.insert(to_show, { tech = technology, state = sort_techs.get_research_state(force_table, technology) })
    end
  end

  local prototypes = {
    fluid = game.fluid_prototypes,
    item = game.item_prototypes,
  }
  table.sort(to_show, function(tech_a, tech_b)
    -- Compare researche state
    if tech_a.state ~= tech_b.state then
      return tech_a.state < tech_b.state
    end
    local ingredients_a = tech_a.tech.research_unit_ingredients
    local ingredients_b = tech_b.tech.research_unit_ingredients
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
    local order_a = tech_a.tech.order
    local order_b = tech_b.tech.order
    if order_a ~= order_b then
      return order_a < order_b
    end
    -- Compare prototype names
    return tech_a.tech.name < tech_b.tech.name
  end)

  -- Create an indexable table
  -- Factorio Lua preserves the insertion order of tables
  local output = {}
  for _, tech_data in pairs(to_show) do
    output[tech_data.tech.name] = tech_data
  end

  force_table.technologies = output
end

return sort_techs
