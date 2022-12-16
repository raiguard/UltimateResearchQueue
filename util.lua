local math = require("__flib__/math")
local table = require("__flib__/table")

local util = {}

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

--- @param technology LuaTechnology
--- @param level uint
--- @return double
function util.get_research_progress(technology, level)
  local force = technology.force
  local current_research = force.current_research
  if current_research and current_research.name == technology.name then
    if not util.is_multilevel(technology) or technology.level == level then
      return force.research_progress
    else
      return 0
    end
  else
    return force.get_saved_technology_progress(technology) or 0
  end
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

--- @param technology LuaTechnology
--- @param level uint
--- @return string
function util.get_queue_key(technology, level)
  if util.is_multilevel(technology) then
    return util.get_base_name(technology) .. "-" .. level
  else
    return technology.name
  end
end

--- @param technology LuaTechnology|LuaTechnologyPrototype
--- @return string
function util.get_base_name(technology)
  local result = string.gsub(technology.name, "%-%d*$", "")
  return result
end

--- @param technology LuaTechnology|LuaTechnologyPrototype
function util.is_multilevel(technology)
  if technology.object_name == "LuaTechnology" then
    technology = technology.prototype
  end
  return technology.level ~= technology.max_level
end

return util
