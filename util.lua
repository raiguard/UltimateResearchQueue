local math = require("__flib__/math")
local table = require("__flib__/table")

local constants = require("__UltimateResearchQueue__/constants")

local util = {}

--- @param tech_data TechnologyData
--- @param check_queue boolean?
function util.are_prereqs_satisfied(tech_data, check_queue)
  for _, prereq in pairs(tech_data.technology.prerequisites) do
    if not prereq.researched then
      if not check_queue or not tech_data.in_queue then
        return false
      end
    end
  end
  return true
end

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
function util.flying_text(player, text)
  player.create_local_flying_text({
    text = text,
    create_at_cursor = true,
  })
  player.play_sound({ path = "utility/cannot_build" })
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

--- @param tech_data TechnologyData
--- @return ResearchState
function util.get_research_state(tech_data)
  local technology = tech_data.technology
  if technology.researched then
    return constants.research_state.researched
  end
  if not technology.enabled then
    return constants.research_state.disabled
  end
  if util.are_prereqs_satisfied(tech_data) then
    return constants.research_state.available
  end
  if util.are_prereqs_satisfied(tech_data, true) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
end

--- @param tech LuaTechnology
--- @param level uint?
--- @return double
function util.get_research_unit_count(tech, level)
  local formula = tech.research_unit_count_formula
  if formula then
    local level = level or tech.level
    return game.evaluate_expression(formula, { l = level, L = level })
  else
    return tech.research_unit_count --[[@as double]]
  end
end

--- @param player LuaPlayer
function util.is_cheating(player)
  return player.cheat_mode or player.controller_type == defines.controllers.editor
end

--- @param tech_data TechnologyDataWithLevel|ResearchQueueNode
--- @return string
function util.get_technology_name(tech_data)
  if tech_data.level then
    return tech_data.data.base_name .. "-" .. tech_data.level
  else
    return tech_data.data.name
  end
end

return util
