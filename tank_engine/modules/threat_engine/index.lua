-- Threat Engine Module
-- Manages threat tracking and taunt optimization

-- Create module table in the TE namespace if it doesn't exist
if not TE.modules.threat_engine then
    TE.modules.threat_engine = {
        -- State tracking
        targets = {},        -- Current threat targets
        
        -- Menu elements
        menu = {
            main_tree = core.menu.tree_node(),
            warning_threshold = core.menu.slider_float(0, 130, 90, "threat_warning_threshold"),
            taunt_threshold = core.menu.slider_float(0, 130, 110, "threat_taunt_threshold"),
            auto_taunt = core.menu.checkbox(true, "threat_auto_taunt"),
            show_threat_warnings = core.menu.checkbox(true, "threat_show_warnings"),
        },
    }
end

-- Load module files
require("modules/threat_engine/menu")
require("modules/threat_engine/on_update")

-- Menu render function
function TE.modules.threat_engine.menu.on_render_menu()
    TE.modules.threat_engine.menu.main_tree:render("Threat Management", function()
        TE.modules.threat_engine.menu.warning_threshold:render("Warning Threshold", "Show warnings when threat exceeds this percentage")
        TE.modules.threat_engine.menu.taunt_threshold:render("Taunt Threshold", "Automatically taunt when threat exceeds this percentage")
        TE.modules.threat_engine.menu.auto_taunt:render("Auto Taunt", "Automatically taunt targets when threshold is exceeded")
        TE.modules.threat_engine.menu.show_threat_warnings:render("Show Warnings", "Display threat warnings in the log")
    end)
end

-- Module interface for main system
return {
    on_update = TE.modules.threat_engine.on_index_update,
    on_render_menu = TE.modules.threat_engine.menu.on_render_menu
}

