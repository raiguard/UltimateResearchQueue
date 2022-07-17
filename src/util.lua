local event = require("__flib__.event")
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

util.research_queue_updated_event = event.generate_id()

-- This is a super ugly way to do an enum type
--- @class ResearchState: integer
--- @class ResearchState.available : ResearchState
--- @class ResearchState.conditionally_available : ResearchState
--- @class ResearchState.not_available : ResearchState
--- @class ResearchState.researched : ResearchState
--- @class ResearchState.disabled : ResearchState
--- @class ResearchState.__index
--- @field available ResearchState.available
--- @field conditionally_available ResearchState.conditionally_available
--- @field not_available ResearchState.not_available
--- @field researched ResearchState.researched
--- @field disabled ResearchState.disabled
util.research_state = {
  available = 0,
  conditionally_available = 1,
  not_available = 2,
  researched = 3,
  disabled = 4,
}

--- @param force LuaForce
--- @param force_table ForceTable
function util.sort_techs(force, force_table)
  local techs = {}
  for name, tech in pairs(force.technologies) do
    local research_state = util.get_research_state(force_table, tech)
    -- Factorio Lua preserves the insertion order of technologies
    techs[name] = { state = research_state, tech = tech }
  end
  force_table.technologies = techs
end

--- @class ToShow
--- @field tech LuaTechnology
--- @field state ResearchState

return util
