-- Warrior Class Module
-- Provides warrior-specific functionality for Tank Engine

-- Create warrior namespace if it doesn't exist
if not TE.classes then TE.classes = {} end
if not TE.classes.warrior then TE.classes.warrior = {} end

-- Load specialization modules
require("classes/warrior/protection_warrior")

-- Common warrior utility functions
TE.classes.warrior.common = {
    -- Resource type for warriors
    get_resource_type = function()
        return 1 -- Rage
    end,
    
    -- Common warrior abilities
    abilities = {
        -- Defensive
        shield_wall = 871,
        last_stand = 12975,
        rallying_cry = 97462,
        
        -- Offensive
        avatar = 107574,
        battle_shout = 6673,
        
        -- Utility
        charge = 100,
        heroic_leap = 6544,
        intervene = 3411,
        
        -- Interrupts
        pummel = 6552,
        intimidating_shout = 5246,
    }
}

-- Return the appropriate specialization module based on current spec
return function()
    local spec_id = TE.variables.get_specialization()
    
    if spec_id == 73 then -- Protection
        return TE.classes.warrior.protection
    elseif spec_id == 71 then -- Arms
        -- Not implemented yet
        return nil
    elseif spec_id == 72 then -- Fury
        -- Not implemented yet
        return nil
    else
        return nil
    end
end
