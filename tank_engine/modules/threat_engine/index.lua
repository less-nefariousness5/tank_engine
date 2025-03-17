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

-- Update function called every frame
function TE.modules.threat_engine.on_update()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or not me:is_in_combat() then
        return
    end
    
    -- Get current target
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    -- Get threat situation
    local threat_status = me:get_threat_situation(target)
    if not threat_status then
        return
    end
    
    -- Store threat data
    TE.modules.threat_engine.targets[target] = {
        threat_percent = threat_status.threat_percent,
        is_tanking = threat_status.is_tanking,
        status = threat_status.status,
        last_update = core.game_time()
    }
    
    -- Check threat thresholds
    local warning_threshold = TE.modules.threat_engine.menu.warning_threshold:get()
    local taunt_threshold = TE.modules.threat_engine.menu.taunt_threshold:get()
    
    if TE.modules.threat_engine.menu.show_threat_warnings:get_state() then
        if not threat_status.is_tanking and threat_status.threat_percent > warning_threshold then
            core.log("Warning: High threat on " .. target:get_name() .. " (" .. math.floor(threat_status.threat_percent) .. "%)")
        end
    end
    
    -- Auto taunt logic
    if TE.modules.threat_engine.menu.auto_taunt:get_state() then
        -- This would require checking for taunt ability availability and using it
        -- Simplified version for now just logs the need to taunt
        if not threat_status.is_tanking and threat_status.threat_percent > taunt_threshold then
            core.log("Tank Engine: Should taunt " .. target:get_name() .. " now!")
        end
    end
end

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
    on_update = TE.modules.threat_engine.on_update,
    on_render_menu = TE.modules.threat_engine.menu.on_render_menu
}
