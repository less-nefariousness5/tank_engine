-- Tank Engine API Integration
-- This file provides centralized access to game APIs

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type combat_forecast
local combat_forecast = require("common/modules/combat_forecast")
---@type health_prediction
local health_prediction = require("common/modules/health_prediction")
---@type spell_helper
local spell_helper = require("common/utility/spell_helper")
---@type spell_queue
local spell_queue = require("common/modules/spell_queue")
---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type target_selector
local target_selector = require("common/modules/target_selector")
---@type plugin_helper
local plugin_helper = require("common/utility/plugin_helper")
---@type control_panel_helper
local control_panel_helper = require("common/utility/control_panel_helper")
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type movement_handler
local movement_handler = require("common/utility/movement_handler")
---@type wigs_tracker
local wigs_tracker = require("common/utility/wigs_tracker")

-- Export all API components
TE.api = {
    buff_manager = buff_manager,
    combat_forecast = combat_forecast,
    health_prediction = health_prediction,
    spell_helper = spell_helper,
    spell_queue = spell_queue,
    unit_helper = unit_helper,
    target_selector = target_selector,
    plugin_helper = plugin_helper,
    control_panel_helper = control_panel_helper,
    key_helper = key_helper,
    movement_handler = movement_handler,
    wigs_tracker = wigs_tracker,
    graphics = core.graphics,
}
