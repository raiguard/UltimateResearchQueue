local event = require("__flib__.event")

local constants = {}

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
constants.research_state = {
  available = 0,
  conditionally_available = 1,
  not_available = 2,
  researched = 3,
  disabled = 4,
}

constants.research_queue_updated_event = event.generate_id()

return constants
