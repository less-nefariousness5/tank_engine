-- Mitigation Engine Menu
-- UI elements for Mitigation Engine configuration
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Mitigation Engine menu render function
function TE.modules.mitigation_engine.menu.on_render_menu()
    TE.modules.mitigation_engine.menu.main_tree:render("Mitigation Engine", function()
        -- Automation settings
        TE.menu.render_header(core.menu.window("mitigation_engine_window"), "Automation Settings")
        
        TE.modules.mitigation_engine.menu.auto_mitigation:render(
            "Auto Active Mitigation",
            "Automatically use active mitigation abilities"
        )
        
        TE.modules.mitigation_engine.menu.optimize_resource:render(
            "Optimize Resource Usage",
            "Intelligently manage resources for mitigation"
        )
        
        -- Threshold settings
        TE.menu.render_header(core.menu.window("mitigation_engine_window"), "Threshold Settings")
        
        TE.modules.mitigation_engine.menu.min_resource:render(
            "Minimum Resource (%)",
            "Minimum resource percentage required to use mitigation"
        )
        
        TE.modules.mitigation_engine.menu.gap_tolerance:render(
            "Gap Tolerance (s)",
            "Maximum allowable gap in mitigation coverage"
        )
        
        -- Display settings
        TE.menu.render_header(core.menu.window("mitigation_engine_window"), "Display Settings")
        
        TE.modules.mitigation_engine.menu.show_gaps:render(
            "Show Mitigation Gaps",
            "Display warnings for gaps in mitigation coverage"
        )
        
        TE.modules.mitigation_engine.menu.show_uptime:render(
            "Show Mitigation Uptime",
            "Display mitigation uptime percentage"
        )
        
        -- Debug information if appropriate
        if TE.settings.is_enabled() then
            TE.menu.render_header(core.menu.window("mitigation_engine_window"), "Debug Information")
            
            -- Current mitigation status
            local is_active = TE.variables.active_mitigation.is_active
            local remaining = is_active and ((TE.variables.active_mitigation.expires_at - core.game_time()) / 1000) or 0
            local status_text = is_active 
                              and string.format("Active (%.1fs remaining)", remaining)
                              or "Inactive"
            
            core.graphics.text_2d("Mitigation: " .. status_text, 
                                 vec2.new(400, TE.menu.window_style.padding.y + 330),
                                 14, is_active and color.green(200) or color.red(200), true)
            
            -- Resource status
            local resource_info = TE.modules.mitigation_engine.resource_availability
            if resource_info then
                core.graphics.text_2d(string.format("Resource: %.1f%%", resource_info.resource_percent), 
                                     vec2.new(400, TE.menu.window_style.padding.y + 350),
                                     14, resource_info.has_sufficient and color.green(200) or color.red(200), true)
            end
            
            -- Uptime statistics
            local uptime_30s = TE.modules.mitigation_engine.mitigation_uptimes[30] or 0
            local uptime_5s = TE.modules.mitigation_engine.mitigation_uptimes[5] or 0
            
            core.graphics.text_2d(string.format("Uptime: %.1f%% (30s) / %.1f%% (5s)", uptime_30s, uptime_5s), 
                                 vec2.new(400, TE.menu.window_style.padding.y + 370),
                                 14, uptime_30s > 70 and color.green(200) or color.yellow(200), true)
            
            -- Gap information
            local gaps = TE.modules.mitigation_engine.mitigation_gaps
            local gap_text = #gaps > 0 
                           and string.format("%d gap(s) detected", #gaps)
                           or "No mitigation gaps"
                           
            core.graphics.text_2d(gap_text, 
                                 vec2.new(400, TE.menu.window_style.padding.y + 390),
                                 14, #gaps > 0 and color.yellow(200) or color.green(200), true)
        end
    end)
end

-- Render function for mitigation visualization
function TE.modules.mitigation_engine.on_render()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Only show extra UI if gaps are enabled
    if not TE.modules.mitigation_engine.menu.show_gaps:get_state() then
        return
    end
    
    -- Draw mitigation timeline if there are gaps
    local gaps = TE.modules.mitigation_engine.mitigation_gaps
    if #gaps > 0 and TE.variables.in_combat then
        -- Draw a warning for the first upcoming gap
        local first_gap = gaps[1]
        
        -- Only show if the gap is current or upcoming
        local current_time = core.game_time()
        local is_current = first_gap.is_current or false
        local is_upcoming = not is_current and first_gap.start_time > current_time
        
        if is_current or is_upcoming then
            -- Convert to screen position
            local screen_size = core.graphics.get_screen_size()
            local center_x = screen_size.x / 2
            local y_pos = screen_size.y * 0.8
            
            -- Draw warning text
            local warning_color = is_current and color.red(230) or color.yellow(200)
            local warning_text = is_current 
                               and string.format("MITIGATION GAP: %.1fs", first_gap.duration) 
                               or string.format("MITIGATION GAP IN %.1fs", (first_gap.start_time - current_time) / 1000)
            
            core.graphics.text_2d(warning_text, 
                                 vec2.new(center_x, y_pos), 
                                 20, warning_color, true)
        end
    end
    
    -- Draw mitigation uptime if enabled
    if TE.modules.mitigation_engine.menu.show_uptime:get_state() and TE.variables.in_combat then
        local uptime = TE.modules.mitigation_engine.mitigation_uptimes[30] or 0
        local screen_size = core.graphics.get_screen_size()
        local x_pos = screen_size.x * 0.85
        local y_pos = screen_size.y * 0.85
        
        -- Choose color based on uptime
        local uptime_color
        if uptime >= 85 then
            uptime_color = color.green(230)
        elseif uptime >= 70 then
            uptime_color = color.yellow(230)
        else
            uptime_color = color.red(230)
        end
        
        -- Draw uptime text
        core.graphics.text_2d(string.format("Mitigation: %.1f%%", uptime), 
                             vec2.new(x_pos, y_pos),
                             16, uptime_color, true)
    end
end


