local event = require("__flib__/event")

local constants = {}

--- @alias EffectDisplayType
--- | "float"
--- | "float_percent"
--- | "signed"
--- | "unsigned"
--- | "ticks"
--- @type table<string, EffectDisplayType>
constants.effect_display_type = {
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

--- The overlay constant for a given TechnologyModifier type
constants.overlay_constant = {
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

constants.on_research_queue_updated = event.generate_id()
--- @class EventData.on_research_queue_updated: EventData
--- @field force LuaForce

constants.queue_limit = 7 * 7

--- @enum QueuePushError
constants.queue_push_error = {
  already_in_queue = 1,
  queue_full = 2,
  too_many_prerequisites = 3,
  too_many_prerequisites_queue_full = 4,
}

--- @enum ResearchState
constants.research_state = {
  available = 1,
  conditionally_available = 2,
  not_available = 3,
  researched = 4,
  disabled = 5,
}

return constants
