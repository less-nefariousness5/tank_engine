-- Defensive Engine Settings
-- Settings for the Defensive Cooldown engine

TE.modules.defensive_engine.settings = {
    -- Automation settings
    automation = {
        ---@type fun(): boolean
        auto_defensives = function() return TE.modules.defensive_engine.menu.auto_defensives:get_state() end,
        
        ---@type fun(): boolean
        enable_boss_detection = function() return TE.modules.defensive_engine.menu.enable_boss_detection:get_state() end,
    },
    
    -- Threshold settings
    thresholds = {
        ---@type fun(): number
        health_threshold = function() return TE.modules.defensive_engine.menu.health_threshold:get() end,
        
        ---@type fun(): number
        low_health_threshold = function() return TE.modules.defensive_engine.menu.low_health_threshold:get() end,
        
        ---@type fun(): number
        damage_spike_threshold = function() return TE.modules.defensive_engine.menu.damage_spike_threshold:get() end,
    },
    
    -- Advanced settings
    advanced = {
        ---@type fun(): number
        anticipation_window = function() return TE.modules.defensive_engine.menu.anticipation_window:get() end,
        
        ---@type fun(): boolean
        prioritize_physical = function() return TE.modules.defensive_engine.menu.prioritize_physical:get_state() end,
    }
}
