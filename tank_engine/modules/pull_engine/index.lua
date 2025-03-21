-- Pull Engine Module
-- Plans and executes optimal pulls

---@type vec3
local vec3 = require("common/geometry/vector_3")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

TE.modules.pull_engine = {
    -- State tracking
    enemy_packs = {},              -- Nearby enemy packs
    patrol_timings = {},           -- Patrol timing tracking
    pull_history = {},             -- History of recent pulls
    current_pull = {               -- Current pull information
        in_progress = false,
        targets = {},
        start_time = 0,
        total_health = 0,
        expected_ttd = 0,
    },
    scheduled_pull = nil,          -- Next scheduled pull
    los_pull_points = {},          -- Line of sight pull positions
    
    -- Pull planning metrics
    metrics = {
        avg_pull_time = 0,         -- Average time to clear a pull
        avg_pull_size = 0,         -- Average pull size (enemies)
        avg_pull_health = 0,       -- Average total health in a pull
        group_dps = 0,             -- Estimated group DPS
    },
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        auto_pull = TE.menu.checkbox(false, "pull_auto_pull"),
        pull_size = TE.menu.slider_int(1, 10, 3, "pull_size"),
        pull_cooldown = TE.menu.slider_float(0, 10, 3, "pull_cooldown"),
        use_los_pulling = TE.menu.checkbox(true, "pull_use_los"),
        enable_path_analysis = TE.menu.checkbox(true, "pull_path_analysis"),
        pull_target_selection = TE.menu.combobox(1, "pull_target_selection"),
        max_pull_distance = TE.menu.slider_float(5, 40, 30, "pull_max_distance"),
        show_pull_planning = TE.menu.checkbox(true, "pull_show_planning"),
        danger_threshold = TE.menu.slider_float(0, 100, 70, "pull_danger_threshold"),
    },
}

-- Load module files
require("modules/pull_engine/menu")
require("modules/pull_engine/settings")
require("modules/pull_engine/on_update")

-- Pull algorithms

---Get the optimal pull size based on available cooldowns
---@param cooldowns_available table Available defensive cooldowns
---@return number optimal_size The optimal number of enemies to pull
function TE.modules.pull_engine.get_optimal_pull_size(cooldowns_available)
    -- Start with the configured pull size
    local base_size = TE.modules.pull_engine.menu.pull_size:get()
    
    -- Adjust based on available cooldowns
    local cooldown_modifier = 0
    if cooldowns_available then
        -- Count high-value defensive cooldowns
        for _, cooldown in pairs(cooldowns_available) do
            if cooldown.is_available and cooldown.type == "emergency" then
                cooldown_modifier = cooldown_modifier + 0.5
            elseif cooldown.is_available and cooldown.type == "physical" then
                cooldown_modifier = cooldown_modifier + 0.3
            end
        end
    end
    
    -- Adjust based on group composition
    local healer_score = 0
    if TE.modules.healer_engine and TE.modules.healer_engine.healers then
        for healer, efficiency in pairs(TE.modules.healer_engine.healing_efficiency) do
            if healer and healer:is_valid() and not healer:is_dead() then
                healer_score = math.max(healer_score, efficiency / 100)
            end
        end
    end
    
    -- Calculate final pull size
    local healer_modifier = healer_score * 0.5 -- Up to +0.5 for a perfect healer
    local optimal_size = base_size + math.floor(cooldown_modifier + healer_modifier)
    
    -- Clamp to reasonable values
    return math.max(1, math.min(optimal_size, 10))
end

