-- Mitigation Engine Module
-- Tracks active mitigation uptimes and optimizes their usage

TE.modules.mitigation_engine = {
    -- State tracking
    mitigation_uptimes = {},       -- Active mitigation uptime tracking
    resource_availability = {},    -- Resource tracking for mitigation
    mitigation_gaps = {},          -- Gaps in mitigation coverage
    mitigation_history = {},       -- Historical mitigation usage
    last_mitigation_end = 0,       -- When the last mitigation effect ended
    last_update_time = 0,          -- Last update timestamp
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        min_resource = TE.menu.slider_float(0, 100, 40, "mitigation_min_resource"),
        gap_tolerance = TE.menu.slider_float(0, 5, 0.5, "mitigation_gap_tolerance"),
        auto_mitigation = TE.menu.checkbox(true, "mitigation_auto_mitigation"),
        show_gaps = TE.menu.checkbox(true, "mitigation_show_gaps"),
        show_uptime = TE.menu.checkbox(true, "mitigation_show_uptime"),
        optimize_resource = TE.menu.checkbox(true, "mitigation_optimize_resource"),
    },
}

-- Load module files
require("modules/mitigation_engine/menu")
require("modules/mitigation_engine/settings")
require("modules/mitigation_engine/on_update")

-- Mitigation algorithms

