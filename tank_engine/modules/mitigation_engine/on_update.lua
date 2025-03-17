-- Mitigation Engine Update Logic

-- Fast update for critical operations (called every frame)
function TE.modules.mitigation_engine.on_fast_update()
    -- Skip if not in combat
    if not TE.variables.me:is_in_combat() then
        return
    end
    
    local current_time = core.game_time()
    
    -- Track active mitigation state
    local is_active = TE.modules.mitigation_engine.is_mitigation_active()
    
    -- Update global state
    TE.variables.active_mitigation.is_active = is_active
    if is_active then
        local remaining = TE.modules.mitigation_engine.get_mitigation_remaining()
        TE.variables.active_mitigation.expires_at = current_time + (remaining * 1000) -- Convert to ms
        
        -- Calculate effectiveness based on remaining time
        -- Assume full effectiveness until the last second
        local max_duration = 0
        local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
        for _, ability in ipairs(mitigation_abilities) do
            if ability.buff_id and TE.variables.buff_up(ability.buff_id) and ability.duration then
                max_duration = math.max(max_duration, ability.duration)
            end
        end
        
        if max_duration > 0 then
            TE.variables.active_mitigation.effectiveness = math.min(1.0, remaining / max_duration)
        else
            TE.variables.active_mitigation.effectiveness = 1.0
        end
    else
        TE.variables.active_mitigation.expires_at = 0
        TE.variables.active_mitigation.effectiveness = 0
    end
    
    -- Track when mitigation ends for gap analysis
    if TE.variables.active_mitigation.is_active and TE.modules.mitigation_engine.last_active_state and not is_active then
        TE.modules.mitigation_engine.last_mitigation_end = current_time
    end
    
    -- Update last active state
    TE.modules.mitigation_engine.last_active_state = is_active
    
    -- Update resource availability (fast tracking for responsive UI)
    TE.modules.mitigation_engine.resource_availability = TE.modules.mitigation_engine.check_resource_availability()
end

-- Normal update for less time-critical operations
function TE.modules.mitigation_engine.on_update()
    -- Track combat state changes
    local is_in_combat = TE.variables.me:is_in_combat()
    
    if is_in_combat and not TE.variables.in_combat then
        -- Just entered combat
        TE.variables.in_combat = true
        TE.modules.mitigation_engine.start_combat()
    elseif not is_in_combat and TE.variables.in_combat then
        -- Just left combat
        TE.variables.in_combat = false
        TE.modules.mitigation_engine.end_combat()
    end
    
    if not TE.variables.in_combat then
        return
    end
    
    -- Update mitigation gaps
    TE.modules.mitigation_engine.update_mitigation_gaps()
    
    -- Check if we should use active mitigation
    if TE.modules.mitigation_engine.menu.auto_mitigation:get_state() then
        local spell_id, reason = TE.modules.mitigation_engine.get_optimal_mitigation_ability()
        if spell_id then
            TE.modules.mitigation_engine.use_mitigation_ability(spell_id, reason)
        end
    end
    
    -- Update mitigation uptime data
    local uptime = TE.modules.mitigation_engine.calculate_mitigation_uptime(30) -- 30 second window
    TE.modules.mitigation_engine.mitigation_uptimes[30] = uptime
    
    -- Also track 5 second uptime for short-term analysis
    local short_uptime = TE.modules.mitigation_engine.calculate_mitigation_uptime(5)
    TE.modules.mitigation_engine.mitigation_uptimes[5] = short_uptime
    
    -- Clean up stale data
    TE.modules.mitigation_engine.cleanup_stale_data()
end

-- Combat start handler
function TE.modules.mitigation_engine.start_combat()
    -- Reset mitigation tracking
    TE.modules.mitigation_engine.mitigation_gaps = {}
    TE.modules.mitigation_engine.mitigation_uptimes = {}
    TE.variables.active_mitigation.is_active = false
    TE.variables.active_mitigation.expires_at = 0
    TE.variables.active_mitigation.effectiveness = 0
    
    -- Check initial resource availability
    TE.modules.mitigation_engine.resource_availability = TE.modules.mitigation_engine.check_resource_availability()
    
    core.log("Mitigation Engine: Combat started")
end

-- Combat end handler
function TE.modules.mitigation_engine.end_combat()
    -- Log end-of-combat stats
    local uptime = TE.modules.mitigation_engine.mitigation_uptimes[30] or 0
    core.log(string.format("Mitigation Engine: Combat ended - %.1f%% uptime", uptime))
    
    -- Reset tracking
    TE.modules.mitigation_engine.mitigation_gaps = {}
    TE.modules.mitigation_engine.last_mitigation_end = 0
    TE.variables.active_mitigation.is_active = false
    TE.variables.active_mitigation.expires_at = 0
    TE.variables.active_mitigation.effectiveness = 0
end

-- Update mitigation gaps
function TE.modules.mitigation_engine.update_mitigation_gaps()
    local current_time = core.game_time()
    
    -- Calculate future gap predictions
    local gap_info = TE.modules.mitigation_engine.predict_mitigation_gaps(10) -- Look 10 seconds ahead
    TE.modules.mitigation_engine.mitigation_gaps = gap_info.gaps
    
    -- Detect current gap
    local is_active = TE.modules.mitigation_engine.is_mitigation_active()
    
    if not is_active and TE.modules.mitigation_engine.last_mitigation_end > 0 then
        local gap_duration = (current_time - TE.modules.mitigation_engine.last_mitigation_end) / 1000 -- Convert to seconds
        local gap_tolerance = TE.modules.mitigation_engine.menu.gap_tolerance:get()
        
        -- Check if gap exceeds tolerance
        if gap_duration > gap_tolerance then
            -- Add current gap to history
            table.insert(TE.modules.mitigation_engine.mitigation_gaps, {
                start_time = TE.modules.mitigation_engine.last_mitigation_end,
                end_time = current_time,
                duration = gap_duration,
                can_mitigate = true, -- Since we're in the gap, we can mitigate if we have abilities
                is_current = true
            })
            
            -- Limit history size
            if #TE.modules.mitigation_engine.mitigation_gaps > 10 then
                table.remove(TE.modules.mitigation_engine.mitigation_gaps, 1)
            end
        end
    end
end

-- Clean up stale data
function TE.modules.mitigation_engine.cleanup_stale_data()
    local current_time = core.game_time()
    local max_age = 120000 -- 2 minutes in ms
    
    -- Clean up mitigation history
    local valid_history = {}
    for _, event in ipairs(TE.modules.mitigation_engine.mitigation_history) do
        if current_time - event.start_time <= max_age then
            table.insert(valid_history, event)
        end
    end
    TE.modules.mitigation_engine.mitigation_history = valid_history
    
    -- Clean up gaps
    local valid_gaps = {}
    for _, gap in ipairs(TE.modules.mitigation_engine.mitigation_gaps) do
        if current_time - gap.end_time <= max_age then
            table.insert(valid_gaps, gap)
        end
    end
    TE.modules.mitigation_engine.mitigation_gaps = valid_gaps
end