---Calculate the best line-of-sight pull position
---@param target game_object The target to pull
---@return vec3|nil position The optimal position to pull from, or nil if no suitable position found
function TE.modules.pull_engine.calculate_los_pull_position(target)
    if not target or not target:is_valid() or target:is_dead() then
        return nil
    end
    
    -- Get target position
    local target_position = target:get_position()
    local player_position = TE.variables.me:get_position()
    
    -- Start by trying a position directly behind the player
    local direction = player_position:clone():__sub(target_position):normalize()
    local pull_distance = 20 -- 20 yards behind player
    local base_pull_position = player_position:clone():__add(direction:clone():__mul(pull_distance))
    
    -- Check line of sight from this position to player
    if core.graphics.trace_line(base_pull_position, player_position, 0x100071) then
        -- Something is blocking line of sight, search for another position
        
        -- Try various angles in a fan behind the player
        local angles = {0, 20, -20, 40, -40, 60, -60}
        for _, angle in ipairs(angles) do
            local rotated_direction = direction:clone():rotate_3d_radians(math.rad(angle))
            local test_position = player_position:clone():__add(rotated_direction:clone():__mul(pull_distance))
            
            -- Check line of sight from this position to player
            if not core.graphics.trace_line(test_position, player_position, 0x100071) then
                -- This position has clear line of sight
                return test_position
            end
        end
        
        -- No good position found, just return the base position
        return base_pull_position
    end
    
    -- Base position has clear line of sight
    return base_pull_position
end

---Analyze the danger level of an enemy pack
---@param pack table The enemy pack to analyze
---@return number danger_score The danger score of the pack (0-100)
---@return table analysis Detailed analysis of the pack
function TE.modules.pull_engine.analyze_enemy_pack_danger(pack)
    if not pack or #pack == 0 then
        return 0, {}
    end
    
    local total_health = 0
    local elite_count = 0
    local ranged_count = 0
    local caster_count = 0
    local total_level = 0
    
    -- Analyze each enemy in the pack
    for _, unit in ipairs(pack) do
        if unit and unit:is_valid() and not unit:is_dead() then
            -- Track health
            total_health = total_health + unit:get_health()
            
            -- Track elites
            local classification = unit:get_classification()
            if classification >= 1 then -- Elite or higher
                elite_count = elite_count + 1
            end
            
            -- Track level
            total_level = total_level + unit:get_level()
            
            -- Try to determine if ranged or caster
            -- This is a simplification - ideally we'd have more accurate data
            if unit:is_casting_spell() then
                caster_count = caster_count + 1
            end
            
            -- Check for known ranged types by ID or name
            local unit_name = string.lower(unit:get_name())
            if unit_name:find("archer") or unit_name:find("hunter") or 
               unit_name:find("sniper") or unit_name:find("shooter") then
                ranged_count = ranged_count + 1
            end
        end
    end
    
    -- Calculate averages and metrics
    local avg_level = #pack > 0 and (total_level / #pack) or 0
    local player_level = TE.variables.me:get_level()
    local level_difference = avg_level - player_level
    
    -- Calculate danger score components
    local size_score = math.min(100, #pack * 10) -- 10 points per enemy
    local elite_score = math.min(100, elite_count * 25) -- 25 points per elite
    local health_score = math.min(100, total_health / TE.variables.me:get_max_health() / 10 * 100) -- Normalize to player health
    local ranged_score = math.min(100, (ranged_count + caster_count) * 15) -- 15 points per ranged/caster
    local level_score = math.min(100, math.max(0, level_difference * 20 + 50)) -- Level difference factor
    
    -- Combined danger score with weights
    local danger_score = (size_score * 0.3) + 
                        (elite_score * 0.25) + 
                        (health_score * 0.15) + 
                        (ranged_score * 0.2) + 
                        (level_score * 0.1)
    
    -- Clamp final score
    danger_score = math.max(0, math.min(100, danger_score))
    
    -- Return score and detailed analysis
    return danger_score, {
        size = #pack,
        total_health = total_health,
        elite_count = elite_count,
        ranged_count = ranged_count,
        caster_count = caster_count,
        avg_level = avg_level,
        level_difference = level_difference,
        component_scores = {
            size_score = size_score,
            elite_score = elite_score,
            health_score = health_score,
            ranged_score = ranged_score,
            level_score = level_score
        }
    }
end

---Get enemies in a pack based on positional clustering
---@param center_unit game_object The central unit of the pack
---@param max_distance number Maximum distance to consider units part of the pack
---@return table enemies Array of enemies in the pack
function TE.modules.pull_engine.get_pack_enemies(center_unit, max_distance)
    if not center_unit or not center_unit:is_valid() or center_unit:is_dead() then
        return {}
    end
    
    max_distance = max_distance or 15 -- Default 15 yards radius
    local center_position = center_unit:get_position()
    local pack_enemies = {center_unit}
    
    -- Find all enemies in range of the center unit
    local units = core.object_manager.get_all_objects()
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) and unit ~= center_unit then
            local distance = center_position:dist_to(unit:get_position())
            
            if distance <= max_distance then
                table.insert(pack_enemies, unit)
            end
        end
    end
    
    return pack_enemies
