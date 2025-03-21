-- TTD Engine Menu
-- UI elements for TTD Engine configuration
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- TTD Engine menu render function
function TE.modules.ttd_engine.menu.on_render_menu()
    TE.modules.ttd_engine.menu.main_tree:render("Time-To-Death Engine", function()
        -- Calculation settings
        TE.menu.render_header(core.menu.window("ttd_engine_window"), "TTD Calculation Settings")
        
        TE.modules.ttd_engine.menu.min_combat_time:render(
            "Minimum Combat Time (s)",
            "Minimum time in combat before TTD calculations become active"
        )
        
        TE.modules.ttd_engine.menu.regression_window:render(
            "Regression Window (s)",
            "Time window used for linear regression calculations"
        )
        
        TE.modules.ttd_engine.menu.smoothing_factor:render(
            "Smoothing Factor",
            "Higher values make TTD more stable but less responsive to changes"
        )
        
        -- Display settings
        TE.menu.render_header(core.menu.window("ttd_engine_window"), "Display Settings")
        
        TE.modules.ttd_engine.menu.show_ttd_values:render(
            "Show TTD Values",
            "Display TTD values above enemy nameplates (not recommended)"
        )
        
        -- Add dedicated TTD window option
        TE.modules.ttd_engine.menu.show_ttd_window:render(
            "Show TTD Window",
            "Display a floating window with Time-To-Death information"
        )
        
        if TE.modules.ttd_engine.menu.show_ttd_window:get_state() then
            TE.modules.ttd_engine.menu.show_all_targets:render(
                "Show All Targets",
                "Display TTD for multiple targets instead of just the current target"
            )
            
            if TE.modules.ttd_engine.menu.show_all_targets:get_state() then
                TE.modules.ttd_engine.menu.max_targets:render(
                    "Maximum Targets",
                    "Maximum number of targets to display in the TTD window"
                )
            end
            
            -- Window position settings
            TE.menu.render_header(core.menu.window("ttd_engine_window"), "Window Position")
            
            TE.modules.ttd_engine.menu.window_x_position:render(
                "Window X Position",
                "Horizontal position of the TTD window (0 = auto-position)"
            )
            
            TE.modules.ttd_engine.menu.window_y_position:render(
                "Window Y Position",
                "Vertical position of the TTD window (0 = auto-position)"
            )
        end
        
        -- Debug information if enabled
        if TE.modules.ttd_engine.menu.show_ttd_values:get_state() or 
           TE.modules.ttd_engine.menu.show_ttd_window:get_state() then
            
            -- Show current TTD values for testing
            local active_ttd_values = 0
            for unit, ttd in pairs(TE.modules.ttd_engine.ttd_values) do
                if unit and unit:is_valid() and not unit:is_dead() then
                    active_ttd_values = active_ttd_values + 1
                end
            end
            
            TE.menu.render_header(core.menu.window("ttd_engine_window"), "Debug Information")
            core.graphics.text_2d("Active TTD Values: " .. active_ttd_values, 
                                 vec2.new(400, TE.menu.window_style.padding.y + 350),
                                 14, color.gray(200), true)
        end
    end)
end

-- Render function for TTD display
function TE.modules.ttd_engine.on_render()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Draw nameplate TTD values if enabled (not recommended)
    if TE.modules.ttd_engine.menu.show_ttd_values:get_state() then
        -- Display TTD values above enemy nameplates
        for unit, ttd in pairs(TE.modules.ttd_engine.ttd_values) do
            if unit and unit:is_valid() and not unit:is_dead() and ttd < 100 then
                local unit_position = unit:get_position()
                local screen_pos = core.graphics.w2s(unit_position)
                
                if screen_pos then
                    -- Format TTD value
                    local ttd_text = string.format("%.1fs", ttd)
                    
                    -- Choose color based on TTD value
                    local ttd_color
                    if ttd < 5 then
                        ttd_color = color.red(230)  -- Dying soon
                    elseif ttd < 15 then
                        ttd_color = color.yellow(230)  -- Medium TTD
                    else
                        ttd_color = color.green(230)  -- Long TTD
                    end
                    
                    -- Draw TTD text
                    core.graphics.text_2d(ttd_text, 
                                        vec2.new(screen_pos.x, screen_pos.y - 30),
                                        12, ttd_color, true)
                end
            end
        end
    end
    
    -- Call the dedicated render method for TTD window if show_ttd_window is enabled
    if TE.modules.ttd_engine.menu.show_ttd_window:get_state() then
        TE.modules.ttd_engine.render_ttd_window()
    end
end


