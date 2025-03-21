-- Healer Engine Update Logic
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Fast update for critical operations (called every frame)
function TE.modules.healer_engine.on_fast_update()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Placeholder for future implementation
    -- This would monitor healers' casts and mana in real-time
end

-- Normal update for less time-critical operations
function TE.modules.healer_engine.on_normal_update()
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Initialize healer data if needed
    if not TE.modules.healer_engine.healing_efficiency then
        TE.modules.healer_engine.healing_efficiency = {}
    end
    
    if not TE.modules.healer_engine.healers then
        TE.modules.healer_engine.healers = {}
    end
    
    -- Find healers in the group
    local units = core.object_manager.get_all_objects()
    for _, unit in pairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() and 
           unit:is_player() and unit:is_party_member() and
           unit:get_group_role() == 1 then -- 1 = HEALER role
            
            -- Track healer
            TE.modules.healer_engine.healers[unit] = true
            
            -- Track mana percentage
            local mana = unit:get_power(0) -- 0 = MANA
            local max_mana = unit:get_max_power(0)
            local mana_pct = max_mana > 0 and (mana / max_mana) or 1.0
            
            -- Check for low mana alert
            if TE.modules.healer_engine.menu and TE.modules.healer_engine.menu.alert_on_low_mana and
               TE.modules.healer_engine.menu.alert_on_low_mana:get_state() and
               TE.modules.healer_engine.menu.low_mana_threshold and
               mana_pct < TE.modules.healer_engine.menu.low_mana_threshold:get() then
                
                -- Alert about low healer mana
                core.log("HEALER LOW MANA: " .. unit:get_name() .. " at " .. math.floor(mana_pct * 100) .. "%")
                
                -- Store efficiency placeholder (would be calculated based on healing done vs. mana spent)
                TE.modules.healer_engine.healing_efficiency[unit] = mana_pct * 100
            end
        end
    end
end

-- Render healer information on screen
function TE.modules.healer_engine.on_render()
    if not TE.settings.is_enabled() or 
       not TE.modules.healer_engine.menu or 
       not TE.modules.healer_engine.menu.show_healer_info or
       not TE.modules.healer_engine.menu.show_healer_info:get_state() then
        return
    end
    
    -- Example of drawing healer info
    local y_pos = 100
    for unit, _ in pairs(TE.modules.healer_engine.healers or {}) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local mana = unit:get_power(0)
            local max_mana = unit:get_max_power(0)
            local mana_pct = max_mana > 0 and (mana / max_mana) or 1.0
            
            -- Create display text
            local healer_text = unit:get_name() .. ": " .. math.floor(mana_pct * 100) .. "% mana"
            
            -- Choose color based on mana percentage
            local text_color
            if mana_pct < 0.3 then
                text_color = color.red(255)
            elseif mana_pct < 0.6 then
                text_color = color.yellow(255)
            else
                text_color = color.green(255)
            end
            
            -- Draw text
            core.graphics.text_2d(healer_text, vec2.new(100, y_pos), 14, text_color)
            y_pos = y_pos + 20
        end
    end
end