end

---Find the optimal target to pull
---@return game_object|nil target The optimal target to pull, or nil if no suitable target found
function TE.modules.pull_engine.find_optimal_pull_target()
    -- Get pull target selection mode
    local selection_mode = TE.modules.pull_engine.menu.pull_target_selection:get()
    local max_distance = TE.modules.pull_engine.menu.max_pull_distance:get()
    local danger_threshold = TE.modules.pull_engine.menu.danger_threshold:get()
    
    -- Get all potential targets
    local units = core.object_manager.get_all_objects()
    local candidates = {}
    
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and TE.variables.me:can_attack(unit) then
            local distance = TE.variables.me:get_position():dist_to(unit:get_position())
            
            if distance <= max_distance then
                -- Get the pack for this unit
                local pack = TE.modules.pull_engine.get_pack_enemies(unit, 15)
                local danger_score, analysis = TE.modules.pull_engine.analyze_enemy_pack_danger(pack)
                
                -- Only consider packs below the danger threshold
                if danger_score <= danger_threshold then
                    table.insert(candidates, {
                        unit = unit,
                        pack = pack,
                        distance = distance,
                        danger_score = danger_score,
                        analysis = analysis
                    })
                end
            end
        end
    end
    
    -- If no candidates, return nil
    if #candidates == 0 then
        return nil
    end
    
    -- Sort candidates based on selection mode
    if selection_mode == 0 then
        -- Closest first
        table.sort(candidates, function(a, b)
            return a.distance < b.distance
        end)
    elseif selection_mode == 1 then
        -- Smallest pack first
        table.sort(candidates, function(a, b)
            return #a.pack < #b.pack
        end)
    elseif selection_mode == 2 then
        -- Largest pack first (up to optimal size)
        local optimal_size = TE.modules.pull_engine.get_optimal_pull_size(TE.modules.defensive_engine and TE.modules.defensive_engine.cooldowns_available)
        
        table.sort(candidates, function(a, b)
            local a_diff = math.abs(#a.pack - optimal_size)
            local b_diff = math.abs(#b.pack - optimal_size)
            return a_diff < b_diff
        end)
    elseif selection_mode == 3 then
        -- Lowest danger score first
        table.sort(candidates, function(a, b)
            return a.danger_score < b.danger_score
        end)
    end
    
    -- Return the best candidate
    return candidates[1] and candidates[1].unit or nil
end

---Execute a pull
---@param target game_object The target to pull
---@param method string The method to use for pulling ("los", "direct", "ranged")
function TE.modules.pull_engine.execute_pull(target, method)
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    method = method or "direct"
    
    -- Start pull tracking
    TE.modules.pull_engine.current_pull.in_progress = true
    TE.modules.pull_engine.current_pull.start_time = core.game_time()
    TE.modules.pull_engine.current_pull.targets = TE.modules.pull_engine.get_pack_enemies(target, 15)
    
    -- Calculate total health
    local total_health = 0
    for _, unit in ipairs(TE.modules.pull_engine.current_pull.targets) do
        if unit and unit:is_valid() and not unit:is_dead() then
            total_health = total_health + unit:get_health()
        end
    end
    TE.modules.pull_engine.current_pull.total_health = total_health
    
    -- Estimate TTD
    if TE.modules.pull_engine.metrics.group_dps > 0 then
        TE.modules.pull_engine.current_pull.expected_ttd = total_health / TE.modules.pull_engine.metrics.group_dps
    else
        TE.modules.pull_engine.current_pull.expected_ttd = 30 -- Default 30 seconds
    end
    
    -- Execute pull based on method
    if method == "los" then
        -- Line of sight pull
        TE.modules.pull_engine.execute_los_pull(target)
    elseif method == "ranged" then
        -- Ranged pull
        TE.modules.pull_engine.execute_ranged_pull(target)
    else
        -- Direct pull
        TE.modules.pull_engine.execute_direct_pull(target)
    end
    
    -- Log the pull
    local pack_size = #TE.modules.pull_engine.current_pull.targets
    core.log(string.format("Pull Engine: Pulling %d enemies with %s method", pack_size, method))
end

---Execute a line-of-sight pull
---@param target game_object The target to pull
function TE.modules.pull_engine.execute_los_pull(target)
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    -- Calculate line of sight position
    local los_position = TE.modules.pull_engine.calculate_los_pull_position(target)
    if not los_position then
        -- Fall back to direct pull if no position found
        TE.modules.pull_engine.execute_direct_pull(target)
        return
    end
    
    -- Store LOS position for visualization
    TE.modules.pull_engine.los_pull_points = {
        target_position = target:get_position(),
        pull_position = los_position
    }
    
    -- Pull sequence:
    -- 1. Target enemy
    core.input.set_target(target)
    
    -- 2. Use a ranged ability to pull if available
    local ranged_pull_spell = TE.modules.pull_engine.get_ranged_pull_ability()
    if ranged_pull_spell then
        -- Use ranged ability
        TE.api.spell_queue:queue_spell_target(ranged_pull_spell, target, 1000, "Ranged pull")
    else
        -- Need to do manual los pull
        -- First, set target
        core.input.set_target(target)
        
        -- Use movement handler to move to LOS position
        TE.api.movement_handler:pause_movement()
        TE.api.movement_handler:move_to_position(los_position)
        
        -- Movement handler will handle the rest
    end
end

---Execute a direct pull
---@param target game_object The target to pull
function TE.modules.pull_engine.execute_direct_pull(target)
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    -- Direct pull sequence:
    -- 1. Target enemy
    core.input.set_target(target)
    
    -- 2. Use a ranged ability to pull if available
    local ranged_pull_spell = TE.modules.pull_engine.get_ranged_pull_ability()
    if ranged_pull_spell then
        -- Use ranged ability
        TE.api.spell_queue:queue_spell_target(ranged_pull_spell, target, 1000, "Ranged pull")
    else
        -- Move to target
        local target_position = target:get_position()
        TE.api.movement_handler:pause_movement()
        TE.api.movement_handler:move_to_position(target_position)
    end
end

---Execute a ranged pull
---@param target game_object The target to pull
function TE.modules.pull_engine.execute_ranged_pull(target)
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    -- Ranged pull sequence:
    -- 1. Target enemy
    core.input.set_target(target)
    
    -- 2. Use a ranged ability to pull
    local ranged_pull_spell = TE.modules.pull_engine.get_ranged_pull_ability()
    if ranged_pull_spell then
        -- Use ranged ability
        TE.api.spell_queue:queue_spell_target(ranged_pull_spell, target, 1000, "Ranged pull")
    else
        -- Fall back to direct pull if no ranged ability available
        TE.modules.pull_engine.execute_direct_pull(target)
    end
end

---Get the best ranged pull ability
---@return number|nil spell_id The ID of the best ranged pull ability, or nil if none available
function TE.modules.pull_engine.get_ranged_pull_ability()
    -- Class-specific implementation would go here
    -- For now, return nil as a placeholder
    return nil
end

-- Module interface for core system
return {
    on_update = TE.modules.pull_engine.on_update,
    on_fast_update = TE.modules.pull_engine.on_fast_update,
    on_render_menu = TE.modules.pull_engine.menu.on_render_menu,
    on_render = TE.modules.pull_engine.on_render,
    on_render_3d = TE.modules.pull_engine.on_render_3d,
}


