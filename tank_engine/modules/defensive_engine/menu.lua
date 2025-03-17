-- Defensive Engine Menu
-- UI elements for Defensive Engine configuration

---@type color
local color = require("common/color")

-- Defensive Engine menu render function
function TE.modules.defensive_engine.menu.on_render_menu()
    TE.modules.defensive_engine.menu.main_tree:render("Defensive Engine", function()
        -- Automation settings
        TE.menu.render_header(nil, "Automation Settings")
        
        TE.modules.defensive_engine.menu.auto_defensives:render(
            "Auto Defensive Cooldowns",
            "Automatically use defensive cooldowns when appropriate"
        )
        
        TE.modules.defensive_engine.menu.enable_boss_detection:render(
            "Enable Boss Ability Detection",
            "Use BigWigs/LittleWigs to detect incoming boss abilities"
        )
        
        -- Threshold settings
        TE.menu.render_header(nil, "Threshold Settings")
        
        TE.modules.defensive_engine.menu.health_threshold:render(
            "Health Threshold (%)",
            "Health percentage to consider using normal defensive cooldowns"
        )
        
        TE.modules.defensive_engine.menu.low_health_threshold:render(
            "Low Health Threshold (%)",
            "Health percentage to consider using emergency defensive cooldowns"
        )
        
        TE.modules.defensive_engine.menu.damage_spike_threshold:render(
            "Damage Spike Detection",
            "Higher values require larger damage spikes to trigger detection"
        )
        
        -- Advanced settings
        TE.menu.render_header(nil, "Advanced Settings")
        
        TE.modules.defensive_engine.menu.anticipation_window:render(
            "Anticipation Window (s)",
            "How far ahead to predict incoming damage"
        )
        
        TE.modules.defensive_engine.menu.prioritize_physical:render(
            "Prioritize Physical Defensives",
            "Prioritize physical damage defensives over magical ones"
        )
        
        -- Debug information if appropriate
        if TE.settings.is_enabled() then
            TE.menu.render_header(nil, "Debug Information")
            
            -- Current health
            local health_percent = TE.variables.health_percent()
            core.graphics.text_2d(string.format("Health: %.1f%%", health_percent), 
                                vec2.new(400, TE.menu.window_style.padding.y + 330),
                                14, health_percent < 50 and color.red(200) or color.green(200), true)
            
            -- Damage distribution
            local phys_percent = TE.modules.defensive_engine.damage_type_distribution.physical or 50
            local magic_percent = TE.modules.defensive_engine.damage_type_distribution.magical or 50
            
            core.graphics.text_2d(string.format("Damage: %.1f%% Physical, %.1f%% Magical", phys_percent, magic_percent), 
                                vec2.new(400, TE.menu.window_style.padding.y + 350),
                                14, color.gray(200), true)
            
            -- Detected spikes
            local spike_count = #TE.modules.defensive_engine.damage_spikes
            local latest_spike = spike_count > 0 and TE.modules.defensive_engine.damage_spikes[spike_count] or nil
            local spike_text = latest_spike and string.format("Last Spike: %.1f%% (%.1fs ago)", 
                                latest_spike.percent,
                                (core.game_time() - latest_spike.time) / 1000)
                                or "No recent spikes"
                                
            core.graphics.text_2d(spike_text, 
                                vec2.new(400, TE.menu.window_style.padding.y + 370),
                                14, color.gray(200), true)
        end
    end)
end

-- Render function for defensive visualization
function TE.modules.defensive_engine.on_render()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- We could add visual indicators for:
    -- 1. Damage type distribution
    -- 2. Recent damage spikes
    -- 3. Defensive cooldown recommendations
    -- 4. Incoming damage forecasts
    
    -- For now, we'll keep this simple
end
