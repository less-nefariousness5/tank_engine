-- Interrupt Engine Module
-- Manages interrupts and crowd control priorities

TE.modules.interrupt_engine = {
    -- State tracking
    interrupt_targets = {},        -- Current interrupt targets
    interrupt_priorities = {},     -- Priority scoring for interrupts
    cc_targets = {},               -- Crowd control targets
    spell_danger_scores = {},      -- Danger scores for known spells
    interrupt_history = {},        -- History of interrupts
    cc_history = {},               -- History of crowd control
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        priority_threshold = TE.menu.slider_float(0, 100, 80, "interrupt_priority_threshold"),
        auto_cc = TE.menu.checkbox(true, "interrupt_auto_cc"),
        auto_interrupt = TE.menu.checkbox(true, "interrupt_auto_interrupt"),
        coordinate_interrupts = TE.menu.checkbox(true, "interrupt_coordinate"),
        show_cast_warnings = TE.menu.checkbox(true, "interrupt_show_warnings"),
        max_interrupt_distance = TE.menu.slider_float(0, 40, 30, "interrupt_max_distance"),
        danger_threshold = TE.menu.slider_float(0, 100, 70, "interrupt_danger_threshold"),
        min_cc_duration = TE.menu.slider_float(0, 10, 4, "interrupt_min_cc_duration"),
    },
    
    -- Dangerous spell types to prioritize
    dangerous_spell_types = {
        "heal", "healing", "cure", "mend", "renew", "rejuvenation", "flash", "greater heal",
        "pyroblast", "fireball", "frostbolt", "shadow bolt", "chaos bolt", "mind blast",
        "summon", "resurrect", "revive", "reanimate", "call", "invoke",
        "shield", "barrier", "ward", "protection", "sanctuary",
        "enrage", "frenzy", "bloodlust", "fury", "berserk",
        "volley", "rain", "storm", "blizzard", "earthquake",
        "detonate", "explode", "blast", "explosion", "erupt",
        "poison", "venom", "plague", "disease", "infect",
        "polymorph", "hex", "banish", "fear", "terror"
    }
}

-- Load module files
require("modules/interrupt_engine/menu")
require("modules/interrupt_engine/settings")
require("modules/interrupt_engine/on_update")

-- Target selection algorithms

---Get the highest priority interrupt target
---@return game_object|nil target The highest priority target to interrupt, or nil if no valid target found
---@return number|nil spell_id The ID of the spell to interrupt
function TE.modules.interrupt_engine.get_high_priority_interrupt()
    local threshold = TE.modules.interrupt_engine.menu.priority_threshold:get()
    local best_target = nil
    local best_priority = threshold
    local best_spell_id = nil
    
    for unit, data in pairs(TE.modules.interrupt_engine.interrupt_targets) do
        if unit and unit:is_valid() and not unit:is_dead() and unit:is_casting_spell() then
            local priority = data.priority or 0
            
            if priority > best_priority then
                -- Check if interrupt is available
                local interrupt_spell = TE.modules.interrupt_engine.get_best_interrupt_spell(unit)
                
                if interrupt_spell then
                    best_target = unit
                    best_priority = priority
                    best_spell_id = interrupt_spell
                end
            end
        end
    end
    
    return best_target, best_spell_id
end

---Get the optimal crowd control target
---@return game_object|nil target The optimal CC target, or nil if no valid target found
---@return number|nil spell_id The ID of the CC spell to use
function TE.modules.interrupt_engine.get_optimal_cc_target()
    local best_target = nil
    local best_cc_spell = nil
    local best_score = 0
    
    for unit, data in pairs(TE.modules.interrupt_engine.cc_targets) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local score = data.score or 0
            
            if score > best_score then
                -- Check if we have a CC spell available for this target
                local cc_spell = TE.modules.interrupt_engine.get_best_cc_spell(unit)
                
                if cc_spell then
                    best_target = unit
                    best_score = score
                    best_cc_spell = cc_spell
                end
            end
        end
    end
    
    return best_target, best_cc_spell
end

