-- Time-To-Death Engine Module
-- Calculates and predicts the time until units will die

TE.modules.ttd_engine = {
    -- State tracking
    health_history = {},             -- Historical health values for regression
    damage_rates = {},               -- Calculated DPS taken by units
    ttd_values = {},                 -- Calculated TTD values for units
    last_update_time = 0,            -- Last update timestamp
    
    -- Menu elements
    menu = {
        main_tree = TE.menu.tree_node(),
        min_combat_time = TE.menu.slider_float(1, 10, 3, "ttd_min_combat_time"),
        regression_window = TE.menu.slider_float(1, 20, 5, "ttd_regression_window"),
        smoothing_factor = TE.menu.slider_float(0.1, 1.0, 0.7, "ttd_smoothing_factor"),
        show_ttd_values = TE.menu.checkbox(false, "ttd_show_values"),
        show_ttd_window = TE.menu.checkbox(true, "ttd_show_window"),
        show_all_targets = TE.menu.checkbox(true, "ttd_show_all_targets"),
        max_targets = TE.menu.slider_int(1, 10, 5, "ttd_max_targets"),
        window_x_position = TE.menu.slider_int(0, 3000, 0, "ttd_window_x_pos"),
        window_y_position = TE.menu.slider_int(0, 2000, 0, "ttd_window_y_pos"),
    },
}

-- Load module files
require("modules/ttd_engine/menu")
require("modules/ttd_engine/settings")
require("modules/ttd_engine/on_update")
require("modules/ttd_engine/render")

-- TTD calculation methods

---Calculate TTD for a specific enemy
---@param unit game_object The unit to calculate TTD for
---@return number time_to_die The estimated time until the unit will die, in seconds
function TE.modules.ttd_engine.calculate_enemy_ttd(unit)
    if not unit or not unit:is_valid() or unit:is_dead() then
        return 0
    end
    
    -- Get stored history
    local history = TE.modules.ttd_engine.health_history[unit]
    if not history or #history < 3 then
        return 9999 -- Not enough data points
    end
    
    local current_time = core.game_time()
    local window_size = TE.modules.ttd_engine.menu.regression_window:get() * 1000 -- Convert to ms
    local current_health = unit:get_health()
    local max_health = unit:get_max_health()
    
    -- If health is very low, return a small value
    if current_health < max_health * 0.02 then
        return 1
    end
    
    -- Filter data points within the regression window
    local valid_data = {}
    for _, data_point in ipairs(history) do
        if current_time - data_point.time <= window_size then
            table.insert(valid_data, data_point)
        end
    end
    
    -- Need at least 3 data points for regression
    if #valid_data < 3 then
        return 9999
    end
    
    -- Calculate linear regression
    local sum_x = 0
    local sum_y = 0
    local sum_xy = 0
    local sum_xx = 0
    local n = #valid_data
    
    for _, data_point in ipairs(valid_data) do
        local x = data_point.time - valid_data[1].time -- Normalize time
        local y = data_point.health
        
        sum_x = sum_x + x
        sum_y = sum_y + y
        sum_xy = sum_xy + (x * y)
        sum_xx = sum_xx + (x * x)
    end
    
    local slope = ((n * sum_xy) - (sum_x * sum_y)) / ((n * sum_xx) - (sum_x * sum_x))
    
    -- If slope is zero or positive, unit isn't taking damage
    if slope >= 0 then
        return 9999
    end
    
    -- Calculate TTD
    local ttd = current_health / math.abs(slope) / 1000 -- Convert to seconds
    
    -- Smoothing with previous TTD value if available
    if TE.modules.ttd_engine.ttd_values[unit] then
        local prev_ttd = TE.modules.ttd_engine.ttd_values[unit]
        local smoothing = TE.modules.ttd_engine.menu.smoothing_factor:get()
        ttd = (prev_ttd * smoothing) + (ttd * (1 - smoothing))
    end
    
    -- Clamp to reasonable values
    return math.max(1, math.min(ttd, 9999))
end

---Calculate TTD for a group of enemies
---@param units table<game_object> The units to calculate group TTD for
---@return number average_ttd The average TTD of the group
function TE.modules.ttd_engine.calculate_group_ttd(units)
    local total_ttd = 0
    local count = 0
    
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local ttd = TE.modules.ttd_engine.ttd_values[unit] or TE.modules.ttd_engine.calculate_enemy_ttd(unit)
            if ttd < 9999 then
                total_ttd = total_ttd + ttd
                count = count + 1
            end
        end
    end
    
    return count > 0 and (total_ttd / count) or 9999
end

---Get a target prioritized by TTD within a range
---@param min_ttd number Minimum acceptable TTD
---@param max_ttd number Maximum acceptable TTD
---@return game_object|nil target The target with appropriate TTD, or nil if no valid target found
function TE.modules.ttd_engine.get_priority_target_by_ttd(min_ttd, max_ttd)
    local best_target = nil
    local best_ttd = max_ttd + 1
    
    min_ttd = min_ttd or 1
    max_ttd = max_ttd or 15
    
    for unit, ttd in pairs(TE.modules.ttd_engine.ttd_values) do
        if unit and unit:is_valid() and not unit:is_dead() then
            if ttd >= min_ttd and ttd <= max_ttd and (best_target == nil or ttd < best_ttd) then
                best_target = unit
                best_ttd = ttd
            end
        end
    end
    
    return best_target
end

-- Module interface for core system
return {
    on_update = TE.modules.ttd_engine.on_normal_update,
    on_fast_update = TE.modules.ttd_engine.on_fast_update,
    on_render_menu = TE.modules.ttd_engine.menu.on_render_menu,
    on_render = TE.modules.ttd_engine.on_render,
}

