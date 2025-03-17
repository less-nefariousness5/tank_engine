-- Pull Engine Settings
-- Settings for the Pull Planning engine

TE.modules.pull_engine.settings = {
    -- Pull settings
    pull = {
        ---@type fun(): boolean
        enable_pull_planning = function() return TE.modules.pull_engine.menu.enable_pull_planning:get_state() end,
        
        ---@type fun(): boolean
        auto_pull = function() return TE.modules.pull_engine.menu.auto_pull:get_state() end,
        
        ---@type fun(): boolean
        los_pulling = function() return TE.modules.pull_engine.menu.los_pulling:get_state() end,
    },
    
    -- Pull size settings
    size = {
        ---@type fun(): number
        safe_pull_size = function() return TE.modules.pull_engine.menu.safe_pull_size:get() end,
        
        ---@type fun(): number
        max_pull_size = function() return TE.modules.pull_engine.menu.max_pull_size:get() end,
        
        ---@type fun(): boolean
        analyze_cooldowns = function() return TE.modules.pull_engine.menu.analyze_cooldowns:get_state() end,
    },
    
    -- Scanning settings
    scanning = {
        ---@type fun(): number
        pull_scan_radius = function() return TE.modules.pull_engine.menu.pull_scan_radius:get() end,
    },
    
    -- Display settings
    display = {
        ---@type fun(): boolean
        show_pack_info = function() return TE.modules.pull_engine.menu.show_pack_info:get_state() end,
        
        ---@type fun(): boolean
        show_pull_path = function() return TE.modules.pull_engine.menu.show_pull_path:get_state() end,
    }
}
