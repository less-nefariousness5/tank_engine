-- Tank Engine Main Entry Point
-- This file initializes the tank engine framework

---@type enums
local enums = require("common/enums")

---@type color
local color = require("common/color")

-- Define TE namespace for our internal use
TE = {
    version = {
        major = 1,
        minor = 0,
        patch = 0,
        toString = function(self)
            return string.format("%d.%d.%d", self.major, self.minor, self.patch)
        end
    },
    modules = {},
    loaded_modules = {}
}

-- Initialize with a simple log
core.log("Tank Engine v" .. TE.version:toString() .. " loaded successfully!")

-- Menu elements will be defined in core/menu.lua

-- Initialize with a simple log
core.log("Tank Engine v" .. TE.version:toString() .. " loaded successfully!")

-- Load core modules
local function load_core_modules()
    local core_modules = {
        "core/menu",      -- Load menu first
        "core/settings",  -- Load settings after menu
        "core/api",
        "core/humanizer",
        "core/variables"
    }
    
    for _, module_path in ipairs(core_modules) do
        local success, _ = pcall(require, module_path)
        if not success then
            core.log_error("Failed to load core module: " .. module_path)
        end
    end
end

-- Create a stub module with WIP tag
local function create_stub_module(module_name)
    -- Create the module namespace if it doesn't exist
    if not TE.modules[module_name] then
        TE.modules[module_name] = {
            -- Menu elements
            menu = {
                main_tree = core.menu.tree_node(),
            }
        }
    end
    
    -- Format the display name
    local display_name = module_name:gsub("_engine", ""):gsub("_", " ")
    
    -- Capitalize words
    display_name = display_name:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest
    end)
    
    -- Add menu render function
    TE.modules[module_name].menu.on_render_menu = function()
        TE.modules[module_name].menu.main_tree:render(display_name .. " [WIP]", function()
            -- Create header
            local yellow_color = color.yellow()
            local header = core.menu.header()
            header:render("Work In Progress", yellow_color)
            
            -- Create description
            local gui_window = core.menu.window("stub_module_window")
            gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), yellow_color, "This module is not yet implemented.")
            gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), color.white(), "It will be available in a future update.")
            gui_window:add_separator(5, 5, 0, 0, color.white(200))
            
            -- Module description
            local descriptions = {
                threat_engine = "Manages threat tracking and taunt optimization",
                defensive_engine = "Optimizes defensive cooldown usage based on incoming damage",
                healer_engine = "Monitors healer performance and adjusts strategy",
                interrupt_engine = "Handles spell interruption and crowd control",
                mitigation_engine = "Ensures active mitigation uptime and resource usage",
                pull_engine = "Optimizes dungeon routes and pull sizes",
                resource_engine = "Manages resource generation and spending",
                survival_engine = "Provides emergency actions based on health tracking",
                wigs_engine = "Integrates with BigWigs/LittleWigs timers",
                ttd_engine = "Calculates time-to-death for enemies"
            }
            
            -- Display description if available
            if descriptions[module_name] then
                local gui_window = core.menu.window("stub_module_window")
                gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), color.cyan(), "Purpose: " .. descriptions[module_name])
            end
        end)
    end
    
    -- Add empty update function
    TE.modules[module_name].on_update = function() end
    
    -- Return a module interface
    local stub_module = {
        on_update = TE.modules[module_name].on_update,
        on_render_menu = TE.modules[module_name].menu.on_render_menu
    }
    
    -- Add to loaded modules
    table.insert(TE.loaded_modules, stub_module)
    
    core.log("Created stub module: " .. module_name)
    
    return stub_module
end

-- Create a partial module with WIP tag but showing it's partially implemented
local function create_partial_module(module_name)
    -- Create the module namespace if it doesn't exist
    if not TE.modules[module_name] then
        TE.modules[module_name] = {
            -- Menu elements
            menu = {
                main_tree = core.menu.tree_node(),
            }
        }
    end
    
    -- Format the display name
    local display_name = module_name:gsub("_engine", ""):gsub("_", " ")
    
    -- Capitalize words
    display_name = display_name:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest
    end)
    
    -- Add menu render function
    TE.modules[module_name].menu.on_render_menu = function()
        TE.modules[module_name].menu.main_tree:render(display_name .. " [Partial]", function()
            -- Create header
            local orange_color = color.orange()
            local header = core.menu.header()
            header:render("Partially Implemented", orange_color)
            
            -- Create description
            local gui_window = core.menu.window("stub_module_window")
            gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), orange_color, "This module is partially implemented.")
            gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), color.white(), "Some features may not be available yet.")
            gui_window:add_separator(5, 5, 0, 0, color.white(200))
            
            -- Module description
            local descriptions = {
                healer_engine = "Monitors healer performance and adjusts strategy",
                wigs_engine = "Integrates with BigWigs/LittleWigs timers"
            }
            
            -- Display description if available
            if descriptions[module_name] then
                local gui_window = core.menu.window("stub_module_window")
                gui_window:render_text(1, gui_window:get_current_context_dynamic_drawing_offset(), color.cyan(), "Purpose: " .. descriptions[module_name])
            end
        end)
    end
    
    -- Add empty update function if needed
    if not TE.modules[module_name].on_update then
        TE.modules[module_name].on_update = function() end
    end
    
    -- Return a module interface
    local partial_module = {
        on_update = TE.modules[module_name].on_update,
        on_render_menu = TE.modules[module_name].menu.on_render_menu
    }
    
    -- Add to loaded modules
    table.insert(TE.loaded_modules, partial_module)
    
    core.log("Created partial module wrapper: " .. module_name)
    
    return partial_module
