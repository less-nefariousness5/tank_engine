-- Wigs Engine Module
-- Tracks and reacts to BigWigs/LittleWigs bars

---@type wigs_tracker
local wigs_tracker = require("common/utility/wigs_tracker")

TE.modules.wigs_engine = {
    -- State tracking
    active_bars = {},                -- Currently active bars
    important_abilities = {},        -- Important abilities to track
    cooldown_timings = {},           -- Cooldown timings relative to bars
    last_update_time = 0,            -- Last update timestamp
    warning_threshold = 3,           -- Time threshold for warnings (seconds)
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        enable_tracking = TE.menu.checkbox(true, "wigs_enable_tracking"),
        warning_threshold = TE.menu.slider_float(1, 10, 3, "wigs_warning_threshold"),
        auto_defensive = TE.menu.checkbox(true, "wigs_auto_defensive"),
        show_notifications = TE.menu.checkbox(true, "wigs_show_notifications"),
        ignore_bars = TE.menu.text_input("wigs_ignore_bars"),
    },
    
    -- Predefined ability patterns to watch for
    dangerous_patterns = {
        "slam", "crush", "smash", "cleave", "tankbuster",
        "breath", "roar", "shatter", "blast", "explosion",
        "tank bomb", "tank debuff", "tank swap", "taunt"
    }
}

-- Load module files
require("modules/wigs_engine/menu")
require("modules/wigs_engine/settings")
require("modules/wigs_engine/on_update")

-- Helper functions for parsing bar text
local function matches_pattern(text, pattern)
    return string.lower(text):find(string.lower(pattern)) ~= nil
end

local function is_dangerous_ability(text)
    for _, pattern in ipairs(TE.modules.wigs_engine.dangerous_patterns) do
        if matches_pattern(text, pattern) then
            return true
        end
    end
    return false
end

-- Wigs tracking algorithms

---Get the most important bar based on time threshold
---@param time_threshold number Time threshold in seconds
---@return bar_data|nil bar The most important bar
function TE.modules.wigs_engine.get_important_bar(time_threshold)
    time_threshold = time_threshold or TE.modules.wigs_engine.menu.warning_threshold:get()
    
    local all_bars = wigs_tracker:get_all()
    local dangerous_bars = {}
    
    -- Filter bars
    for _, bar in pairs(all_bars) do
        local remaining = bar.expire_time - core.game_time() / 1000
        
        -- Check if this is a bar we care about
        if remaining > 0 and remaining <= time_threshold and is_dangerous_ability(bar.text) then
            table.insert(dangerous_bars, {
                bar = bar,
                remaining = remaining
            })
        end
    end
    
    -- Sort by remaining time (ascending)
    table.sort(dangerous_bars, function(a, b)
        return a.remaining < b.remaining
    end)
    
    return dangerous_bars[1] and dangerous_bars[1].bar or nil
end

---Predict timing of a specific boss ability
---@param ability_name string Name of the ability to look for
---@return number|nil time_remaining Time until the ability in seconds, or nil if not found
function TE.modules.wigs_engine.predict_ability_timing(ability_name)
    local all_bars = wigs_tracker:get_all()
    
    for _, bar in pairs(all_bars) do
        if matches_pattern(bar.text, ability_name) then
            return bar.expire_time - core.game_time() / 1000
        end
    end
    
    return nil
end

---Recommend a cooldown based on upcoming boss abilities
---@param cooldown_id number ID of the cooldown to check
---@return boolean should_use Whether the cooldown should be used
---@return string|nil ability_name Name of the ability to use the cooldown for
function TE.modules.wigs_engine.recommend_cooldown_timing(cooldown_id)
    local cooldown_duration = core.spell_book.get_spell_cooldown(cooldown_id)
    if cooldown_duration > 0 then
        return false, nil -- Cooldown not available
    end
    
    local important_bar = TE.modules.wigs_engine.get_important_bar(5) -- Look 5 seconds ahead
    if important_bar then
        return true, important_bar.text
    end
    
    return false, nil
end

-- Module interface for core system
return {
    on_update = TE.modules.wigs_engine.on_normal_update,
    on_fast_update = nil, -- No need for fast updates
    on_render_menu = TE.modules.wigs_engine.menu.on_render_menu,
    on_render = TE.modules.wigs_engine.on_render,
}

