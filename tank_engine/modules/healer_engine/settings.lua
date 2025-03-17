-- Healer Engine Settings Module

TE.modules.healer_engine.settings = {
    -- Settings accessed through menu elements
    is_tracking_enabled = function() return TE.modules.healer_engine.menu.enable_tracking:get_state() end,
    alert_on_low_mana = function() return TE.modules.healer_engine.menu.alert_on_low_mana:get_state() end,
    low_mana_threshold = function() return TE.modules.healer_engine.menu.low_mana_threshold:get() end,
    show_healer_info = function() return TE.modules.healer_engine.menu.show_healer_info:get_state() end,
    adjust_for_healers = function() return TE.modules.healer_engine.menu.adjust_for_healers:get_state() end,
}