end

-- Load engine modules
local function load_engine_modules()
    -- Check which modules are complete vs. incomplete
    local complete_modules = {
        "modules/threat_engine/index",
        "modules/defensive_engine/index",
        "modules/ttd_engine/index",
        "modules/pull_engine/index",
        "modules/mitigation_engine/index",
        "modules/interrupt_engine/index"
    }
    
    -- Partial modules (have at least index.lua but may be incomplete)
    local partial_modules = {
        "modules/healer_engine/index",
        "modules/wigs_engine/index"
    }
    
    -- Modules not yet implemented
    local missing_modules = {
        "resource_engine",
        "survival_engine"
    }
    
    -- Load complete modules
    for _, module_path in ipairs(complete_modules) do
        local success, module = pcall(require, module_path)
        if success then
            table.insert(TE.loaded_modules, module)
            core.log("Loaded complete module: " .. module_path)
        else
            core.log_error("Failed to load module: " .. module_path .. ". Error: " .. tostring(module))
        end
    end
    
    -- Load partial modules
    for _, module_path in ipairs(partial_modules) do
        local success, module = pcall(require, module_path)
        if success then
            table.insert(TE.loaded_modules, module)
            core.log("Loaded partial module: " .. module_path)
        else
            core.log_error("Failed to load partial module: " .. module_path)
            
            -- Extract module name
            local module_name = module_path:match("modules/([^/]+)")
            if module_name then
                create_partial_module(module_name)
            end
        end
    end
    
    -- Create stubs for missing modules
    for _, module_name in ipairs(missing_modules) do
        create_stub_module(module_name)
    end
end

-- Load class-specific modules
local function load_class_modules()
    -- Check for available class modules
    local class_modules = {
        "classes/warrior/index"
        -- Add other classes as they're implemented
    }
    
    -- Load available class modules
    for _, module_path in ipairs(class_modules) do
        local success, class_module = pcall(require, module_path)
        if success and class_module then
            local active_spec = class_module()
            if active_spec then
                TE.active_class = active_spec
                core.log("Loaded class module: " .. module_path)
            else
                core.log("Class module loaded but no active specialization found: " .. module_path)
            end
        else
            core.log("Failed to load class module: " .. module_path)
        end
    end
end

-- Load modules
load_core_modules()
load_engine_modules()
load_class_modules()

-- Main update function
local function on_update()
    -- Check if plugin is enabled
    if not TE.settings.is_enabled() then
        return
    end
    
    -- Get player object
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then
        return
    end
    
    -- Basic threat management example
    local target = me:get_target()
    if target and target:is_valid() and not target:is_dead() then
        local threat_status = me:get_threat_situation(target)
        if threat_status and threat_status.status > 0 then
            -- We have some threat on target
            if threat_status.is_tanking then
                -- We are currently tanking
                if me:get_health() / me:get_max_health() < 0.5 then
                    core.log("Consider using defensive cooldowns!")
                end
            else
                -- We're not tanking but have threat
                core.log("Building threat on target: " .. target:get_name())
            end
        end
    end
    
    -- Update loaded modules
    for _, module in pairs(TE.loaded_modules) do
        if module.on_update then
            pcall(module.on_update)
        end
    end
end

-- Menu render function
local function on_render_menu()
    TE.menu.main_tree:render("Tank Engine", function()
        TE.menu.enable_script_check:render("Enable Tank Engine")
        
        if not TE.settings.is_enabled() then 
            return 
        end
        
        -- Render humanizer settings
        local humanizer_tree = core.menu.tree_node()
        humanizer_tree:render("Humanizer", function()
            TE.menu.min_delay:render("Min delay", "Min delay until next run.")
            TE.menu.max_delay:render("Max delay", "Max delay until next run.")
        end)
        
        -- Render module menus
        for _, module in pairs(TE.loaded_modules) do
            if module.on_render_menu then
                pcall(module.on_render_menu)
            end
        end
    end)
end

-- Register callbacks
core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(on_render_menu)












