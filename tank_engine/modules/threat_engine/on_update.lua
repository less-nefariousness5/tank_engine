-- Threat Engine Update Logic

-- Fast update for critical operations
function TE.modules.threat_engine.on_fast_update()
    -- Skip if not in combat
    if not TE.variables.me:is_in_combat() then
        return
    end
    
    -- Refresh threat status for active targets
    local units = core.object_manager.get_all_objects()
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and unit:can_attack(TE.variables.me) then
            -- Get threat situation
            local threat = unit:get_threat_situation(TE.variables.me)
            
            if threat then
                -- Update threat values table
                TE.modules.threat_engine.threat_values[unit] = {
                    is_tanking = threat.is_tanking,
                    status = threat.status,
                    percent = threat.threat_percent,
                    value = threat.threat_percent -- For now, we use percent as value
                }
                
                -- Update losing threat list
                if threat.is_tanking and threat.threat_percent < TE.modules.threat_engine.menu.warning_threshold:get() then
                    TE.modules.threat_engine.losing_threat_targets[unit] = threat.threat_percent
                else
                    TE.modules.threat_engine.losing_threat_targets[unit] = nil
                end
                
                -- Count enemies targeting tank (has aggro)
                if threat.is_tanking then
                    TE.variables.threat_status.aggro_targets = TE.variables.threat_status.aggro_targets + 1
                end
            end
        end
    end
    
    -- Update global threat status
    TE.variables.threat_status.has_aggro = TE.variables.threat_status.aggro_targets > 0
    TE.variables.threat_status.losing_aggro = next(TE.modules.threat_engine.losing_threat_targets) ~= nil
end

-- Normal update for less time-critical operations
function TE.modules.threat_engine.on_update()
    -- Track combat state changes
    local is_in_combat = TE.variables.me:is_in_combat()
    
    if is_in_combat and not TE.variables.in_combat then
        -- Just entered combat
        TE.variables.in_combat = true
        TE.modules.threat_engine.start_combat()
    elseif not is_in_combat and TE.variables.in_combat then
        -- Just left combat
        TE.variables.in_combat = false
        TE.modules.threat_engine.end_combat()
    end
    
    if not TE.variables.in_combat then
        return
    end
    
    -- Update high priority targets list
    TE.modules.threat_engine.update_priority_targets()
    
    -- Check for offtank presence
    TE.modules.threat_engine.check_for_offtank()
end

-- Combat start handler
function TE.modules.threat_engine.start_combat()
    -- Reset threat tracking
    TE.modules.threat_engine.threat_values = {}
    TE.modules.threat_engine.losing_threat_targets = {}
    TE.modules.threat_engine.high_priority_targets = {}
    
    -- Reset threat status
    TE.variables.threat_status.has_aggro = false
    TE.variables.threat_status.losing_aggro = false
    TE.variables.threat_status.aggro_targets = 0
    
    core.log("Threat Engine: Combat started")
end

-- Combat end handler
function TE.modules.threat_engine.end_combat()
    -- Clear threat tracking
    TE.modules.threat_engine.threat_values = {}
    TE.modules.threat_engine.losing_threat_targets = {}
    TE.modules.threat_engine.high_priority_targets = {}
    
    -- Reset threat status
    TE.variables.threat_status.has_aggro = false
    TE.variables.threat_status.losing_aggro = false
    TE.variables.threat_status.aggro_targets = 0
    
    core.log("Threat Engine: Combat ended")
end

-- Update high priority targets
function TE.modules.threat_engine.update_priority_targets()
    TE.modules.threat_engine.high_priority_targets = {}
    
    -- First, add targets that are losing threat
    for unit, percent in pairs(TE.modules.threat_engine.losing_threat_targets) do
        if unit and unit:is_valid() and not unit:is_dead() then
            table.insert(TE.modules.threat_engine.high_priority_targets, {
                unit = unit,
                priority = (100 - percent) / 10, -- Higher priority for lower threat
                reason = "Losing threat"
            })
        end
    end
    
    -- Add casting units as high priority
    for unit, _ in pairs(TE.modules.threat_engine.threat_values) do
        if unit and unit:is_valid() and not unit:is_dead() and unit:is_casting_spell() then
            local already_added = false
            for _, entry in ipairs(TE.modules.threat_engine.high_priority_targets) do
                if entry.unit == unit then
                    already_added = true
                    break
                end
            end
            
            if not already_added then
                table.insert(TE.modules.threat_engine.high_priority_targets, {
                    unit = unit,
                    priority = 8, -- High priority for casters
                    reason = "Casting spell"
                })
            end
        end
    end
    
    -- Sort by priority (descending)
    table.sort(TE.modules.threat_engine.high_priority_targets, function(a, b)
        return a.priority > b.priority
    end)
end

-- Check for offtank
function TE.modules.threat_engine.check_for_offtank()
    if not TE.modules.threat_engine.menu.track_offtank:get_state() then
        return
    end
    
    local group_members = {}
    local units = core.object_manager.get_all_objects()
    
    -- Find group members
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and unit:is_player() and unit:is_party_member() and unit ~= TE.variables.me then
            table.insert(group_members, unit)
        end
    end
    
    -- Check for tanks in group
    TE.variables.group.has_offtank = false
    TE.variables.group.offtank = nil
    
    for _, unit in ipairs(group_members) do
        if unit:get_group_role() == 0 then -- Tank role
            TE.variables.group.has_offtank = true
            TE.variables.group.offtank = unit
            break
        end
    end
end
