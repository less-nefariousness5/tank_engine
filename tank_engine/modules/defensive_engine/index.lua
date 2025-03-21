-- Defensive Engine Module
-- Optimizes defensive cooldown usage based on incoming damage patterns

-- Create module table in the TE namespace if it doesn't exist
if not TE.modules.defensive_engine then
    TE.modules.defensive_engine = {
        -- State tracking
        incoming_damage_history = {},  -- Historical damage intake
        damage_spikes = {},            -- Detected spike damage patterns
        cooldowns_available = {},      -- Available defensive cooldowns
        
        -- Menu elements
        menu = {
            main_tree = core.menu.tree_node(),
            health_threshold = core.menu.slider_float(0, 100, 50, "defensive_health_threshold"),
            damage_spike_threshold = core.menu.slider_float(0, 50, 20, "defensive_spike_threshold"),
            auto_defensives = core.menu.checkbox(true, "defensive_auto_defensives"),
            prioritize_physical = core.menu.checkbox(true, "defensive_prioritize_physical"),
        },
    }
end

-- Load module files
require("modules/defensive_engine/menu")
require("modules/defensive_engine/on_update")

-- Update function called every frame (duplicate)
-- Remove the duplicate function definition and use the existing one from index.lua
function TE.modules.defensive_engine.on_index_update()
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or not me:is_in_combat() then
        return
    end
    
    -- Get current health percentage
    local health_percent = (me:get_health() / me:get_max_health()) * 100
    
    -- Check health threshold
    local threshold = TE.modules.defensive_engine.menu.health_threshold:get()
    
    if health_percent < threshold and TE.modules.defensive_engine.menu.auto_defensives:get_state() then
        core.log("Tank Engine: Health below threshold (" .. math.floor(health_percent) .. "%), consider using defensives")
        
        -- This would check available defensive cooldowns and use them
        -- For now, just log the recommendation
        core.log("Tank Engine: Recommending defensive cooldown usage")
    end
    
    -- Track damage for spike detection
    local current_time = core.game_time()
    local current_health = me:get_health()
    local last_health = TE.modules.defensive_engine.last_health or current_health
    
    if last_health > current_health then
        local damage_amount = last_health - current_health
        
        -- Record damage event
        table.insert(TE.modules.defensive_engine.incoming_damage_history, {
            time = current_time,
            amount = damage_amount
        })
        
        -- Limit history size
        if #TE.modules.defensive_engine.incoming_damage_history > 50 then
            table.remove(TE.modules.defensive_engine.incoming_damage_history, 1)
        end
        
        -- Check for damage spike
        local spike_threshold = TE.modules.defensive_engine.menu.damage_spike_threshold:get() / 100
        local max_health = me:get_max_health()
        
        if damage_amount > (max_health * spike_threshold) then
            core.log("Tank Engine: Damage spike detected! (" .. math.floor((damage_amount / max_health) * 100) .. "% of max health)")
            
            table.insert(TE.modules.defensive_engine.damage_spikes, {
                time = current_time,
                amount = damage_amount,
                percent = (damage_amount / max_health) * 100
            })
            
            -- Limit spikes history
            if #TE.modules.defensive_engine.damage_spikes > 10 then
                table.remove(TE.modules.defensive_engine.damage_spikes, 1)
            end
        end
    end
    
    -- Update last health value
    TE.modules.defensive_engine.last_health = current_health
end

-- Menu render function
function TE.modules.defensive_engine.menu.on_render_menu()
    TE.modules.defensive_engine.menu.main_tree:render("Defensive Management", function()
        TE.modules.defensive_engine.menu.health_threshold:render("Health Threshold", "Use defensives when health falls below this percentage")
        TE.modules.defensive_engine.menu.damage_spike_threshold:render("Spike Threshold", "Detect damage spikes above this percentage of max health")
        TE.modules.defensive_engine.menu.auto_defensives:render("Auto Defensives", "Automatically use defensive cooldowns")
        TE.modules.defensive_engine.menu.prioritize_physical:render("Prioritize Physical", "Prioritize physical damage reduction")
    end)
end

-- Module interface for main system
return {
    on_update = TE.modules.defensive_engine.on_index_update,
    on_render_menu = TE.modules.defensive_engine.menu.on_render_menu
}

