-- Pull Engine Menu
-- UI elements for Pull Engine configuration

---@type color
local color = require("common/color")

-- Pull Engine menu render function
function TE.modules.pull_engine.menu.on_render_menu()
    TE.modules.pull_engine.menu.main_tree:render("Pull Engine", function()
        -- Automation settings
        TE.menu.render_header(nil, "Automation Settings")
        
        TE.modules.pull_engine.menu.auto_pull:render(
            "Auto Pull",
            "Automatically pull enemies"
        )
        
        -- Target selection combobox options
        local selection_options = {
            "Closest First",
            "Smallest Pack First",
            "Optimal Pack Size",
            "Lowest Danger First"
        }
        
        TE.modules.pull_engine.menu.pull_target_selection:render(
            "Pull Target Selection",
            selection_options,
            "Method used to select which enemies to pull"
        )
        
        -- Pull size settings
        TE.menu.render_header(nil, "Pull Configuration")
        
        TE.modules.pull_engine.menu.pull_size:render(
            "Pull Size",
            "Number of enemies to pull at once"
        )
        
        TE.modules.pull_engine.menu.pull_cooldown:render(
            "Pull Cooldown (s)",
            "Time to wait between automatic pulls"
        )
        
        TE.modules.pull_engine.menu.max_pull_distance:render(
            "Maximum Pull Distance",
            "Maximum distance to consider targets for pulling"
        )
        
        TE.modules.pull_engine.menu.danger_threshold:render(
            "Danger Threshold",
            "Maximum danger score for automatic pulls"
        )
        
        -- Advanced settings
        TE.menu.render_header(nil, "Advanced Settings")
        
        TE.modules.pull_engine.menu.use_los_pulling:render(
            "Use LoS Pulling",
            "Pull enemies using line-of-sight mechanics"
        )
        
        TE.modules.pull_engine.menu.enable_path_analysis:render(
            "Enable Path Analysis",
            "Analyze patrol paths for better pull timing"
        )
        
        -- Display settings
        TE.menu.render_header(nil, "Display Settings")
        
        TE.modules.pull_engine.menu.show_pull_planning:render(
            "Show Pull Planning",
            "Display pull planning information in the world"
        )
        
        -- Debug information if appropriate
        if TE.settings.is_enabled() then
            TE.menu.render_header(nil, "Debug Information")
            
            -- Current pull status
            local pull_status = TE.modules.pull_engine.current_pull.in_progress 
                              and string.format("In progress (%d targets)", #TE.modules.pull_engine.current_pull.targets) 
                              or "Not pulling"
            
            core.graphics.text_2d("Pull Status: " .. pull_status, 
                                 vec2.new(400, TE.menu.window_style.padding.y + 330),
                                 14, TE.modules.pull_engine.current_pull.in_progress and color.yellow(200) or color.green(200), true)
            
            -- Pull metrics
            local metrics = TE.modules.pull_engine.metrics
            local metrics_text = string.format("Avg: %.1fs, %.1f enemies, %.1f DPS", 
                                             metrics.avg_pull_time,
                                             metrics.avg_pull_size,
                                             metrics.group_dps)
            
            core.graphics.text_2d(metrics_text, 
                                 vec2.new(400, TE.menu.window_style.padding.y + 350),
                                 14, color.gray(200), true)
            
            -- Nearby packs
            local pack_count = #TE.modules.pull_engine.enemy_packs
            core.graphics.text_2d(string.format("Enemy Packs: %d", pack_count), 
                                 vec2.new(400, TE.menu.window_style.padding.y + 370),
                                 14, pack_count > 0 and color.yellow(200) or color.green(200), true)
        end
    end)
end

-- Render function for pull engine visualization
function TE.modules.pull_engine.on_render()
    if not TE.settings.is_enabled() or not TE.modules.pull_engine.menu.show_pull_planning:get_state() then
        return
    end
    
    -- Draw LOS pull points if available
    if TE.modules.pull_engine.los_pull_points.target_position and 
       TE.modules.pull_engine.los_pull_points.pull_position then
        
        local target_pos = TE.modules.pull_engine.los_pull_points.target_position
        local pull_pos = TE.modules.pull_engine.los_pull_points.pull_position
        
        -- Convert to screen positions
        local target_screen = core.graphics.w2s(target_pos)
        local pull_screen = core.graphics.w2s(pull_pos)
        
        if target_screen and pull_screen then
            -- Draw line connecting the points
            core.graphics.line_2d(target_screen, pull_screen, color.yellow(180), 2)
            
            -- Draw points
            core.graphics.circle_2d_filled(target_screen, 5, color.red(200))
            core.graphics.circle_2d_filled(pull_screen, 5, color.green(200))
            
            -- Draw labels
            core.graphics.text_2d("Target", 
                                vec2.new(target_screen.x, target_screen.y - 15),
                                12, color.white(200), true)
            
            core.graphics.text_2d("Pull Position", 
                                vec2.new(pull_screen.x, pull_screen.y - 15),
                                12, color.white(200), true)
        end
        
        -- Draw 3D visualization
        core.graphics.line_3d(target_pos, pull_pos, color.yellow(180), 2)
        core.graphics.circle_3d(target_pos, 1, color.red(200), 2)
        core.graphics.circle_3d(pull_pos, 1, color.green(200), 2)
    end
    
    -- Draw enemy packs
    for i, pack in ipairs(TE.modules.pull_engine.enemy_packs) do
        -- Only show the first 3 packs to avoid clutter
        if i > 3 then
            break
        end
        
        -- Choose color based on danger score
        local pack_color
        if pack.danger_score >= 80 then
            pack_color = color.red(180)
        elseif pack.danger_score >= 50 then
            pack_color = color.orange(180)
        else
            pack_color = color.green(180)
        end
        
        -- Draw center unit
        local center_pos = pack.center:get_position()
        core.graphics.circle_3d(center_pos, 1, pack_color, 2)
        
        -- Draw lines to all units in pack
        for _, unit in ipairs(pack.units) do
            if unit ~= pack.center and unit:is_valid() and not unit:is_dead() then
                local unit_pos = unit:get_position()
                core.graphics.line_3d(center_pos, unit_pos, pack_color, 1)
            end
        end
        
        -- Draw danger score above pack
        local screen_pos = core.graphics.w2s(center_pos)
        if screen_pos then
            core.graphics.text_2d(string.format("Pack %d: %d units - Danger: %.0f", 
                                             i, #pack.units, pack.danger_score),
                                vec2.new(screen_pos.x, screen_pos.y - 30),
                                12, pack_color, true)
        end
    end
    
    -- Show patrol paths
    if TE.modules.pull_engine.menu.enable_path_analysis:get_state() then
        for unit, data in pairs(TE.modules.pull_engine.patrol_timings) do
            if unit and unit:is_valid() and not unit:is_dead() and data.is_patrolling then
                -- Draw patrol center and radius
                core.graphics.circle_3d(data.patrol_center, data.patrol_radius, color.blue(150), 1)
                
                -- Draw current position
                local unit_pos = unit:get_position()
                core.graphics.circle_3d(unit_pos, 0.5, color.blue(200), 2)
                
                -- Draw patrol path based on recorded positions
                if #data.positions >= 2 then
                    for i = 1, #data.positions - 1 do
                        local pos1 = data.positions[i].position
                        local pos2 = data.positions[i + 1].position
                        core.graphics.line_3d(pos1, pos2, color.blue(150), 1)
                    end
                end
                
                -- Show patrol info on nameplate
                local screen_pos = core.graphics.w2s(unit_pos)
                if screen_pos then
                    core.graphics.text_2d("Patrolling", 
                                        vec2.new(screen_pos.x, screen_pos.y - 20),
                                        10, color.blue(200), true)
                end
            end
        end
    end
    
    -- Show scheduled pull
    if TE.modules.pull_engine.scheduled_pull and 
       TE.modules.pull_engine.scheduled_pull.target and 
       TE.modules.pull_engine.scheduled_pull.target:is_valid() and 
       not TE.modules.pull_engine.scheduled_pull.target:is_dead() then
        
        local target = TE.modules.pull_engine.scheduled_pull.target
        local target_pos = target:get_position()
        local method = TE.modules.pull_engine.scheduled_pull.method
        
        -- Draw 3D indicator
        core.graphics.circle_3d(target_pos, 2, color.yellow(200), 2)
        
        -- Draw method text
        local screen_pos = core.graphics.w2s(target_pos)
        if screen_pos then
            core.graphics.text_2d("PULL TARGET (" .. method .. ")", 
                                 vec2.new(screen_pos.x, screen_pos.y - 40),
                                 14, color.yellow(230), true)
        end
    end
end
