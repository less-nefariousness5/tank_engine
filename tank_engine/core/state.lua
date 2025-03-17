-- Tank Engine State Management
-- Provides a central state manager for communication between modules

TE.state = {
    -- State data storage
    _data = {},
    
    -- Subscribers to state changes
    _subscribers = {},
    
    -- Event history for debugging
    _history = {},
    
    -- History max length
    _max_history = 100,
}

-- Initialize state with default values
function TE.state.initialize()
    -- Core state
    TE.state._data = {
        -- Player state
        player = {
            health_current = 0,
            health_max = 0,
            health_percent = 0,
            resource_current = {},  -- Indexed by resource type
            resource_max = {},      -- Indexed by resource type
            position = nil,         -- vec3
            in_combat = false,
            target = nil,           -- Current target
            role = nil,             -- Current role
            spec = nil,             -- Current specialization
        },
        
        -- Combat state
        combat = {
            in_progress = false,
            start_time = 0,
            duration = 0,
            incoming_damage = {
                total = 0,
                physical = 0,
                magical = 0,
                last_spike = 0,
                history = {},        -- Recent damage events
            },
            threat = {
                status = {},         -- Indexed by unit ID
                aggro_targets = {},  -- Units with aggro on player
            },
        },
        
        -- Target state
        targets = {
            current = nil,          -- Primary target
            primary = nil,          -- Tank target
            focus = nil,            -- Focus target
            mouseover = nil,        -- Mouseover target
            enemies = {},           -- Nearby enemies
            allies = {},            -- Nearby allies
            tanks = {},             -- Other tanks 
            interrupt_targets = {}, -- Prioritized interrupt targets
        },
        
        -- Ability state
        abilities = {
            cooldowns = {},         -- Active cooldowns
            available = {},         -- Available abilities 
            recommended = {},       -- Recommended abilities
            last_used = {},         -- Last used abilities with timestamps
        },
        
        -- Module states (modules can register their own state sections)
        modules = {},
    }
    
    core.log("State management system initialized")
    return true
end

-- Register a module's state
function TE.state.register_module(module_name, initial_state)
    if not TE.state._data.modules[module_name] then
        TE.state._data.modules[module_name] = initial_state or {}
        return true
    else
        core.log_warning("Module state already registered: " .. module_name)
        return false
    end
end

-- Get a state value using a path notation (e.g., "player.health_current")
function TE.state.get(path)
    if not path then return nil end
    
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = TE.state._data
    for _, part in ipairs(parts) do
        if current[part] == nil then
            return nil
        end
        current = current[part]
    end
    
    return current
end

