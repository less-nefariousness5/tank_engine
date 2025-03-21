-- Interrupt Engine Menu
-- UI elements for Interrupt Engine configuration
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Interrupt Engine menu render function
function TE.modules.interrupt_engine.menu.on_render_menu()
    TE.modules.interrupt_engine.menu.main_tree:render("Interrupt Engine", function()
        -- Automation settings
        TE.menu.render_header(core.menu.window("interrupt_engine_window"), "Automation Settings")
        
        TE.modules.interrupt_engine.menu.auto_interrupt:render(
            "Auto Interrupt",
            "Automatically interrupt spells"
        )
        
        TE.modules.interrupt_engine.menu.auto_cc:render(
            "Auto Crowd Control",
            "Automatically apply crowd control"
        )
        
        TE.modules.interrupt_engine.menu.coordinate_interrupts:render(
            "Coordinate Interrupts",
            "Coordinate interrupts with group members"
        )
        
        -- Threshold settings
        TE.menu.render_header(core.menu.window("interrupt_engine_window"), "Threshold Settings")
        
        TE.modules.interrupt_engine.menu.priority_threshold:render(
            "Interrupt Priority Threshold",
            "Minimum priority score required to interrupt"
        )
        
        TE.modules.interrupt_engine.menu.danger_threshold:render(
            "CC Danger Threshold",
            "Minimum danger score required to apply CC"
        )
        
        TE.modules.interrupt_engine.menu.max_interrupt_distance:render(
            "Maximum Interrupt Distance",
            "Maximum distance to consider targets for interrupts or CC"
        )
        
        TE.modules.interrupt_engine.menu.min_cc_duration:render(
            "Minimum CC Duration",
            "Minimum duration of crowd control to apply"
        )
        
        -- Display settings
        TE.menu.render_header(core.menu.window("interrupt_engine_window"), "Display Settings")
        
        TE.modules.interrupt_engine.menu.show_cast_warnings:render(
            "Show Cast Warnings",
            "Display warnings for important casts"
        )
        
        -- Debug information if appropriate
        if TE.settings.is_enabled() then
            TE.menu.render_header(core.menu.window("interrupt_engine_window"), "Debug Information")
            
            -- Count current interrupt targets
            local interrupt_count = 0
            for _ in pairs(TE.modules.interrupt_engine.interrupt_targets) do
                interrupt_count = interrupt_count + 1
            end
            
            -- Count current CC targets
            local cc_count = 0
            for _ in pairs(TE.modules.interrupt_engine.cc_targets) do
                cc_count = cc_count + 1
            end
            
            -- Display counts
            core.graphics.text_2d(string.format("Interrupt Targets: %d", interrupt_count), 
                                 vec2.new(400, TE.menu.window_style.padding.y + 330),
                                 14, interrupt_count > 0 and color.yellow(200) or color.green(200), true)
            
            core.graphics.text_2d(string.format("CC Targets: %d", cc_count), 
                                 vec2.new(400, TE.menu.window_style.padding.y + 350),
                                 14, cc_count > 0 and color.yellow(200) or color.green(200), true)
            
            -- Show most recent interrupt
            if #TE.modules.interrupt_engine.interrupt_history > 0 then
                local last_interrupt = TE.modules.interrupt_engine.interrupt_history[#TE.modules.interrupt_engine.interrupt_history]
                local time_ago = (core.game_time() - last_interrupt.time) / 1000
                
                if time_ago < 60 then
                    core.graphics.text_2d(string.format("Last Interrupt: %s on %s's %s (%.1fs ago)", 
                                         last_interrupt.spell_name,
                                         last_interrupt.target_name,
                                         last_interrupt.target_spell_name,
                                         time_ago), 
                                         vec2.new(400, TE.menu.window_style.padding.y + 370),
                                         14, color.gray(200), true)
                end
            end
        end
    end)
end

-- Render function for interrupt visualization
function TE.modules.interrupt_engine.on_render()
    if not TE.settings.is_enabled() or not TE.modules.interrupt_engine.menu.show_cast_warnings:get_state() then
        return
    end
    
    -- Only show cast warnings if enabled
    local current_time = core.game_time()
    local screen_size = core.graphics.get_screen_size()
    local center_x = screen_size.x / 2
    local base_y = screen_size.y * 0.3
    
    -- Track how many warnings we've shown
    local warning_count = 0
    
    -- Show warnings for high priority interrupts
    for unit, data in pairs(TE.modules.interrupt_engine.interrupt_targets) do
        if unit and unit:is_valid() and not unit:is_dead() and data.danger_score >= 70 then
            -- Only show the top 3 warnings
            if warning_count >= 3 then
                break
            end
            
            local spell_name = core.spell_book.get_spell_name(data.spell_id) or "Unknown Spell"
            local unit_name = unit:get_name()
            local remaining_time = math.max(0, data.remaining_time)
            
            -- Choose color based on danger and remaining time
            local warning_color
            if data.danger_score >= 90 then
                warning_color = color.red(230)
            elseif data.danger_score >= 80 then
                warning_color = color.orange(230)
            else
                warning_color = color.yellow(230)
            end
            
            -- Show warning text
            local warning_text = string.format("%s casting %s (%.1fs)", unit_name, spell_name, remaining_time)
            core.graphics.text_2d(warning_text, 
                                 vec2.new(center_x, base_y + (warning_count * 25)),
                                 16, warning_color, true)
            
            warning_count = warning_count + 1
        end
    end
    
    -- Show interrupt on nameplates
    for unit, data in pairs(TE.modules.interrupt_engine.interrupt_targets) do
        if unit and unit:is_valid() and not unit:is_dead() then
            -- Convert to screen position if possible
            local unit_position = unit:get_position()
            local screen_pos = core.graphics.w2s(unit_position)
            
            if screen_pos then
                -- Choose icon or text based on danger
                local interrupt_color
                
                if data.danger_score >= 90 then
                    interrupt_color = color.red(230)
                elseif data.danger_score >= 70 then
                    interrupt_color = color.orange(230)
                else
                    interrupt_color = color.yellow(200)
                end
                
                -- Display an interrupt indicator
                core.graphics.text_2d("INTERRUPT", 
                                     vec2.new(screen_pos.x, screen_pos.y - 40),
                                     12, interrupt_color, true)
            end
        end
    end
end

