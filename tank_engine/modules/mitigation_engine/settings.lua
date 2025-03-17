-- Mitigation Engine Settings
-- Settings for the Active Mitigation engine

TE.modules.mitigation_engine.settings = {
    -- Automation settings
    automation = {
        ---@type fun(): boolean
        auto_mitigation = function() return TE.modules.mitigation_engine.menu.auto_mitigation:get_state() end,
        
        ---@type fun(): boolean
        optimize_resource = function() return TE.modules.mitigation_engine.menu.optimize_resource:get_state() end,
    },
    
    -- Threshold settings
    thresholds = {
        ---@type fun(): number
        min_resource = function() return TE.modules.mitigation_engine.menu.min_resource:get() end,
        
        ---@type fun(): number
        gap_tolerance = function() return TE.modules.mitigation_engine.menu.gap_tolerance:get() end,
    },
    
    -- Display settings
    display = {
        ---@type fun(): boolean
        show_gaps = function() return TE.modules.mitigation_engine.menu.show_gaps:get_state() end,
        
        ---@type fun(): boolean
        show_uptime = function() return TE.modules.mitigation_engine.menu.show_uptime:get_state() end,
    }
}