---Calculate the danger score for a spell
---@param spell_id number The ID of the spell to evaluate
---@return number score The danger score (0-100)
function TE.modules.interrupt_engine.calculate_cast_danger(spell_id)
    -- Check cache first
    if TE.modules.interrupt_engine.spell_danger_scores[spell_id] then
        return TE.modules.interrupt_engine.spell_danger_scores[spell_id]
    end
    
    -- Get spell information
    local spell_name = core.spell_book.get_spell_name(spell_id)
    if not spell_name then
        return 0
    end
    
    local spell_desc = core.spell_book.get_spell_description(spell_id)
    local name_lower = string.lower(spell_name)
    local desc_lower = string.lower(spell_desc or "")
    
    -- Start with base score
    local score = 50
    
    -- Check for dangerous spell types
    for _, danger_type in ipairs(TE.modules.interrupt_engine.dangerous_spell_types) do
        if name_lower:find(danger_type) or desc_lower:find(danger_type) then
            score = score + 15
            break
        end
    end
    
    -- Analyze spell based on name and description
    -- Heals are dangerous
    if name_lower:find("heal") or desc_lower:find("heal") or
       name_lower:find("cure") or desc_lower:find("cure") then
        score = score + 20
    end
    
    -- Big damage is dangerous
    if name_lower:find("blast") or desc_lower:find("blast") or
       name_lower:find("bolt") or desc_lower:find("bolt") or
       name_lower:find("shock") or desc_lower:find("shock") then
        score = score + 15
    end
    
    -- AoE is dangerous
    if name_lower:find("rain") or desc_lower:find("rain") or
       name_lower:find("storm") or desc_lower:find("storm") or
       name_lower:find("volley") or desc_lower:find("volley") or
       name_lower:find("explosion") or desc_lower:find("explosion") then
        score = score + 25
    end
    
    -- Summons are dangerous
    if name_lower:find("summon") or desc_lower:find("summon") or
       name_lower:find("call") or desc_lower:find("call") then
        score = score + 30
    end
    
    -- Buffs are moderately dangerous
    if name_lower:find("shield") or desc_lower:find("shield") or
       name_lower:find("ward") or desc_lower:find("ward") or
       name_lower:find("barrier") or desc_lower:find("barrier") then
        score = score + 10
    end
    
    -- Clamp score to 0-100
    score = math.max(0, math.min(100, score))
    
    -- Cache the result
    TE.modules.interrupt_engine.spell_danger_scores[spell_id] = score
    
    return score
end

