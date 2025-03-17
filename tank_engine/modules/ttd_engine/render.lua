-- TTD Engine Rendering Module
-- Provides visual display of Time-To-Death information

---@type enums
local enums = require("common/enums")
---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")

-- Store TTD information for display
local display_data = {
    target_name = "",
    ttd_value = 0,
    has_target = false,
    target_list = {} -- For multi-target display
}

-- Configuration
local config = {
    max_targets = 5,    -- Maximum number of targets to display
    show_all = false,   -- If true, shows all targets; if false, shows only current target
    window_pos = nil    -- Will be initialized on first render
}

-- Update TTD display data
local function update_display_data()
    -- Basic validation: Ensure the player exists
    local local_player = core.object_manager.get_local_player()
    if not local_player then
        display_data.has_target = false
        display_data.target_name = ""
        display_data.ttd_value = 0
        display_data.target_list = {}
        return
    end
    
    -- Get current target
    local target = local_player:get_target()
    
    -- Update single target data
    if not target or not target:is_valid() or target:is_dead() then
        display_data.has_target = false
        display_data.target_name = ""
        display_data.ttd_value = 0
    else
        display_data.has_target = true
        display_data.target_name = target:get_name()
        display_data.ttd_value = TE.modules.ttd_engine.ttd_values[target] or 0
    end
    
    -- Update multi-target list
    display_data.target_list = {}
    
    -- Only process if showing all targets and there are TTD values
    if config.show_all and TE.modules.ttd_engine.ttd_values then
        local targets = {}
        
        -- Collect all valid targets with TTD values
        for unit, ttd in pairs(TE.modules.ttd_engine.ttd_values) do
            if unit and unit:is_valid() and not unit:is_dead() and ttd < 100 then
                table.insert(targets, {
                    unit = unit,
                    name = unit:get_name(),
                    ttd = ttd
                })
            end
        end
        
        -- Sort by TTD (lowest first)
        table.sort(targets, function(a, b)
            return a.ttd < b.ttd
        end)
        
        -- Take top N targets
        for i = 1, math.min(#targets, config.max_targets) do
            table.insert(display_data.target_list, targets[i])
        end
    end
end

-- Get appropriate color based on TTD value
local function get_ttd_color(ttd_value)
    if ttd_value < 5 then
        return color.red(255)    -- Dying soon
    elseif ttd_value < 15 then
        return color.yellow(255) -- Medium TTD
    else
        return color.green(255)  -- Long TTD
    end
end

-- Render TTD information in a floating window
function TE.modules.ttd_engine.render_ttd_window()
    -- Only render if module and display are enabled
    if not TE.settings.is_enabled() or not TE.modules.ttd_engine.settings.display.show_ttd_window() then
        return
    end
    
    -- Update display data
    update_display_data()
    
    -- Check if we should show multi-target view
    config.show_all = TE.modules.ttd_engine.settings.display.show_all_targets()
    
    -- Get screen size to determine UI scaling
    local screen_size = core.graphics.get_screen_size()
    
    -- Determine window size based on display mode
    local window_width = 180
    local window_height = config.show_all and (25 * (1 + #display_data.target_list)) or 25
    
    -- Apply UI scaling
    local scale_factor = 1.0
    if screen_size.y >= 2000 then
        scale_factor = 1.5
    elseif screen_size.y >= 1440 then
        scale_factor = 1.3
    end
    
    -- Scale window dimensions
    local button_size = vec2.new(window_width * scale_factor, window_height * scale_factor)
    local font_id = scale_factor > 1.3 
        and enums.window_enums.font_id.FONT_SEMI_BIG
        or (scale_factor > 1.0 
            and enums.window_enums.font_id.FONT_NORMAL
            or enums.window_enums.font_id.FONT_SMALL)
    
    -- Define background color for the UI window
    local background_color = color.new(20, 20, 31, 200) -- Matching Tank Engine style
    
    -- Create a named window in the UI system
    local gui_window = core.menu.window("ttd_display_window_id")
    
    -- Initialize window position if needed
    if not config.window_pos then
        local x_pos = TE.modules.ttd_engine.settings.display.window_x_position()
        local y_pos = TE.modules.ttd_engine.settings.display.window_y_position()
        
        -- Use settings if valid, otherwise use defaults
        if x_pos > 0 and y_pos > 0 then
            config.window_pos = vec2.new(x_pos, y_pos)
        else
            -- Default to upper right corner
            config.window_pos = vec2.new(screen_size.x - 200, 100)
        end
    end
    
    -- Set window position
    gui_window:set_initial_position(config.window_pos)
    
    -- Ensure the window maintains the correct size
    gui_window:set_initial_size(button_size)
    
    -- Render the UI window
    local is_window_open = gui_window:begin(
        enums.window_enums.window_resizing_flags.NO_RESIZE, -- Prevents resizing
        false, -- Disables close button
        background_color, -- Window background color
        color.new(40, 40, 60, 220), -- Border color
        enums.window_enums.window_cross_visuals.NO_CROSS, -- No close button visuals
        function()
            -- Apply selected font size
            gui_window:push_font(font_id)
            
            -- Title section
            gui_window:render_text(
                font_id,
                vec2.new(8, 4),
                color.white(220),
                "Time-To-Death"
            )
            
            -- Add separator after title
            if config.show_all and #display_data.target_list > 0 then
                gui_window:add_separator(0, 0, 20, 0, color.gray(150))
                
                -- Render each target in list
                local y_offset = 26 * scale_factor
                for _, target_data in ipairs(display_data.target_list) do
                    local message = string.format("%s: %.1fs", target_data.name, target_data.ttd)
                    local text_color = get_ttd_color(target_data.ttd)
                    
                    gui_window:render_text(
                        font_id,
                        vec2.new(8, y_offset),
                        text_color,
                        message
                    )
                    
                    y_offset = y_offset + (20 * scale_factor)
                end
            else
                -- Single target display
                local message
                if display_data.has_target then
                    if display_data.ttd_value > 0 and display_data.ttd_value < 100 then
                        message = string.format("%s: %.1fs", display_data.target_name, display_data.ttd_value)
                    else
                        message = string.format("%s: --", display_data.target_name)
                    end
                else
                    message = "No Target"
                end
                
                -- Determine text color
                local text_color = display_data.has_target
                    and get_ttd_color(display_data.ttd_value)
                    or color.white(220)
                
                gui_window:render_text(
                    font_id,
                    vec2.new(8, 22 * scale_factor),
                    text_color,
                    message
                )
            end
        end
    )
    
    -- Save window position if moved
    if is_window_open and config.window_pos then
        local new_pos = gui_window:get_position()
        if new_pos.x ~= config.window_pos.x or new_pos.y ~= config.window_pos.y then
            config.window_pos = new_pos
            -- Save to settings
            if TE.modules.ttd_engine.settings.display.set_window_position then
                TE.modules.ttd_engine.settings.display.set_window_position(new_pos.x, new_pos.y)
            end
        end
    end
end
