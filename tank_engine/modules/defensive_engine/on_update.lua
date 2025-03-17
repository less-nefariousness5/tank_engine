-- Defensive Engine Update Logic

---@type health_prediction
local health_prediction = require("common/modules/health_prediction")

-- Fast update for critical operations (called every frame)
function TE.modules.defensive_engine.on_fast_update()
    -- Skip if not in combat
    if not TE.state.get("combat.in_progress") then
        return
    end
    
    local current_time = core.game_time()
    
    -- Get current and previous health from state
    local current_health = TE.state.get("player.health_current")
    local last_health = TE.modules.defensive_engine.last_health or current_health
    
    if last_health > current_health then
        local damage_amount = last_health - current_health
        local max_health = TE.state.get("player.health_max")
        
        -- Only record significant damage (>0.5% of max health)
        if damage_amount > (max_health * 0.005) then
            -- Try to determine damage type (physical vs magical)
            -- This is a simplification - ideally we'd get the actual damage school
            local damage_type = "physical" -- Default assumption
            
            -- Use state system to record damage
            TE.state.record_damage(damage_amount, damage_type)
            
            -- Record damage event for module-specific tracking
            table.insert(TE.modules.defensive_engine.recent_damage_events, {
                time = current_time,
                amount = damage_amount,
                type = damage_type
            })
            
            -- Limit history size
            if #TE.modules.defensive_engine.recent_damage_events > 100 then
                table.remove(TE.modules.defensive_engine.recent_damage_events, 1)
            end
            
            -- Check for damage spikes
            TE.modules.defensive_engine.check_for_damage_spike(damage_amount, current_time)
        end
    end
    
    -- Update last health value
    TE.modules.defensive_engine.last_health = current_health
end

-- Normal update for less time-critical operations
function TE.modules.defensive_engine.on_update()
    -- Check if combat state has changed from state management
    local is_in_combat = TE.state.get("combat.in_progress")
    local was_in_combat = TE.modules.defensive_engine.was_in_combat
    
    if is_in_combat and not was_in_combat then
        -- Just entered combat
        TE.modules.defensive_engine.was_in_combat = true
        TE.modules.defensive_engine.start_combat()
    elseif not is_in_combat and was_in_combat then
        -- Just left combat
        TE.modules.defensive_engine.was_in_combat = false
        TE.modules.defensive_engine.end_combat()
    end
    
    if not is_in_combat then
        return
    end
    
    -- Update available cooldowns
    TE.modules.defensive_engine.update_available_cooldowns()
    
    -- Update damage type distribution
    TE.modules.defensive_engine.update_damage_distribution()
    
    -- Get health percentage from state
    local health_percent = TE.state.get("player.health_percent")
    
    -- Check if we should use a defensive cooldown
    if TE.modules.defensive_engine.menu.auto_defensives:get_state() then
        local cooldown_id, reason = TE.modules.defensive_engine.get_recommended_defensive()
        if cooldown_id then
            TE.modules.defensive_engine.use_defensive_cooldown(cooldown_id, reason)
        end
    end
    
    -- Update state with module-specific information
    TE.state.set("modules.defensive_engine.last_scan_time", core.game_time())
    TE.state.set("modules.defensive_engine.cooldowns_available", TE.modules.defensive_engine.cooldowns_available)
    
    -- Clean up old data
    TE.modules.defensive_engine.cleanup_stale_data()
end

-- Combat start handler
function TE.modules.defensive_engine.start_combat()
    -- Reset defensive tracking
    TE.modules.defensive_engine.incoming_damage_history = {}
    TE.modules.defensive_engine.damage_spikes = {}
    TE.modules.defensive_engine.recent_damage_events = {}
    TE.modules.defensive_engine.last_health = TE.state.get("player.health_current")
    
    -- Initialize damage type distribution
    TE.modules.defensive_engine.damage_type_distribution = {
        physical = 50,
        magical = 50
    }
    
    -- Initialize cooldowns list
    TE.modules.defensive_engine.update_available_cooldowns()
    
    -- Start a new combat session
    local combat_start_time = core.game_time()
    TE.modules.defensive_engine.combat_start_time = combat_start_time
    
    -- Register defensive engine state with state management
    TE.state.register_module("defensive_engine", {
        combat_start_time = combat_start_time,
        damage_spikes = {},
        incoming_damage_total = 0,
        cooldowns_available = {},
        recommendation = nil
    })
    
    core.log("Defensive Engine: Combat started")
end

-- Combat end handler
function TE.modules.defensive_engine.end_combat()
    -- Clear tracking data
    TE.modules.defensive_engine.incoming_damage_history = {}
    TE.modules.defensive_engine.damage_spikes = {}
    TE.modules.defensive_engine.recent_damage_events = {}
    
    core.log("Defensive Engine: Combat ended")
end