-- Set a state value using a path notation and notify subscribers
function TE.state.set(path, value)
    if not path then return false end
    
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = TE.state._data
    for i = 1, #parts - 1 do
        local part = parts[i]
        if current[part] == nil then
            current[part] = {}
        end
        current = current[part]
    end
    
    local last_part = parts[#parts]
    local old_value = current[last_part]
    current[last_part] = value
    
    -- Add to history
    table.insert(TE.state._history, {
        time = core.game_time(),
        path = path,
        old_value = old_value,
        new_value = value
    })
    
    -- Trim history if needed
    if #TE.state._history > TE.state._max_history then
        table.remove(TE.state._history, 1)
    end
    
    -- Notify subscribers
    TE.state.notify_subscribers(path, old_value, value)
    
    return true
end

-- Subscribe to state changes
function TE.state.subscribe(path, callback)
    if not path or not callback then return false end
    
    TE.state._subscribers[path] = TE.state._subscribers[path] or {}
    table.insert(TE.state._subscribers[path], callback)
    
    return true
end

-- Unsubscribe from state changes
function TE.state.unsubscribe(path, callback)
    if not path or not callback or not TE.state._subscribers[path] then 
        return false 
    end
    
    for i, cb in ipairs(TE.state._subscribers[path]) do
        if cb == callback then
            table.remove(TE.state._subscribers[path], i)
            return true
        end
    end
    
    return false
end

-- Notify subscribers of state changes
function TE.state.notify_subscribers(path, old_value, new_value)
    -- Exact path match
    if TE.state._subscribers[path] then
        for _, callback in ipairs(TE.state._subscribers[path]) do
            pcall(callback, path, old_value, new_value)
        end
    end
    
    -- Wildcard matches (e.g., "player.*")
    for subscriber_path, callbacks in pairs(TE.state._subscribers) do
        -- Check if the subscriber path is a wildcard that matches the changed path
        if subscriber_path:match("%.%*$") then
            local base_path = subscriber_path:gsub("%.%*$", "")
            if path:find("^" .. base_path .. "%.") then
                for _, callback in ipairs(callbacks) do
                    pcall(callback, path, old_value, new_value)
                end
            end
        end
    end
end

-- Update the player state portion with current data
function TE.state.update_player_state()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return false
    end
    
    TE.state.set("player.health_current", me:get_health())
    TE.state.set("player.health_max", me:get_max_health())
    TE.state.set("player.health_percent", (me:get_health() / me:get_max_health()) * 100)
    TE.state.set("player.position", me:get_position())
    TE.state.set("player.in_combat", me:is_in_combat())
    
    -- Update resources based on class
    local class_id = me:get_class()
    local resources = TE.state.get_class_resources(class_id)
    
    for _, resource_type in ipairs(resources) do
        TE.state.set("player.resource_current." .. resource_type, me:get_power(resource_type))
        TE.state.set("player.resource_max." .. resource_type, me:get_max_power(resource_type))
    end
    
    -- Update specialization
    TE.state.set("player.spec", core.spell_book.get_specialization_id())
    
    -- Update target
    local target = me:get_target()
    if target and target:is_valid() then
        TE.state.set("player.target", target)
    else
        TE.state.set("player.target", nil)
    end
    
    return true
end

-- Get resource types for a class
function TE.state.get_class_resources(class_id)
    local resources = {0} -- Health is always resource 0
    
    -- Add class-specific resources
    -- Reference: https://wowpedia.fandom.com/wiki/Enum.PowerType
    if class_id == 1 then        -- Warrior
        table.insert(resources, 1) -- Rage
    elseif class_id == 2 then    -- Paladin
        table.insert(resources, 0) -- Mana
        table.insert(resources, 9) -- Holy Power
    elseif class_id == 3 then    -- Hunter
        table.insert(resources, 2) -- Focus
    elseif class_id == 4 then    -- Rogue
        table.insert(resources, 3) -- Energy
        table.insert(resources, 4) -- Combo Points
    elseif class_id == 5 then    -- Priest
        table.insert(resources, 0) -- Mana
        table.insert(resources, 13) -- Insanity
    elseif class_id == 6 then    -- Death Knight
        table.insert(resources, 5) -- Runes
        table.insert(resources, 6) -- Runic Power
    elseif class_id == 7 then    -- Shaman
        table.insert(resources, 0) -- Mana
        table.insert(resources, 11) -- Maelstrom
    elseif class_id == 8 then    -- Mage
        table.insert(resources, 0) -- Mana
        table.insert(resources, 16) -- Arcane Charges
    elseif class_id == 9 then    -- Warlock
        table.insert(resources, 0) -- Mana
        table.insert(resources, 7) -- Soul Shards
    elseif class_id == 10 then   -- Monk
        table.insert(resources, 3) -- Energy
        table.insert(resources, 12) -- Chi
    elseif class_id == 11 then   -- Druid
        table.insert(resources, 0) -- Mana
        table.insert(resources, 3) -- Energy
        table.insert(resources, 4) -- Combo Points
        table.insert(resources, 8) -- Lunar Power
    elseif class_id == 12 then   -- Demon Hunter
        table.insert(resources, 17) -- Fury
        table.insert(resources, 18) -- Pain
    elseif class_id == 13 then   -- Evoker
        table.insert(resources, 0) -- Mana
        table.insert(resources, 19) -- Essence
    end
    
    return resources
end

-- Update the combat state portion
function TE.state.update_combat_state()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return false
    end
    
    local in_combat = me:is_in_combat()
    local current_time = core.game_time()
    
    -- Check for combat state changes
    if in_combat ~= TE.state.get("combat.in_progress") then
        if in_combat then
            -- Combat started
            TE.state.set("combat.in_progress", true)
            TE.state.set("combat.start_time", current_time)
            TE.state.set("combat.incoming_damage.total", 0)
            TE.state.set("combat.incoming_damage.physical", 0)
            TE.state.set("combat.incoming_damage.magical", 0)
            TE.state.set("combat.incoming_damage.history", {})
        else
            -- Combat ended
            TE.state.set("combat.in_progress", false)
            TE.state.set("combat.duration", current_time - TE.state.get("combat.start_time"))
        end
    end
    
    -- Update combat duration if in combat
    if in_combat then
        TE.state.set("combat.duration", current_time - TE.state.get("combat.start_time"))
    end
    
    return true
end

-- Record a damage event
function TE.state.record_damage(amount, damage_type, source)
    if not amount or amount <= 0 then return false end
    
    local current_time = core.game_time()
    local history = TE.state.get("combat.incoming_damage.history") or {}
    
    -- Record the damage event
    local event = {
        time = current_time,
        amount = amount,
        type = damage_type or "physical", -- Default to physical
        source = source,
    }
    
    table.insert(history, event)
    
    -- Limit history size
    if #history > 20 then
        table.remove(history, 1)
    end
    
    -- Update history and totals
    TE.state.set("combat.incoming_damage.history", history)
    
    local total = TE.state.get("combat.incoming_damage.total") or 0
    TE.state.set("combat.incoming_damage.total", total + amount)
    
    if damage_type == "physical" then
        local physical = TE.state.get("combat.incoming_damage.physical") or 0
        TE.state.set("combat.incoming_damage.physical", physical + amount)
    elseif damage_type == "magical" then
        local magical = TE.state.get("combat.incoming_damage.magical") or 0
        TE.state.set("combat.incoming_damage.magical", magical + amount)
    end
    
    -- Check for damage spike
    local recent_damage = 0
    local window_start = current_time - 1000 -- 1 second window
    
    for _, damage_event in ipairs(history) do
        if damage_event.time >= window_start then
            recent_damage = recent_damage + damage_event.amount
        end
    end
    
    local me = core.object_manager.get_local_player()
    if me and me:is_valid() then
        local max_health = me:get_max_health()
        local damage_percent = (recent_damage / max_health) * 100
        
        -- Consider a spike if damage exceeds 20% of max health in 1 second
        if damage_percent > 20 then
            TE.state.set("combat.incoming_damage.last_spike", current_time)
        end
    end
    
    return true
end

-- Update the targets state portion
function TE.state.update_targets_state()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return false
    end
    
    -- Update current target
    local target = me:get_target()
    if target and target:is_valid() then
        TE.state.set("targets.current", target)
    else
        TE.state.set("targets.current", nil)
    end
    
    -- Update focus target
    local focus = core.input.get_focus()
    if focus and focus:is_valid() then
        TE.state.set("targets.focus", focus)
    else
        TE.state.set("targets.focus", nil)
    end
    
    -- Update mouseover target
    local mouseover = core.object_manager.get_mouse_over_object()
    if mouseover and mouseover:is_valid() then
        TE.state.set("targets.mouseover", mouseover)
    else
        TE.state.set("targets.mouseover", nil)
    end
    
    -- Update nearby enemies and allies
    local position = me:get_position()
    local enemies = TE.api.unit_helper:get_enemy_list_around(position, 40, false, false, false, false)
    local allies = TE.api.unit_helper:get_ally_list_around(position, 40, false, false, false)
    
    TE.state.set("targets.enemies", enemies)
    TE.state.set("targets.allies", allies)
    
    -- Find other tanks
    local tanks = {}
    for _, unit in ipairs(allies) do
        if unit:is_valid() and not unit:is_dead() and TE.api.unit_helper:is_tank(unit) and unit ~= me then
            table.insert(tanks, unit)
        end
    end
    TE.state.set("targets.tanks", tanks)
    
    return true
end

-- Perform a full state update (called on each main update cycle)
function TE.state.update()
    TE.state.update_player_state()
    TE.state.update_combat_state()
    TE.state.update_targets_state()
    
    -- Allow modules to update their state
    for module_name, _ in pairs(TE.state._data.modules) do
        if TE.modules[module_name] and TE.modules[module_name].update_state then
            pcall(TE.modules[module_name].update_state)
        end
    end
end

-- Get a descriptive debug dump of the state for a specific path
function TE.state.debug_dump(path)
    path = path or ""
    local result = {}
    
    local data = path == "" and TE.state._data or TE.state.get(path)
    if not data then
        return "Path not found: " .. path
    end
    
    -- Helper function to recursively dump state
    local function dump_table(t, prefix, depth)
        depth = depth or 0
        if depth > 3 then return "..." end -- Prevent too deep recursion
        
        for k, v in pairs(t) do
            local key = prefix .. (prefix ~= "" and "." or "") .. k
            
            if type(v) == "table" then
                if next(v) == nil then
                    table.insert(result, key .. " = {}")
                else
                    table.insert(result, key .. " = {")
                    dump_table(v, key, depth + 1)
                    table.insert(result, "}")
                end
            elseif type(v) == "function" then
                table.insert(result, key .. " = <function>")
            elseif type(v) == "userdata" then
                table.insert(result, key .. " = <userdata>")
            else
                table.insert(result, key .. " = " .. tostring(v))
            end
        end
    end
    
    if type(data) == "table" then
        dump_table(data, path)
    else
        table.insert(result, path .. " = " .. tostring(data))
    end
    
    return table.concat(result, "\n")
end
