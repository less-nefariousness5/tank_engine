---@diagnostic disable: missing-fields

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- Global state management
TE.variables = {
    ---@type game_object
    me = core.object_manager.get_local_player(),
    
    ---@type fun(): game_object?
    target = function() return TE.variables.me:get_target() end,
    
    ---@type fun(): game_object?
    enemy_target = function() 
        return TE.variables.is_valid_enemy_target() and TE.variables.me:get_target() or nil 
    end,
    
    ---@type fun(): boolean
    is_valid_enemy_target = function()
        local target = TE.variables.target()
        if not target then return false end
        if not target:is_valid() then return false end
        if target:is_dead() then return false end
        if not TE.variables.me:can_attack(target) then return false end
        return true
    end,
    
    -- Current combat state
    in_combat = false,
    
    -- Tank-specific state
    active_mitigation = {
        is_active = false,
        expires_at = 0,
        effectiveness = 0,   -- 0-1 value representing effectiveness
    },
    
    -- Threat state
    threat_status = {
        has_aggro = false,
        losing_aggro = false,
        aggro_targets = 0,   -- Number of enemies targeting tank
    },
    
    -- Group state
    group = {
        size = 0,
        has_offtank = false,
        offtank = nil,
    },
    
    -- Dungeon state
    dungeon = {
        is_mythic_plus = false,
        key_level = 0,
    },
}

---Check if a buff is active on a unit
---@param spell_id number
---@param unit? game_object
---@return boolean
function TE.variables.buff_up(spell_id, unit)
    unit = unit or TE.variables.me
    if not unit or not unit:is_valid() or unit:is_dead() then return false end
    return buff_manager:get_buff_data(unit, { spell_id }).is_active
end

---Get the remaining time on a buff
---@param spell_id number
---@param unit? game_object
---@return number
function TE.variables.buff_remains(spell_id, unit)
    if not unit or not unit:is_valid() or unit:is_dead() then return 0 end
    unit = unit or TE.variables.me
    return buff_manager:get_buff_data(unit, { spell_id }).remaining
end

---Get the stack count of a buff
---@param spell_id number
---@param unit? game_object
---@return number
function TE.variables.buff_stacks(spell_id, unit)
    if not unit or not unit:is_valid() or unit:is_dead() then return 0 end
    unit = unit or TE.variables.me
    return buff_manager:get_buff_data(unit, { spell_id }).stacks
end

---Check if an aura is active
---@param spell_id number
---@return boolean
function TE.variables.aura_up(spell_id)
    return buff_manager:get_aura_data(TE.variables.me, { spell_id }).is_active
end

---Get the remaining time on an aura
---@param spell_id number
---@return number
function TE.variables.aura_remains(spell_id)
    return buff_manager:get_aura_data(TE.variables.me, { spell_id }).remaining
end

---Get a resource value
---@param power_type number
---@return number
function TE.variables.resource(power_type)
    return TE.variables.me:get_power(power_type)
end

---Get resource as percentage
---@param power_type number
---@return number
function TE.variables.resource_percent(power_type)
    local current = TE.variables.me:get_power(power_type)
    local max = TE.variables.me:get_max_power(power_type)
    return max > 0 and (current / max * 100) or 0
end

---Check if an ability is on cooldown
---@param spell_id number
---@return boolean
function TE.variables.on_cooldown(spell_id)
    return core.spell_book.get_spell_cooldown(spell_id) > 0
end

---Get the cooldown remaining on an ability
---@param spell_id number
---@return number
function TE.variables.cooldown_remains(spell_id)
    return core.spell_book.get_spell_cooldown(spell_id)
end

---Check if player has aggro from a unit
---@param unit game_object
---@return boolean
function TE.variables.has_aggro(unit)
    if not unit or not unit:is_valid() or unit:is_dead() then return false end
    local threat = unit:get_threat_situation(TE.variables.me)
    return threat and threat.is_tanking or false
end

---Get player's health as a percentage
---@return number
function TE.variables.health_percent()
    return TE.variables.me:get_health() / TE.variables.me:get_max_health() * 100
end
