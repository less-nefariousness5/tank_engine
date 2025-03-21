-- Interrupt Engine Update Logic

-- Fast update for critical operations (called every frame)
function TE.modules.interrupt_engine.on_fast_update()
    -- Skip if not in combat
    if not TE.variables.me:is_in_combat() then
        return
    end
    
    local current_time = core.game_time()
    
    -- Scan for units that are casting interruptible spells
    local units = core.object_manager.get_all_objects()
    local interrupt_targets = {}
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) then
            if unit:is_casting_spell() and unit:is_active_spell_interruptable() then
                local spell_id = unit:get_active_spell_id()
                local cast_end_time = unit:get_active_spell_cast_end_time()
                
                -- Only consider spells that still have time to interrupt
                if cast_end_time > current_time + 200 then -- 200ms buffer
                    -- Calculate priority
                    local danger_score = TE.modules.interrupt_engine.calculate_cast_danger(spell_id)
                    local remaining_cast_time = (cast_end_time - current_time) / 1000 -- Convert to seconds
                    
                    -- Prioritize spells that are about to finish casting
                    local time_urgency = 1 + math.max(0, (3 - remaining_cast_time) / 3)
                    
                    -- Prioritize dangerous spells
                    local danger_factor = danger_score / 50 -- Normalize to a factor around 1
                    
                    -- Combined priority score
                    local priority = danger_score * time_urgency * danger_factor
                    
                    -- Add to interrupt targets
                    interrupt_targets[unit] = {
                        spell_id = spell_id,
                        cast_end_time = cast_end_time,
                        remaining_time = remaining_cast_time,
                        danger_score = danger_score,
                        priority = priority
                    }
                end
            end
        end
    end
    
    -- Update interrupt targets
    TE.modules.interrupt_engine.interrupt_targets = interrupt_targets
end

-- Normal update for less time-critical operations
function TE.modules.interrupt_engine.on_normal_update()
    -- Track combat state changes
    local is_in_combat = TE.variables.me:is_in_combat()
    
    if is_in_combat and not TE.variables.in_combat then
        -- Just entered combat
        TE.variables.in_combat = true
        TE.modules.interrupt_engine.start_combat()
    elseif not is_in_combat and TE.variables.in_combat then
        -- Just left combat
        TE.variables.in_combat = false
        TE.modules.interrupt_engine.end_combat()
    end
    
    if not TE.variables.in_combat then
        return
    end
    
    -- Scan for potential CC targets
    TE.modules.interrupt_engine.update_cc_targets()
    
    -- Check if we should interrupt or CC
    if TE.modules.interrupt_engine.menu.auto_interrupt:get_state() then
        local target, spell_id = TE.modules.interrupt_engine.get_high_priority_interrupt()
        if target and spell_id then
            TE.modules.interrupt_engine.interrupt_spell(target, spell_id)
        end
    end
    
    if TE.modules.interrupt_engine.menu.auto_cc:get_state() then
        local target, spell_id = TE.modules.interrupt_engine.get_optimal_cc_target()
        if target and spell_id then
            TE.modules.interrupt_engine.apply_crowd_control(target, spell_id)
        end
    end
    
    -- Clean up stale data
    TE.modules.interrupt_engine.cleanup_stale_data()
end

-- Combat start handler
function TE.modules.interrupt_engine.start_combat()
    -- Reset interrupt tracking
    TE.modules.interrupt_engine.interrupt_targets = {}
    TE.modules.interrupt_engine.cc_targets = {}
    
    core.log("Interrupt Engine: Combat started")
end

-- Combat end handler
function TE.modules.interrupt_engine.end_combat()
    -- Log end-of-combat stats
    local interrupt_count = #TE.modules.interrupt_engine.interrupt_history
    local cc_count = #TE.modules.interrupt_engine.cc_history
    
    if interrupt_count > 0 or cc_count > 0 then
        core.log(string.format("Interrupt Engine: Combat ended - %d interrupts, %d CCs", 
                              interrupt_count, cc_count))
    end
    
    -- Reset tracking
    TE.modules.interrupt_engine.interrupt_targets = {}
    TE.modules.interrupt_engine.cc_targets = {}
end

-- Update crowd control targets
function TE.modules.interrupt_engine.update_cc_targets()
    local cc_targets = {}
    local danger_threshold = TE.modules.interrupt_engine.menu.danger_threshold:get()
    
    -- Get nearby attackable units
    local units = core.object_manager.get_all_objects()
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) then
            -- Skip units that are already under CC
            if TE.modules.interrupt_engine.is_under_cc(unit) then
                goto continue
            end
            
            -- Don't CC current tank target unless configured to
            if unit == TE.variables.target() and not TE.modules.interrupt_engine.menu.cc_tank_target then
                goto continue
            end
            
            -- Calculate CC priority score
            local health_percent = unit:get_health() / unit:get_max_health() * 100
            local is_casting = unit:is_casting_spell()
            local is_elite = unit:get_classification() >= 1 -- Elite or higher
            
            -- Base score
            local score = 50
            
            -- Adjust based on health
            if health_percent < 30 then
                score = score + 10 -- Higher priority for low health targets
            elseif health_percent > 70 then
                score = score + 5 -- Higher priority for high health targets
            end
            
            -- Adjust based on status
            if is_casting then
                score = score + 15 -- Casters are higher priority
            end
            
            -- Adjust based on type
            if is_elite then
                score = score + 20 -- Elites are higher priority
            end
            
            -- Only consider high-danger targets
            if score >= danger_threshold then
                cc_targets[unit] = {
                    score = score,
                    health_percent = health_percent,
                    is_casting = is_casting,
                    is_elite = is_elite
                }
            end
        end
        
        ::continue::
    end
    
    -- Update CC targets
    TE.modules.interrupt_engine.cc_targets = cc_targets
end

-- Check if a unit is under crowd control
function TE.modules.interrupt_engine.is_under_cc(unit)
    if not unit or not unit:is_valid() then
        return false
    end
    
    -- Check for common CC debuffs
    local cc_debuffs = {
        5782,  -- Fear
        118,   -- Polymorph
        51514, -- Hex
        6770,  -- Sap
        2094,  -- Blind
        605,   -- Mind Control
        853,   -- Hammer of Justice
        -- Add more as needed
    }
    
    for _, debuff_id in ipairs(cc_debuffs) do
        if TE.variables.buff_up(debuff_id, unit) then
            return true
        end
    end
    
    return false
end

-- Clean up stale data
function TE.modules.interrupt_engine.cleanup_stale_data()
    local current_time = core.game_time()
    local max_age = 600000 -- 10 minutes in ms
    
    -- Clean up interrupt history
    local valid_interrupts = {}
    for _, event in ipairs(TE.modules.interrupt_engine.interrupt_history) do
        if current_time - event.time <= max_age then
            table.insert(valid_interrupts, event)
        end
    end
    TE.modules.interrupt_engine.interrupt_history = valid_interrupts
    
    -- Clean up CC history
    local valid_ccs = {}
    for _, event in ipairs(TE.modules.interrupt_engine.cc_history) do
        if current_time - event.time <= max_age then
            table.insert(valid_ccs, event)
        end
    end
    TE.modules.interrupt_engine.cc_history = valid_ccs
end