---Get the optimal mitigation ability to use based on current situation
---@return number|nil spell_id The spell ID of the optimal mitigation ability, or nil if no suitable ability found
---@return string|nil reason The reason for selecting this ability
function TE.modules.mitigation_engine.get_optimal_mitigation_ability()
    -- Check if we have enough resources
    local resource_type = TE.modules.mitigation_engine.get_class_resource_type()
    local current_resource = TE.variables.resource_percent(resource_type)
    local min_resource = TE.modules.mitigation_engine.menu.min_resource:get()
    
    if current_resource < min_resource then
        return nil, "Insufficient resources"
    end
    
    -- Check if we already have active mitigation
    if TE.modules.mitigation_engine.is_mitigation_active() then
        local remaining = TE.modules.mitigation_engine.get_mitigation_remaining()
        
        -- If mitigation still has significant time left, don't use another
        if remaining > 2 then
            return nil, "Mitigation already active"
        end
    end
    
    -- Get available mitigation abilities
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    
    -- Sort by priority (highest first)
    table.sort(mitigation_abilities, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Find first available spell
    for _, ability in ipairs(mitigation_abilities) do
        if not TE.variables.on_cooldown(ability.spell_id) then
            -- Check if we're in active combat
            if not TE.variables.in_combat and ability.combat_only then
                -- Skip combat-only abilities when not in combat
                goto continue
            end
            
            -- Check if resources are sufficient for this ability
            if ability.resource_cost and current_resource < ability.resource_cost then
                goto continue
            end
            
            -- This ability is usable
            return ability.spell_id, ability.reason or "Optimal mitigation ability"
        end
        
        ::continue::
    end
    
    return nil, "No suitable mitigation available"
end

---Calculate the current mitigation uptime percentage
---@param window_size number Time window in seconds
---@return number uptime_percent The percentage of time mitigation was active
function TE.modules.mitigation_engine.calculate_mitigation_uptime(window_size)
    window_size = window_size or 30 -- Default 30 second window
    
    local current_time = core.game_time()
    local window_start = current_time - (window_size * 1000) -- Convert to ms
    
    -- Filter mitigation history within window
    local active_time = 0
    local history = TE.modules.mitigation_engine.mitigation_history
    
    for _, event in ipairs(history) do
        if event.end_time >= window_start then
            local start = math.max(event.start_time, window_start)
            local finish = math.min(event.end_time, current_time)
            active_time = active_time + (finish - start)
        end
    end
    
    -- Calculate percentage
    local window_ms = window_size * 1000
    return (active_time / window_ms) * 100
end

---Predict gaps in mitigation coverage in the future window
---@param future_window number Time window in seconds to look ahead
---@return table gaps Information about upcoming mitigation gaps
function TE.modules.mitigation_engine.predict_mitigation_gaps(future_window)
    future_window = future_window or 10 -- Default 10 second window
    
    local current_time = core.game_time()
    local window_end = current_time + (future_window * 1000) -- Convert to ms
    
    -- Start with current mitigation state
    local is_active = TE.modules.mitigation_engine.is_mitigation_active()
    local current_remaining = TE.modules.mitigation_engine.get_mitigation_remaining() * 1000 -- Convert to ms
    
    -- If mitigation is active, check when it will end
    local gaps = {}
    local current_position = current_time
    
    if is_active and current_remaining > 0 then
        current_position = current_time + current_remaining
    end
    
    -- Check cooldowns on mitigation abilities
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    local next_available = window_end
    
    for _, ability in ipairs(mitigation_abilities) do
        local cooldown = core.spell_book.get_spell_cooldown(ability.spell_id) * 1000 -- Convert to ms
        local available_at = current_time + cooldown
        
        if available_at < next_available then
            next_available = available_at
        end
    end
    
    -- Calculate gap
    if current_position < window_end then
        table.insert(gaps, {
            start_time = current_position,
            end_time = math.min(next_available, window_end),
            duration = (math.min(next_available, window_end) - current_position) / 1000, -- Convert to seconds
            can_mitigate = next_available <= window_end
        })
    end
    
    return {
        has_gaps = #gaps > 0,
        gaps = gaps,
        current_status = {
            is_active = is_active,
            remaining = current_remaining / 1000, -- Convert to seconds
            next_available = (next_available - current_time) / 1000 -- Convert to seconds
        }
    }
end

---Check if any mitigation is currently active
---@return boolean is_active Whether mitigation is active
function TE.modules.mitigation_engine.is_mitigation_active()
    -- Check if any class-specific mitigation is active
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    
    for _, ability in ipairs(mitigation_abilities) do
        if ability.buff_id and TE.variables.buff_up(ability.buff_id) then
            return true
        end
    end
    
    return false
end

---Get the remaining time on the current mitigation
---@return number remaining_time The remaining time in seconds
function TE.modules.mitigation_engine.get_mitigation_remaining()
    local max_remaining = 0
    
    -- Check all mitigation buffs
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    
    for _, ability in ipairs(mitigation_abilities) do
        if ability.buff_id and TE.variables.buff_up(ability.buff_id) then
            local remaining = TE.variables.buff_remains(ability.buff_id)
            max_remaining = math.max(max_remaining, remaining)
        end
    end
    
    return max_remaining
end

---Check the resource availability for mitigation abilities
---@return table resource_info Information about resource availability
function TE.modules.mitigation_engine.check_resource_availability()
    local resource_type = TE.modules.mitigation_engine.get_class_resource_type()
    local current_resource = TE.variables.resource(resource_type)
    local max_resource = TE.variables.me:get_max_power(resource_type)
    local resource_percent = max_resource > 0 and (current_resource / max_resource * 100) or 0
    
    -- Get resource costs for mitigation abilities
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    local required_resources = {}
    
    for _, ability in ipairs(mitigation_abilities) do
        if ability.resource_cost then
            table.insert(required_resources, {
                spell_id = ability.spell_id,
                cost = ability.resource_cost,
                can_afford = resource_percent >= ability.resource_cost
            })
        end
    end
    
    return {
        resource_type = resource_type,
        current_resource = current_resource,
        max_resource = max_resource,
        resource_percent = resource_percent,
        min_required = TE.modules.mitigation_engine.menu.min_resource:get(),
        has_sufficient = resource_percent >= TE.modules.mitigation_engine.menu.min_resource:get(),
        ability_resources = required_resources
    }
end

---Use a mitigation ability
---@param spell_id number The spell ID of the mitigation ability
---@param reason string The reason for using the ability
function TE.modules.mitigation_engine.use_mitigation_ability(spell_id, reason)
    if not spell_id then return end
    
    -- Check if spell is castable first
    if not TE.api.spell_helper:is_spell_queueable(spell_id, TE.variables.me, TE.variables.me, true, true) then
        return
    end
    
    -- Queue the spell
    TE.api.spell_queue:queue_spell_target(spell_id, TE.variables.me, 1000, reason)
    
    -- Log the mitigation usage
    local spell_name = core.spell_book.get_spell_name(spell_id) or "Unknown Spell"
    core.log(string.format("Mitigation Engine: Using %s (%d) - %s", spell_name, spell_id, reason or ""))
    
    -- Record usage for uptime tracking
    local current_time = core.game_time()
    local mitigation_abilities = TE.modules.mitigation_engine.get_class_mitigation_abilities()
    
    for _, ability in ipairs(mitigation_abilities) do
        if ability.spell_id == spell_id and ability.duration then
            table.insert(TE.modules.mitigation_engine.mitigation_history, {
                spell_id = spell_id,
                start_time = current_time,
                end_time = current_time + (ability.duration * 1000), -- Convert to ms
                duration = ability.duration
            })
            
            -- Limit history size
            if #TE.modules.mitigation_engine.mitigation_history > 50 then
                table.remove(TE.modules.mitigation_engine.mitigation_history, 1)
            end
        end
    end
end

-- Placeholder functions for class-specific mitigation

---Get the primary resource type for the current class
---@return number resource_type The power type ID for the current class's resource
function TE.modules.mitigation_engine.get_class_resource_type()
    -- Default implementation
    return 0 -- Default to mana
end

---Get class-specific mitigation abilities
---@return table abilities Array of mitigation abilities with details
function TE.modules.mitigation_engine.get_class_mitigation_abilities()
    -- Default empty implementation
    return {}
end

-- Module interface for core system
return {
    on_update = TE.modules.mitigation_engine.on_update,
    on_fast_update = TE.modules.mitigation_engine.on_fast_update,
    on_render_menu = TE.modules.mitigation_engine.menu.on_render_menu,
    on_render = TE.modules.mitigation_engine.on_render,
}
