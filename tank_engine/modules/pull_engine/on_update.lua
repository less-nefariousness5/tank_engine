-- Pull Engine Update Logic
---@type vec3
local vec3 = require("common/geometry/vector_3")

-- Fast update for critical operations (called every frame)
function TE.modules.pull_engine.on_fast_update()
    -- Skip if disabled
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Track current pull
    if TE.modules.pull_engine.current_pull.in_progress then
        TE.modules.pull_engine.update_current_pull()
    end
    
    -- Handle scheduled pull
    if TE.modules.pull_engine.scheduled_pull then
        local current_time = core.game_time()
        
        if current_time >= TE.modules.pull_engine.scheduled_pull.time then
            -- Execute the scheduled pull
            TE.modules.pull_engine.execute_pull(
                TE.modules.pull_engine.scheduled_pull.target,
                TE.modules.pull_engine.scheduled_pull.method
            )
            
            -- Clear scheduled pull
            TE.modules.pull_engine.scheduled_pull = nil
        end
    end
end

-- Normal update for less time-critical operations
function TE.modules.pull_engine.on_update()
    -- Track combat state changes
    local is_in_combat = TE.variables.me:is_in_combat()
    
    if is_in_combat and not TE.variables.in_combat then
        -- Just entered combat
        TE.variables.in_combat = true
        TE.modules.pull_engine.start_combat()
    elseif not is_in_combat and TE.variables.in_combat then
        -- Just left combat
        TE.variables.in_combat = false
        TE.modules.pull_engine.end_combat()
    end
    
    -- Auto-pull logic
    if not TE.variables.in_combat and TE.modules.pull_engine.menu.auto_pull:get_state() then
        -- Check if we're on cooldown from a previous pull
        local current_time = core.game_time()
        local last_pull_end = TE.modules.pull_engine.last_pull_end or 0
        local pull_cooldown = TE.modules.pull_engine.menu.pull_cooldown:get() * 1000 -- Convert to ms
        
        if current_time >= last_pull_end + pull_cooldown then
            -- Look for a target to pull
            local target = TE.modules.pull_engine.find_optimal_pull_target()
            
            if target then
                -- Determine pull method
                local method = "direct"
                
                if TE.modules.pull_engine.menu.use_los_pulling:get_state() then
                    method = "los"
                elseif TE.modules.pull_engine.get_ranged_pull_ability() then
                    method = "ranged"
                end
                
                -- Schedule the pull
                TE.modules.pull_engine.scheduled_pull = {
                    target = target,
                    method = method,
                    time = current_time + 500 -- Small delay to give time for decision making
                }
            end
        end
    end
    
    -- Update enemy packs
    TE.modules.pull_engine.update_enemy_packs()
    
    -- Update patrol timings
    TE.modules.pull_engine.update_patrol_timings()
    
    -- Clean up stale data
    TE.modules.pull_engine.cleanup_stale_data()
end

-- Combat start handler
function TE.modules.pull_engine.start_combat()
    -- Reset pull tracking if not already in a pull
    if not TE.modules.pull_engine.current_pull.in_progress then
        TE.modules.pull_engine.current_pull.in_progress = true
        TE.modules.pull_engine.current_pull.start_time = core.game_time()
        TE.modules.pull_engine.current_pull.targets = {}
        TE.modules.pull_engine.current_pull.total_health = 0
        TE.modules.pull_engine.current_pull.expected_ttd = 30
    end
    
    -- Clear scheduled pull
    TE.modules.pull_engine.scheduled_pull = nil
    
    core.log("Pull Engine: Combat started")
end

-- Combat end handler
function TE.modules.pull_engine.end_combat()
    -- Process and store pull data if it was in progress
    if TE.modules.pull_engine.current_pull.in_progress then
        local current_time = core.game_time()
        local pull_duration = (current_time - TE.modules.pull_engine.current_pull.start_time) / 1000 -- Convert to seconds
        
        -- Record pull
        table.insert(TE.modules.pull_engine.pull_history, {
            start_time = TE.modules.pull_engine.current_pull.start_time,
            end_time = current_time,
            duration = pull_duration,
            targets = TE.modules.pull_engine.current_pull.targets,
            total_health = TE.modules.pull_engine.current_pull.total_health,
            target_count = #TE.modules.pull_engine.current_pull.targets
        })
        
        -- Update pull metrics
        TE.modules.pull_engine.update_pull_metrics()
        
        -- Reset current pull
        TE.modules.pull_engine.current_pull.in_progress = false
        TE.modules.pull_engine.current_pull.targets = {}
        TE.modules.pull_engine.current_pull.total_health = 0
        TE.modules.pull_engine.current_pull.expected_ttd = 0
        
        -- Set last pull end time
        TE.modules.pull_engine.last_pull_end = current_time
        
        core.log(string.format("Pull Engine: Combat ended - Pull lasted %.1f seconds", pull_duration))
    end
    
    -- Clear scheduled pull
    TE.modules.pull_engine.scheduled_pull = nil
