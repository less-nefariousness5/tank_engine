-- Interrupt Engine Settings
-- Settings for the Interrupt and Crowd Control engine

TE.modules.interrupt_engine.settings = {
    -- Automation settings
    automation = {
        ---@type fun(): boolean
        auto_interrupt = function() return TE.modules.interrupt_engine.menu.auto_interrupt:get_state() end,
        
        ---@type fun(): boolean
        auto_cc = function() return TE.modules.interrupt_engine.menu.auto_cc:get_state() end,
        
        ---@type fun(): boolean
        coordinate_interrupts = function() return TE.modules.interrupt_engine.menu.coordinate_interrupts:get_state() end,
    },
    
    -- Threshold settings
    thresholds = {
        ---@type fun(): number
        priority_threshold = function() return TE.modules.interrupt_engine.menu.priority_threshold:get() end,
        
        ---@type fun(): number
        danger_threshold = function() return TE.modules.interrupt_engine.menu.danger_threshold:get() end,
        
        ---@type fun(): number
        max_interrupt_distance = function() return TE.modules.interrupt_engine.menu.max_interrupt_distance:get() end,
        
        ---@type fun(): number
        min_cc_duration = function() return TE.modules.interrupt_engine.menu.min_cc_duration:get() end,
    },
    
    -- Display settings
    display = {
        ---@type fun(): boolean
        show_cast_warnings = function() return TE.modules.interrupt_engine.menu.show_cast_warnings:get_state() end,
    }
}
