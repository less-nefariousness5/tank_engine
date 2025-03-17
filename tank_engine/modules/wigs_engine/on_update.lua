-- Wigs Engine Update Logic
-- Integrates with BigWigs/LittleWigs timers for boss ability optimization

-- Fast update for critical operations (called every frame)
function TE.modules.wigs_engine.on_fast_update()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Placeholder for future implementation
    -- This would respond to imminent boss abilities
end

-- Normal update for less time-critical operations
function TE.modules.wigs_engine.on_update()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Initialize timer data if needed
    if not TE.modules.wigs_engine.active_timers then
        TE.modules.wigs_engine.active_timers = {}
    end
    
    -- Use wigs_tracker to get bars
    local wigs_available = TE.api and TE.api.wigs_tracker
    if wigs_available then
        -- Get all active bars from BigWigs/LittleWigs
        local bars = TE.api.wigs_tracker:get_all()
        
        -- Process bars
        for _, bar in pairs(bars) do
            if bar then
                -- Store in our tracking system
                TE.modules.wigs_engine.active_timers[bar.key] = {
                    text = bar.text,
                    remaining = bar.expire_time - core.game_time(),
                    duration = bar.duration,
                    created_at = bar.created_at,
                    expire_time = bar.expire_time
                }
                
                -- Check for defensive timing
                if TE.modules.wigs_engine.menu and 
                   TE.modules.wigs_engine.menu.use_defensive_timers and
                   TE.modules.wigs_engine.menu.use_defensive_timers:get_state() and
                   TE.modules.wigs_engine.menu.pre_defensive_time then
                    
                    local pre_time = TE.modules.wigs_engine.menu.pre_defensive_time:get() * 1000 -- ms
                    local remaining = bar.expire_time - core.game_time()
                    
                    -- If ability is about to happen and is a dangerous ability
                    if remaining <= pre_time and TE.modules.wigs_engine.is_dangerous_ability(bar.text) then
                        -- Log defensive warning
                        core.log("DEFENSIVE WARNING: " .. bar.text .. " in " .. 
                                math.floor(remaining / 1000) .. " seconds")
                    end
                end
            end
        end
        
        -- Clean up expired timers
        local current_time = core.game_time()
        for key, timer in pairs(TE.modules.wigs_engine.active_timers) do
            if timer.expire_time < current_time then
                TE.modules.wigs_engine.active_timers[key] = nil
            end
        end
    end
end

-- Helper function to determine if an ability is dangerous
function TE.modules.wigs_engine.is_dangerous_ability(ability_text)
    -- This would be a comprehensive database of dangerous abilities
    -- For now, we'll just check for common dangerous ability keywords
    local dangerous_keywords = {
        "smash", "cleave", "explosion", "storm", "breath", "blast", "wave",
        "eruption", "slam", "crush", "destruction", "annihilation", "obliteration"
    }
    
    ability_text = ability_text:lower()
    
    for _, keyword in ipairs(dangerous_keywords) do
        if ability_text:find(keyword) then
            return true
        end
    end
    
    return false
end

-- Render active timers on screen
function TE.modules.wigs_engine.on_render()
    if not TE.settings.is_enabled() or 
       not TE.modules.wigs_engine.menu or 
       not TE.modules.wigs_engine.menu.show_active_timers or
       not TE.modules.wigs_engine.menu.show_active_timers:get_state() then
        return
    end
    
    -- Example of drawing timer info
    local timers = {}
    for _, timer in pairs(TE.modules.wigs_engine.active_timers or {}) do
        table.insert(timers, timer)
    end
    
    -- Sort by remaining time
    table.sort(timers, function(a, b)
        return a.remaining < b.remaining
    end)
    
    -- Draw timers
    local y_pos = 200
    for _, timer in ipairs(timers) do
        local remaining_sec = math.max(0, timer.remaining / 1000)
        
        -- Create display text
        local timer_text = timer.text .. ": " .. string.format("%.1f", remaining_sec) .. "s"
        
        -- Choose color based on time remaining
        local text_color
        if remaining_sec < 3 then
            text_color = color.red(255)
        elseif remaining_sec < 8 then
            text_color = color.yellow(255)
        else
            text_color = color.white(255)
        end
        
        -- Draw text
        core.graphics.text_2d(timer_text, vec2.new(400, y_pos), 14, text_color)
        y_pos = y_pos + 20
    end
end
