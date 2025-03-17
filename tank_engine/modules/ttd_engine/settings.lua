-- TTD Engine Settings
-- Settings for the Time-To-Death calculation engine

TE.modules.ttd_engine.settings = {
    -- TTD calculation settings
    calculation = {
        ---@type fun(): number
        min_combat_time = function() return TE.modules.ttd_engine.menu.min_combat_time:get() end,
        
        ---@type fun(): number
        regression_window = function() return TE.modules.ttd_engine.menu.regression_window:get() end,
        
        ---@type fun(): number
        smoothing_factor = function() return TE.modules.ttd_engine.menu.smoothing_factor:get() end,
    },
    
    -- Display settings
    display = {
        ---@type fun(): boolean
        show_ttd_values = function() return TE.modules.ttd_engine.menu.show_ttd_values:get_state() end,
        
        ---@type fun(): boolean
        show_ttd_window = function() return TE.modules.ttd_engine.menu.show_ttd_window:get_state() end,
        
        ---@type fun(): boolean
        show_all_targets = function() return TE.modules.ttd_engine.menu.show_all_targets:get_state() end,
        
        ---@type fun(): number
        max_targets = function() return TE.modules.ttd_engine.menu.max_targets:get() end,
        
        ---@type fun(): number
        window_x_position = function() return TE.modules.ttd_engine.menu.window_x_position:get() end,
        
        ---@type fun(): number
        window_y_position = function() return TE.modules.ttd_engine.menu.window_y_position:get() end,
        
        ---@type fun(x: number, y: number)
        set_window_position = function(x, y) 
            if TE.modules.ttd_engine.menu.window_x_position and TE.modules.ttd_engine.menu.window_y_position then
                TE.modules.ttd_engine.menu.window_x_position:set(x)
                TE.modules.ttd_engine.menu.window_y_position:set(y)
            end
        end
    }
}
