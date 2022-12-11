local math = require("__flib__/math")
local table = require("__flib__/table")

local constants = require("__UltimateResearchQueue__/constants")

local util = {}

--- @param tech LuaTechnology
--- @param queue Queue?
function util.are_prereqs_satisfied(tech, queue)
  for name, prereq in pairs(tech.prerequisites) do
    if not prereq.researched then
      if not queue or not queue.queue[name] then
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

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return ResearchState
function util.get_research_state(force_table, tech)
  if tech.researched then
    return constants.research_state.researched
  end
  if not tech.enabled then
    return constants.research_state.disabled
  end
  if util.are_prereqs_satisfied(tech) then
    return constants.research_state.available
  end
  if util.are_prereqs_satisfied(tech, force_table.queue) then
    return constants.research_state.conditionally_available
  end
  return constants.research_state.not_available
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

--- @param force_table ForceTable
--- @param tech LuaTechnology
--- @return string[]
function util.get_unresearched_prerequisites(force_table, tech)
  local research_states = force_table.research_states
  local to_research = {}
  for prerequisite_name, prerequisite in pairs(global.technology_prerequisites[tech.name]) do
    if
      research_states[prerequisite.name] ~= constants.research_state.researched
      and not force_table.queue.queue[prerequisite_name]
    then
      table.insert(to_research, prerequisite_name)
    end
  end
  table.insert(to_research, tech.name)
  return to_research
end

--- @param player LuaPlayer
function util.is_cheating(player)
  return player.cheat_mode or player.controller_type == defines.controllers.editor
end

return util
