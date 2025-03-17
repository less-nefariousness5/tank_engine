-- Wigs Engine Settings Module

TE.modules.wigs_engine.settings = {
    -- Settings accessed through menu elements
    is_wigs_enabled = function() return TE.modules.wigs_engine.menu.enable_wigs:get_state() end,
    use_defensive_timers = function() return TE.modules.wigs_engine.menu.use_defensive_timers:get_state() end,
    use_offensive_timers = function() return TE.modules.wigs_engine.menu.use_offensive_timers:get_state() end,
    show_active_timers = function() return TE.modules.wigs_engine.menu.show_active_timers:get_state() end,
    pre_defensive_time = function() return TE.modules.wigs_engine.menu.pre_defensive_time:get() end,
}
