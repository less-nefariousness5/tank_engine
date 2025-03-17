-- Core Index File
-- This file loads all core components of the Tank Engine

-- Load core modules in proper order
require("core/api")
require("core/humanizer")
require("core/menu")
require("core/settings")
require("core/variables")
require("core/state")

-- Initialize core components
function TE.initialize_core()
    -- Initialize state management
    TE.state.initialize()
    
    -- Initialize settings with persistence
    TE.settings.initialize()
    
    -- Add settings menu options
    TE.settings.add_settings_menu_options()
    
    core.log("Core components initialized")
    return true
end
