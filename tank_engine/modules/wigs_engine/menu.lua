-- Wigs Engine Menu
-- UI elements for BigWigs/LittleWigs integration
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Create menu elements if they don't exist yet
if not TE.modules.wigs_engine.menu then
    TE.modules.wigs_engine.menu = {
        main_tree = TE.menu.tree_node(),
        enable_wigs = TE.menu.checkbox(true, "wigs_enable_integration"),
        use_defensive_timers = TE.menu.checkbox(true, "wigs_use_defensive_timers"),
        use_offensive_timers = TE.menu.checkbox(true, "wigs_use_offensive_timers"),
        show_active_timers = TE.menu.checkbox(true, "wigs_show_active_timers"),
        pre_defensive_time = TE.menu.slider_float(1, 10, 3, "wigs_pre_defensive_time"),
    }
end

-- Wigs Engine menu render function
function TE.modules.wigs_engine.menu.on_render_menu()
    TE.modules.wigs_engine.menu.main_tree:render("Wigs Engine [Partial]", function()
        -- Create header
        local header = core.menu.header()
        header:render("BigWigs/LittleWigs Integration", color.cyan())
        
        -- Basic settings
        TE.modules.wigs_engine.menu.enable_wigs:render(
            "Enable Wigs Integration",
            "Use BigWigs/LittleWigs timers to optimize gameplay"
        )
        
        if TE.modules.wigs_engine.menu.enable_wigs:get_state() then
            TE.modules.wigs_engine.menu.use_defensive_timers:render(
                "Use Defensive Timers",
                "Use timers to prepare defensive cooldowns"
            )
            
            if TE.modules.wigs_engine.menu.use_defensive_timers:get_state() then
                TE.modules.wigs_engine.menu.pre_defensive_time:render(
                    "Pre-Defensive Time (s)",
                    "Prepare defensives this many seconds before an ability"
                )
            end
            
            TE.modules.wigs_engine.menu.use_offensive_timers:render(
                "Use Offensive Timers",
                "Use timers to optimize offensive cooldowns"
            )
            
            TE.modules.wigs_engine.menu.show_active_timers:render(
                "Show Active Timers",
                "Display active BigWigs/LittleWigs timers on screen"
            )
        end
        
        -- Development status
        local gui_window = core.menu.window("wigs_engine_window")
        gui_window:add_separator(0, 0, 10, 0, color.gray(150))
        local status_header = core.menu.header()
        status_header:render("Development Status", color.orange())
        local dynamic = gui_window:get_current_context_dynamic_drawing_offset()
        gui_window:render_text(1, vec2.new(dynamic.x, dynamic.y), color.orange(), "This module is partially implemented.")
        gui_window:set_current_context_dynamic_drawing_offset(vec2.new(dynamic.x, dynamic.y + 20))
        gui_window:render_text(1, vec2.new(dynamic.x, dynamic.y), color.white(), "Some features may not be available yet.")
    end)
end