-- Check for damage spikes
function TE.modules.defensive_engine.check_for_damage_spike(damage_amount, current_time)
    local max_health = TE.variables.me:get_max_health()
    local damage_percent = (damage_amount / max_health) * 100
    
    -- Only consider significant damage (>5% of max health)
    if damage_percent < 5 then
        return
    end
    
    -- Calculate average damage in last second
    local recent_window = 1000 -- 1 second in ms
    local window_start = current_time - recent_window
    local window_damage = damage_amount
    local damage_events = 1
    
    for i = #TE.modules.defensive_engine.recent_damage_events - 1, 1, -1 do
        local event = TE.modules.defensive_engine.recent_damage_events[i]
        if event.time >= window_start then
            window_damage = window_damage + event.amount
            damage_events = damage_events + 1
        else
            break
        end
    end
    
    local avg_damage = damage_events > 0 and (window_damage / damage_events) or 0
    
    -- Detect spike if current damage is significantly higher than average
    local spike_threshold = TE.modules.defensive_engine.menu.damage_spike_threshold:get() / 10
    if damage_amount > avg_damage * spike_threshold then
        local spike = {
            time = current_time,
            amount = damage_amount,
            percent = damage_percent
        }
        
        table.insert(TE.modules.defensive_engine.damage_spikes, spike)
        
        -- Limit history size
        if #TE.modules.defensive_engine.damage_spikes > 20 then
            table.remove(TE.modules.defensive_engine.damage_spikes, 1)
        end
        
        -- Log spike detection
        core.log(string.format("Defensive Engine: Damage spike detected (%.1f%% of max health)", damage_percent))
    end
end

-- Update available cooldowns
function TE.modules.defensive_engine.update_available_cooldowns()
    TE.modules.defensive_engine.cooldowns_available = {}
    
    -- Collect class-specific defensives
    local physical_defensives = TE.modules.defensive_engine.class_specific_physical_defensives()
    local magical_defensives = TE.modules.defensive_engine.class_specific_magical_defensives()
    local emergency_defensives = TE.modules.defensive_engine.class_specific_emergency_defensives()
    
    -- Combine all defensives
    local all_defensives = {}
    for _, spell_data in ipairs(physical_defensives) do
        table.insert(all_defensives, {
            spell_id = spell_data.spell_id,
            type = "physical",
            priority = spell_data.priority or 1
        })
    end
    
    for _, spell_data in ipairs(magical_defensives) do
        table.insert(all_defensives, {
            spell_id = spell_data.spell_id,
            type = "magical",
            priority = spell_data.priority or 1
        })
    end
    
    for _, spell_data in ipairs(emergency_defensives) do
        table.insert(all_defensives, {
            spell_id = spell_data.spell_id,
            type = "emergency",
            priority = spell_data.priority or 1
        })
    end
    
    -- Check cooldown status for each defensive
    for _, spell_data in ipairs(all_defensives) do
        local cooldown = core.spell_book.get_spell_cooldown(spell_data.spell_id)
        
        TE.modules.defensive_engine.cooldowns_available[spell_data.spell_id] = {
            spell_id = spell_data.spell_id,
            type = spell_data.type,
            cooldown_remaining = cooldown,
            is_available = cooldown <= 0,
            priority = spell_data.priority
        }
    end
end

-- Update damage type distribution
function TE.modules.defensive_engine.update_damage_distribution()
    local current_time = core.game_time()
    local window_size = 5000 -- Last 5 seconds
    local window_start = current_time - window_size
    
    local physical_damage = 0
    local magical_damage = 0
    
    -- Analyze recent damage events
    for _, event in ipairs(TE.modules.defensive_engine.recent_damage_events) do
        if event.time >= window_start then
            if event.type == "physical" then
                physical_damage = physical_damage + event.amount
            else
                magical_damage = magical_damage + event.amount
            end
        end
    end
    
    local total_damage = physical_damage + magical_damage
    
    -- Update distribution if we have damage data
    if total_damage > 0 then
        TE.modules.defensive_engine.damage_type_distribution = {
            physical = (physical_damage / total_damage) * 100,
            magical = (magical_damage / total_damage) * 100
        }
    end
end

-- Use a defensive cooldown
function TE.modules.defensive_engine.use_defensive_cooldown(spell_id, reason)
    if not spell_id then return end
    
    -- Check if spell is castable first
    if not TE.api.spell_helper:is_spell_queueable(spell_id, TE.variables.me, TE.variables.me, true, true) then
        return
    end
    
    -- Queue the spell
    TE.api.spell_queue:queue_spell_target(spell_id, TE.variables.me, 1000, reason)
    
    -- Store the recommendation in state
    TE.state.set("modules.defensive_engine.recommendation", {
        spell_id = spell_id,
        reason = reason,
        time = core.game_time()
    })
    
    -- Log the defensive usage
    local spell_name = core.spell_book.get_spell_name(spell_id) or "Unknown Spell"
    core.log(string.format("Defensive Engine: Using %s (%d) - %s", spell_name, spell_id, reason or ""))
end

-- Clean up stale data
function TE.modules.defensive_engine.cleanup_stale_data()
    local current_time = core.game_time()
    local max_age = 30000 -- 30 seconds in ms
    
    -- Clean up damage events
    local valid_events = {}
    for _, event in ipairs(TE.modules.defensive_engine.recent_damage_events) do
        if current_time - event.time <= max_age then
            table.insert(valid_events, event)
        end
    end
    TE.modules.defensive_engine.recent_damage_events = valid_events
    
    -- Clean up damage spikes
    local valid_spikes = {}
    for _, spike in ipairs(TE.modules.defensive_engine.damage_spikes) do
        if current_time - spike.time <= max_age then
            table.insert(valid_spikes, spike)
        end
    end
    TE.modules.defensive_engine.damage_spikes = valid_spikes
end
