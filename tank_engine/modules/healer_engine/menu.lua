-- Healer Engine Menu
-- UI elements for Healer Engine configuration
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Create menu elements if they don't exist yet
if not TE.modules.healer_engine.menu then
    TE.modules.healer_engine.menu = {
        main_tree = TE.menu.tree_node(),
        enable_tracking = TE.menu.checkbox(true, "healer_enable_tracking"),
        alert_on_low_mana = TE.menu.checkbox(true, "healer_alert_low_mana"),
        low_mana_threshold = TE.menu.slider_float(0.1, 0.5, 0.3, "healer_low_mana_threshold"),
        show_healer_info = TE.menu.checkbox(true, "healer_show_info"),
        adjust_for_healers = TE.menu.checkbox(true, "healer_adjust_gameplay"),
    }
end

-- Healer Engine menu render function
function TE.modules.healer_engine.menu.on_render_menu()
    TE.modules.healer_engine.menu.main_tree:render("Healer Engine [Partial]", function()
        -- Create header
        local header = core.menu.header()
        header:render("Healer Tracking", color.cyan())
        
        -- Basic settings
        TE.modules.healer_engine.menu.enable_tracking:render(
            "Enable Healer Tracking",
            "Track and analyze healer performance"
        )
        
        if TE.modules.healer_engine.menu.enable_tracking:get_state() then
            TE.modules.healer_engine.menu.show_healer_info:render(
                "Show Healer Info",
                "Display healer information on screen"
            )
            
            TE.modules.healer_engine.menu.adjust_for_healers:render(
                "Adjust Gameplay for Healers",
                "Consider healer state when making tanking decisions"
            )
            
            -- Mana tracking settings
            TE.modules.healer_engine.menu.alert_on_low_mana:render(
                "Alert on Low Healer Mana",
                "Show warning when healers are low on mana"
            )
            
            if TE.modules.healer_engine.menu.alert_on_low_mana:get_state() then
                TE.modules.healer_engine.menu.low_mana_threshold:render(
                    "Low Mana Threshold",
                    "Percentage to consider healer mana as low"
                )
            end
        end
        
        -- Development status
        local gui_window = core.menu.window("healer_engine_window")
        gui_window:add_separator(0, 0, 10, 0, color.gray(150))
        local status_header = core.menu.header()
        status_header:render("Development Status", color.orange())
        local dynamic = gui_window:get_current_context_dynamic_drawing_offset()
        gui_window:render_text(1, vec2.new(dynamic.x, dynamic.y), color.orange(), "This module is partially implemented.")
        gui_window:set_current_context_dynamic_drawing_offset(vec2.new(dynamic.x, dynamic.y + 20))
        gui_window:render_text(1, vec2.new(dynamic.x, dynamic.y), color.white(), "Some features may not be available yet.")
    end)
end




