-- Tank Engine Settings Module
-- This file provides core settings functionality for the Tank Engine

---@type plugin_helper
local plugin_helper = require("common/utility/plugin_helper")

TE.settings = {
    ---@type fun(): boolean
    is_enabled = function() return TE.menu.enable_script_check:get_state() end,
    ---@type fun(): integer
    min_delay = function() return TE.menu.min_delay:get() end,
    ---@type fun(): integer
    max_delay = function() return TE.menu.max_delay:get() end,
}

---@param keybind keybind
---@return boolean
function TE.settings.is_toggle_enabled(keybind)
    return plugin_helper:is_toggle_enabled(keybind)
end
