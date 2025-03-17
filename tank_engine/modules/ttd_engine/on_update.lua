-- TTD Engine Update Logic

-- Fast update for critical operations (call every frame)
function TE.modules.ttd_engine.on_fast_update()
    -- Skip if not in combat
    if not TE.variables.me:is_in_combat() then
        return
    end
    
    local current_time = core.game_time()
    
    -- Only update every 100ms to avoid excessive calculations
    if current_time - TE.modules.ttd_engine.last_update_time < 100 then
        return
    end
    
    -- Find all valid enemy targets
    local units = core.object_manager.get_all_objects()
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) then
            -- Initialize health history for this unit if needed
            if not TE.modules.ttd_engine.health_history[unit] then
                TE.modules.ttd_engine.health_history[unit] = {}
            end
            
            -- Record current health value
            local current_health = unit:get_health()
            table.insert(TE.modules.ttd_engine.health_history[unit], {
                time = current_time,
                health = current_health,
                max_health = unit:get_max_health()
            })
            
            -- Limit history size to prevent memory bloat
            if #TE.modules.ttd_engine.health_history[unit] > 50 then
                table.remove(TE.modules.ttd_engine.health_history[unit], 1)
            end
        end
    end
    
    TE.modules.ttd_engine.last_update_time = current_time
end

-- Normal update for less time-critical operations
function TE.modules.ttd_engine.on_update()
    -- Track combat state changes
    local is_in_combat = TE.variables.me:is_in_combat()
    
    if is_in_combat and not TE.variables.in_combat then
        -- Just entered combat
        TE.variables.in_combat = true
        TE.modules.ttd_engine.start_combat()
    elseif not is_in_combat and TE.variables.in_combat then
        -- Just left combat
        TE.variables.in_combat = false
        TE.modules.ttd_engine.end_combat()
    end
    
    if not TE.variables.in_combat then
        return
    end
    
    -- Check if we've been in combat long enough
    local combat_time = (core.game_time() - TE.modules.ttd_engine.combat_start_time) / 1000
    if combat_time < TE.modules.ttd_engine.settings.calculation.min_combat_time() then
        return
    end
    
    -- Update TTD values for all tracked units
    TE.modules.ttd_engine.update_ttd_values()
    
    -- Clean up old data
    TE.modules.ttd_engine.cleanup_stale_data()
end

-- Combat start handler
function TE.modules.ttd_engine.start_combat()
    -- Reset TTD tracking
    TE.modules.ttd_engine.health_history = {}
    TE.modules.ttd_engine.damage_rates = {}
    TE.modules.ttd_engine.ttd_values = {}
    TE.modules.ttd_engine.combat_start_time = core.game_time()
    
    core.log("TTD Engine: Combat started")
end

-- Combat end handler
function TE.modules.ttd_engine.end_combat()
    -- Clear TTD tracking
    TE.modules.ttd_engine.health_history = {}
    TE.modules.ttd_engine.damage_rates = {}
    TE.modules.ttd_engine.ttd_values = {}
    
    core.log("TTD Engine: Combat ended")
end

-- Update TTD values for all tracked units
function TE.modules.ttd_engine.update_ttd_values()
    for unit, history in pairs(TE.modules.ttd_engine.health_history) do
        if unit and unit:is_valid() and not unit:is_dead() then
            -- Calculate TTD for this unit
            local ttd = TE.modules.ttd_engine.calculate_enemy_ttd(unit)
            
            -- Store TTD value
            TE.modules.ttd_engine.ttd_values[unit] = ttd
            
            -- Calculate damage rate (health loss per second)
            if #history >= 2 then
                local oldest = history[1]
                local newest = history[#history]
                local time_diff = (newest.time - oldest.time) / 1000 -- Convert to seconds
                local health_diff = oldest.health - newest.health
                
                if time_diff > 0 and health_diff > 0 then
                    local damage_rate = health_diff / time_diff
                    TE.modules.ttd_engine.damage_rates[unit] = damage_rate
                end
            end
        end
    end
end

-- Clean up stale data for units that no longer exist
function TE.modules.ttd_engine.cleanup_stale_data()
    -- Clean up health history
    for unit, _ in pairs(TE.modules.ttd_engine.health_history) do
        if not unit or not unit:is_valid() or unit:is_dead() then
            TE.modules.ttd_engine.health_history[unit] = nil
            TE.modules.ttd_engine.damage_rates[unit] = nil
            TE.modules.ttd_engine.ttd_values[unit] = nil
        end
    end
    
    -- Additionally, prune old health records
    local current_time = core.game_time()
    local max_age = TE.modules.ttd_engine.settings.calculation.regression_window() * 2 * 1000 -- Convert to ms, double window for safety
    
    for unit, history in pairs(TE.modules.ttd_engine.health_history) do
        local valid_entries = {}
        for _, entry in ipairs(history) do
            if current_time - entry.time <= max_age then
                table.insert(valid_entries, entry)
            end
        end
        TE.modules.ttd_engine.health_history[unit] = valid_entries
    end
end