end

-- Update the current pull status
function TE.modules.pull_engine.update_current_pull()
    if not TE.modules.pull_engine.current_pull.in_progress then
        return
    end
    
    -- Check if any targets are still alive
    local targets_alive = false
    for _, unit in ipairs(TE.modules.pull_engine.current_pull.targets) do
        if unit and unit:is_valid() and not unit:is_dead() then
            targets_alive = true
            break
        end
    end
    
    -- Check for additional targets that weren't in the original pull
    local units = core.object_manager.get_all_objects()
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) and unit:is_in_combat() then
            -- Check if this unit is already in our targets list
            local found = false
            for _, existing in ipairs(TE.modules.pull_engine.current_pull.targets) do
                if existing == unit then
                    found = true
                    break
                end
            end
            
            -- If not found, add to targets
            if not found then
                table.insert(TE.modules.pull_engine.current_pull.targets, unit)
                TE.modules.pull_engine.current_pull.total_health = TE.modules.pull_engine.current_pull.total_health + unit:get_health()
                targets_alive = true
            end
        end
    end
    
    -- If no targets are alive and not in combat, end the pull
    if not targets_alive and not TE.variables.me:is_in_combat() then
        TE.modules.pull_engine.end_combat()
    end
end

-- Update enemy packs
function TE.modules.pull_engine.update_enemy_packs()
    -- Skip if in combat
    if TE.variables.in_combat then
        return
    end
    
    -- Clear current packs
    TE.modules.pull_engine.enemy_packs = {}
    
    -- Find potential pack centers
    local units = core.object_manager.get_all_objects()
    local processed = {}
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) and not processed[unit] then
            -- Get pack for this unit
            local pack = TE.modules.pull_engine.get_pack_enemies(unit, 15)
            
            -- Skip empty packs
            if #pack > 0 then
                -- Mark all units in this pack as processed
                for _, pack_unit in ipairs(pack) do
                    processed[pack_unit] = true
                end
                
                -- Calculate danger score
                local danger_score, analysis = TE.modules.pull_engine.analyze_enemy_pack_danger(pack)
                
                -- Store pack
                table.insert(TE.modules.pull_engine.enemy_packs, {
                    center = unit,
                    units = pack,
                    danger_score = danger_score,
                    analysis = analysis
                })
            end
        end
    end
    
    -- Sort packs by distance
    table.sort(TE.modules.pull_engine.enemy_packs, function(a, b)
        local a_dist = TE.variables.me:get_position():dist_to(a.center:get_position())
        local b_dist = TE.variables.me:get_position():dist_to(b.center:get_position())
        return a_dist < b_dist
    end)
end

