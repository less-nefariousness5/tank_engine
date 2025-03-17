-- Healer Engine Module
-- Tracks healer performance and incoming healing

---@type health_prediction
local health_prediction = require("common/modules/health_prediction")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

TE.modules.healer_engine = {
    -- State tracking
    healers = {},                  -- Healers in the group
    healing_received = {},         -- Healing received from each healer
    healing_efficiency = {},       -- Healer efficiency scores
    recent_healing = {},           -- Recent healing events
    last_update_time = 0,          -- Last update timestamp
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        enable_tracking = TE.menu.checkbox(true, "healer_enable_tracking"),
        analysis_window = TE.menu.slider_float(2, 20, 5, "healer_analysis_window"),
        show_healer_score = TE.menu.checkbox(true, "healer_show_score"),
        low_healing_threshold = TE.menu.slider_float(0, 100, 30, "healer_low_threshold"),
    },
}

-- Load module files
require("modules/healer_engine/menu")
require("modules/healer_engine/settings")
require("modules/healer_engine/on_update")

-- Healer scoring algorithms

---Calculate a score for a specific healer
---@param healer game_object The healer to score
---@return number score The healer's performance score (0-100)
function TE.modules.healer_engine.calculate_healer_score(healer)
    if not healer or not healer:is_valid() or healer:is_dead() then
        return 0
    end
    
    -- Get healing history for this healer
    local healing_data = TE.modules.healer_engine.healing_received[healer]
    if not healing_data or #healing_data == 0 then
        return 50 -- Default score with no data
    end
    
    local current_time = core.game_time()
    local window_size = TE.modules.healer_engine.menu.analysis_window:get() * 1000 -- Convert to ms
    
    -- Filter data points within the analysis window
    local valid_data = {}
    for _, data_point in ipairs(healing_data) do
        if current_time - data_point.time <= window_size then
            table.insert(valid_data, data_point)
        end
    end
    
    -- If no recent healing, lower score
    if #valid_data == 0 then
        return 30
    end
    
    -- Calculate metrics
    local total_healing = 0
    local healing_events = #valid_data
    local last_heal_time = valid_data[#valid_data].time
    local avg_heal_size = 0
    
    for _, data_point in ipairs(valid_data) do
        total_healing = total_healing + data_point.amount
    end
    
    if healing_events > 0 then
        avg_heal_size = total_healing / healing_events
    end
    
    -- Calculate healing rate (per second)
    local healing_rate = total_healing / (window_size / 1000)
    
    -- Get healer mana percentage
    local mana_percent = healer:get_power(0) / healer:get_max_power(0) * 100
    
    -- Calculate base score components
    local healing_score = math.min(100, healing_rate / (TE.variables.me:get_max_health() * 0.1) * 50)
    local recency_score = math.max(0, 100 - ((current_time - last_heal_time) / 500))
    local mana_score = mana_percent
    
    -- Combine scores with weights
    local final_score = (healing_score * 0.5) + (recency_score * 0.3) + (mana_score * 0.2)
    
    -- Store efficiency score
    TE.modules.healer_engine.healing_efficiency[healer] = final_score
    
    return math.min(100, math.max(0, final_score))
end

---Predict incoming healing over a time window
---@param window number Time window in seconds
---@return number healing_amount The predicted amount of incoming healing
function TE.modules.healer_engine.predict_incoming_healing(window)
    window = window or 3 -- Default 3 second window
    
    -- Use health prediction module for incoming heals
    local incoming_heals = TE.variables.me:get_incoming_heals()
    
    -- Calculate additional predicted healing based on recent healing rate
    local additional_healing = 0
    local total_healing_rate = 0
    
    for healer, _ in pairs(TE.modules.healer_engine.healers) do
        if healer and healer:is_valid() and not healer:is_dead() then
            local score = TE.modules.healer_engine.healing_efficiency[healer] or 50
            local healer_rate = (score / 100) * TE.variables.me:get_max_health() * 0.10 -- 10% of max health per second at 100 score
            total_healing_rate = total_healing_rate + healer_rate
        end
    end
    
    additional_healing = total_healing_rate * window
    
    return incoming_heals + additional_healing
end

---Determine if incoming healing is sufficient for current situation
---@param incoming_damage number Predicted incoming damage
---@return boolean is_sufficient Whether healing is sufficient
---@return number healing_deficit The amount of additional healing needed (if any)
function TE.modules.healer_engine.is_healing_sufficient(incoming_damage)
    -- Default to 5 seconds of incoming damage if not specified
    incoming_damage = incoming_damage or 0
    
    -- Get current health deficit
    local current_health = TE.variables.me:get_health()
    local max_health = TE.variables.me:get_max_health()
    local health_deficit = max_health - current_health
    
    -- Predict incoming healing over next 5 seconds
    local predicted_healing = TE.modules.healer_engine.predict_incoming_healing(5)
    
    -- Calculate total deficit including incoming damage
    local total_deficit = health_deficit + incoming_damage
    
    -- Check if healing is sufficient
    local is_sufficient = predicted_healing >= total_deficit
    local healing_needed = math.max(0, total_deficit - predicted_healing)
    
    return is_sufficient, healing_needed
end

-- Module interface for core system
return {
    on_update = TE.modules.healer_engine.on_update,
    on_fast_update = nil, -- No need for fast updates
    on_render_menu = TE.modules.healer_engine.menu.on_render_menu,
    on_render = TE.modules.healer_engine.on_render,
}