---Get the best available interrupt spell for a target
---@param target game_object The target to interrupt
---@return number|nil spell_id The ID of the best interrupt spell, or nil if none available
function TE.modules.interrupt_engine.get_best_interrupt_spell(target)
    if not target or not target:is_valid() or not target:is_casting_spell() then
        return nil
    end
    
    -- Check distance
    local max_distance = TE.modules.interrupt_engine.menu.max_interrupt_distance:get()
    local distance = TE.variables.me:get_position():dist_to(target:get_position())
    
    if distance > max_distance then
        return nil
    end
    
    -- Get class-specific interrupt spells
    local interrupt_spells = TE.modules.interrupt_engine.get_class_interrupt_spells()
    
    -- Sort by priority (highest first)
    table.sort(interrupt_spells, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Find first available spell
    for _, spell_data in ipairs(interrupt_spells) do
        if not TE.variables.on_cooldown(spell_data.spell_id) then
            -- Check if the spell is in range and castable
            if TE.api.spell_helper:is_spell_queueable(spell_data.spell_id, TE.variables.me, target, false, false) then
                return spell_data.spell_id
            end
        end
    end
    
    return nil
end

---Get the best available crowd control spell for a target
---@param target game_object The target to crowd control
---@return number|nil spell_id The ID of the best CC spell, or nil if none available
function TE.modules.interrupt_engine.get_best_cc_spell(target)
    if not target or not target:is_valid() or target:is_dead() then
        return nil
    end
    
    -- Check distance
    local max_distance = TE.modules.interrupt_engine.menu.max_interrupt_distance:get()
    local distance = TE.variables.me:get_position():dist_to(target:get_position())
    
    if distance > max_distance then
        return nil
    end
    
    -- Calculate remaining CC duration
    local min_cc_duration = TE.modules.interrupt_engine.menu.min_cc_duration:get()
    
    -- Get class-specific CC spells
    local cc_spells = TE.modules.interrupt_engine.get_class_cc_spells()
    
    -- Sort by priority (highest first)
    table.sort(cc_spells, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Find first available spell
    for _, spell_data in ipairs(cc_spells) do
        if not TE.variables.on_cooldown(spell_data.spell_id) then
            -- Check duration is sufficient
            if (spell_data.duration or 0) >= min_cc_duration then
                -- Check if the spell is in range and castable
                if TE.api.spell_helper:is_spell_queueable(spell_data.spell_id, TE.variables.me, target, false, false) then
                    return spell_data.spell_id
                end
            end
        end
    end
    
    return nil
end

---Interrupt a spell cast
---@param target game_object The target casting the spell
---@param spell_id number The ID of the interrupt spell to use
function TE.modules.interrupt_engine.interrupt_spell(target, spell_id)
    if not target or not target:is_valid() or target:is_dead() or not spell_id then
        return
    end
    
    -- Check if target is still casting
    if not target:is_casting_spell() then
        return
    end
    
    -- Get the spell being cast
    local cast_spell_id = target:get_active_spell_id()
    local cast_spell_name = cast_spell_id and core.spell_book.get_spell_name(cast_spell_id) or "Unknown Spell"
    
    -- Queue the interrupt
    TE.api.spell_queue:queue_spell_target(spell_id, target, 1000, "Interrupting " .. cast_spell_name)
    
    -- Log the interrupt
    local interrupt_spell_name = core.spell_book.get_spell_name(spell_id) or "Unknown Spell"
    core.log(string.format("Interrupt Engine: Using %s to interrupt %s's %s", 
                          interrupt_spell_name, 
                          target:get_name(),
                          cast_spell_name))
    
    -- Record for interrupt history
    local current_time = core.game_time()
    table.insert(TE.modules.interrupt_engine.interrupt_history, {
        time = current_time,
        target = target,
        target_name = target:get_name(),
        spell_id = spell_id,
        spell_name = interrupt_spell_name,
        target_spell_id = cast_spell_id,
        target_spell_name = cast_spell_name
    })
    
    -- Limit history size
    if #TE.modules.interrupt_engine.interrupt_history > 20 then
        table.remove(TE.modules.interrupt_engine.interrupt_history, 1)
    end
end

---Apply crowd control to a target
---@param target game_object The target to crowd control
---@param spell_id number The ID of the CC spell to use
function TE.modules.interrupt_engine.apply_crowd_control(target, spell_id)
    if not target or not target:is_valid() or target:is_dead() or not spell_id then
        return
    end
    
    -- Queue the CC
    TE.api.spell_queue:queue_spell_target(spell_id, target, 1000, "Applying crowd control")
    
    -- Log the CC
    local cc_spell_name = core.spell_book.get_spell_name(spell_id) or "Unknown Spell"
    core.log(string.format("Interrupt Engine: Using %s on %s", 
                          cc_spell_name, 
                          target:get_name()))
    
    -- Record for CC history
    local current_time = core.game_time()
    table.insert(TE.modules.interrupt_engine.cc_history, {
        time = current_time,
        target = target,
        target_name = target:get_name(),
        spell_id = spell_id,
        spell_name = cc_spell_name
    })
    
    -- Limit history size
    if #TE.modules.interrupt_engine.cc_history > 20 then
        table.remove(TE.modules.interrupt_engine.cc_history, 1)
    end
end

-- Placeholder functions for class-specific interrupts and CC

---Get class-specific interrupt spells
---@return table spells Array of {spell_id, priority, range} for interrupt spells
function TE.modules.interrupt_engine.get_class_interrupt_spells()
    -- Default empty implementation
    return {}
end

---Get class-specific crowd control spells
---@return table spells Array of {spell_id, priority, duration, type} for CC spells
function TE.modules.interrupt_engine.get_class_cc_spells()
    -- Default empty implementation
    return {}
end

-- Module interface for core system
return {
    on_update = TE.modules.interrupt_engine.on_update,
    on_fast_update = TE.modules.interrupt_engine.on_fast_update,
    on_render_menu = TE.modules.interrupt_engine.menu.on_render_menu,
    on_render = TE.modules.interrupt_engine.on_render,
}