-- Update patrol timings
function TE.modules.pull_engine.update_patrol_timings()
    -- Skip if in combat
    if TE.variables.in_combat then
        return
    end
    
    -- Current time
    local current_time = core.game_time()
    
    -- Clear old patrol data
    for unit, data in pairs(TE.modules.pull_engine.patrol_timings) do
        if not unit or not unit:is_valid() or unit:is_dead() or current_time - data.last_update > 10000 then
            TE.modules.pull_engine.patrol_timings[unit] = nil
        end
    end
    
    -- Update all visible units
    local units = core.object_manager.get_all_objects()
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) then
            -- Get current position
            local position = unit:get_position()
            
            -- Initialize if needed
            if not TE.modules.pull_engine.patrol_timings[unit] then
                TE.modules.pull_engine.patrol_timings[unit] = {
                    positions = {},
                    velocities = {},
                    last_position = position,
                    last_update = current_time,
                    is_patrolling = false,
                    patrol_radius = 0,
                    patrol_center = position,
                }
            end
            
            -- Update patrol data
            local patrol_data = TE.modules.pull_engine.patrol_timings[unit]
            local time_diff = (current_time - patrol_data.last_update) / 1000 -- Convert to seconds
            
            -- Only update if enough time has passed
            if time_diff >= 0.5 then
                -- Calculate displacement
                local displacement = position:dist_to(patrol_data.last_position)
                
                -- Calculate velocity
                local velocity = displacement / time_diff
                
                -- Store position and velocity
                table.insert(patrol_data.positions, {
                    position = position:clone(),
                    time = current_time
                })
                
                table.insert(patrol_data.velocities, {
                    velocity = velocity,
                    time = current_time
                })
                
                -- Limit history size
                if #patrol_data.positions > 10 then
                    table.remove(patrol_data.positions, 1)
                end
                
                if #patrol_data.velocities > 10 then
                    table.remove(patrol_data.velocities, 1)
                end
                
                -- Determine if patrolling
                local is_moving = velocity > 0.5 -- Consider moving if velocity is significant
                local has_change_direction = false
                
                if #patrol_data.positions >= 3 then
                    -- Check if unit has changed direction (sign of patrolling)
                    local pos1 = patrol_data.positions[#patrol_data.positions - 2].position
                    local pos2 = patrol_data.positions[#patrol_data.positions - 1].position
                    local pos3 = patrol_data.positions[#patrol_data.positions].position
                    
                    -- Calculate direction vectors
                    local dir1 = pos2:clone():__sub(pos1)
                    local dir2 = pos3:clone():__sub(pos2)
                    
                    -- Check for direction change using dot product
                    local dot = dir1:dot(dir2)
                    has_change_direction = dot < 0 -- Negative dot product indicates direction change
                end
                
                -- Update patrol status
                patrol_data.is_patrolling = is_moving and has_change_direction
                
                -- Calculate patrol radius if patrolling
                if patrol_data.is_patrolling and #patrol_data.positions >= 3 then
                    -- Find min/max coordinates
                    local min_x, min_y, min_z = math.huge, math.huge, math.huge
                    local max_x, max_y, max_z = -math.huge, -math.huge, -math.huge
                    
                    for _, pos_data in ipairs(patrol_data.positions) do
                        local pos = pos_data.position
                        min_x = math.min(min_x, pos.x)
                        min_y = math.min(min_y, pos.y)
                        min_z = math.min(min_z, pos.z)
                        max_x = math.max(max_x, pos.x)
                        max_y = math.max(max_y, pos.y)
                        max_z = math.max(max_z, pos.z)
                    end
                    
                    -- Calculate center and radius
                    patrol_data.patrol_center = vec3.new(
                        (min_x + max_x) / 2,
                        (min_y + max_y) / 2,
                        (min_z + max_z) / 2
                    )
                    
                    patrol_data.patrol_radius = math.max(
                        (max_x - min_x) / 2,
                        (max_y - min_y) / 2
                    )
                end
                
                -- Update for next cycle
                patrol_data.last_position = position:clone()
                patrol_data.last_update = current_time
            end
        end
    end
end

-- Update pull metrics
function TE.modules.pull_engine.update_pull_metrics()
    -- Need at least one pull for metrics
    if #TE.modules.pull_engine.pull_history == 0 then
        return
    end
    
    -- Calculate metrics from history
    local total_duration = 0
    local total_targets = 0
    local total_health = 0
    
    for _, pull in ipairs(TE.modules.pull_engine.pull_history) do
        total_duration = total_duration + pull.duration
        total_targets = total_targets + pull.target_count
        total_health = total_health + pull.total_health
    end
    
    -- Calculate averages
    TE.modules.pull_engine.metrics.avg_pull_time = total_duration / #TE.modules.pull_engine.pull_history
    TE.modules.pull_engine.metrics.avg_pull_size = total_targets / #TE.modules.pull_engine.pull_history
    TE.modules.pull_engine.metrics.avg_pull_health = total_health / #TE.modules.pull_engine.pull_history
    
    -- Calculate group DPS if we have data
    if total_duration > 0 then
        TE.modules.pull_engine.metrics.group_dps = total_health / total_duration
    end
end

-- Clean up stale data
function TE.modules.pull_engine.cleanup_stale_data()
    local current_time = core.game_time()
    local max_age = 3600000 -- 1 hour in ms
    
    -- Clean up pull history
    local valid_history = {}
    for _, pull in ipairs(TE.modules.pull_engine.pull_history) do
        if current_time - pull.end_time <= max_age then
            table.insert(valid_history, pull)
        end
    end
    TE.modules.pull_engine.pull_history = valid_history
    
    -- Limit history size
    if #TE.modules.pull_engine.pull_history > 20 then
        -- Only keep the 20 most recent
        local temp = {}
        for i = #TE.modules.pull_engine.pull_history - 19, #TE.modules.pull_engine.pull_history do
            table.insert(temp, TE.modules.pull_engine.pull_history[i])
        end
        TE.modules.pull_engine.pull_history = temp
    end
end
