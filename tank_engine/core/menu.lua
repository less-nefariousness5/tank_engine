-- Tank Engine Menu Module
-- This file provides core menu functionality for the Tank Engine

---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

local tag = "tank_engine_"

-- Initialize the menu namespace
TE.menu = {
    main_tree = core.menu.tree_node(),
    enable_script_check = core.menu.checkbox(true, tag .. "enable_script_check"),
    humanizer = core.menu.header(),
    min_delay = core.menu.slider_int(100, 300, 150, tag .. "min_delay"),
    max_delay = core.menu.slider_int(200, 500, 300, tag .. "max_delay")
}

-- Default window style configuration
TE.menu.window_style = {
    background = {
        top_left = color.new(20, 20, 31, 255),
        top_right = color.new(31, 31, 46, 255),
        bottom_right = color.new(20, 20, 31, 255),
        bottom_left = color.new(31, 31, 46, 255)
    },
    size = vec2.new(800, 500),
    padding = vec2.new(15, 15),
    header_color = color.new(255, 255, 255, 255),
    header_spacing = 36,
    column_spacing = 400
}

-- Window helper functions
---Setup window with default styling
---@param window window The window to setup
function TE.menu.setup_window(window)
    window:set_background_multicolored(
        TE.menu.window_style.background.top_left,
        TE.menu.window_style.background.top_right,
        TE.menu.window_style.background.bottom_right,
        TE.menu.window_style.background.bottom_left
    )
    window:set_initial_size(TE.menu.window_style.size)
    window:set_next_window_padding(TE.menu.window_style.padding)
end

---Render a header with consistent styling
---@param window window The window to render in
---@param text string The header text
function TE.menu.render_header(window, text)
    if not window then return end
    local dynamic = window:get_current_context_dynamic_drawing_offset()
    window:render_text(1, vec2.new(dynamic.x, dynamic.y), TE.menu.window_style.header_color, text)
    window:set_current_context_dynamic_drawing_offset(
        vec2.new(dynamic.x, dynamic.y + TE.menu.window_style.header_spacing)
    )
end

-- Menu creation shortcuts
function TE.menu.tree_node()
    return core.menu.tree_node()
end

function TE.menu.checkbox(default_state, id)
    return core.menu.checkbox(default_state, tag .. id)
end

function TE.menu.key_checkbox(default_key, initial_toggle_state, default_state, show_in_binds, default_mode_state, id)
    return core.menu.key_checkbox(default_key, initial_toggle_state, default_state, show_in_binds, default_mode_state,
        tag .. id)
end

function TE.menu.slider_int(min_value, max_value, default_value, id)
    return core.menu.slider_int(min_value, max_value, default_value, tag .. id)
end

function TE.menu.slider_float(min_value, max_value, default_value, id)
    return core.menu.slider_float(min_value, max_value, default_value, tag .. id)
end

function TE.menu.combobox(default_index, id)
    return core.menu.combobox(default_index, tag .. id)
end

function TE.menu.combobox_reorderable(default_index, id)
    return core.menu.combobox_reorderable(default_index, tag .. id)
end

function TE.menu.keybind(default_value, initial_toggle_state, id)
    return core.menu.keybind(default_value, initial_toggle_state, tag .. id)
end

function TE.menu.button(id)
    return core.menu.button(tag .. id)
end

function TE.menu.colorpicker(default_color, id)
    return core.menu.colorpicker(default_color, tag .. id)
end

function TE.menu.header()
    return core.menu.header()
end

function TE.menu.text_input(id)
    return core.menu.text_input(tag .. id)
end

function TE.menu.window(window_id)
    return core.menu.window(tag .. window_id)
end
