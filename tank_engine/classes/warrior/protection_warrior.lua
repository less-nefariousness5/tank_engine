-- Protection Warrior Module
-- Implements tank engine functionality for Protection Warriors

---@type spell_helper
local spell_helper = require("common/utility/spell_helper")

-- Create protection warrior namespace if it doesn't exist
if not TE.classes.warrior.protection then
    TE.classes.warrior.protection = {
        -- Specialization-specific abilities
        abilities = {
            -- Active mitigation
            shield_block = 2565,
            ignore_pain = 190456,
            spell_reflection = 23920,
            
            -- Offensive
            shield_slam = 23922,
            thunder_clap = 6343,
            revenge = 6572,
            devastate = 20243,
            
            -- Talents/Covenant
            demoralizing_shout = 1160,
            shockwave = 46968,
            dragon_roar = 118000,
            ravager = 228920,
        },
        
        -- Menu elements
        menu = {
            main_tree = TE.menu.tree_node(),
            use_shield_block = TE.menu.checkbox(true, "prot_use_shield_block"),
            use_ignore_pain = TE.menu.checkbox(true, "prot_use_ignore_pain"),
            use_spell_reflection = TE.menu.checkbox(true, "prot_use_spell_reflection"),
            min_rage_threshold = TE.menu.slider_float(0, 100, 30, "prot_min_rage"),
            shield_block_threshold = TE.menu.slider_float(0, 100, 70, "prot_shield_block_threshold"),
            ignore_pain_threshold = TE.menu.slider_float(0, 100, 60, "prot_ignore_pain_threshold"),
        }
    }
end

-- Load module files (to be implemented later)
-- require("classes/warrior/protection_warrior/menu")
-- require("classes/warrior/protection_warrior/rotation")

-- Implement required Tank Engine interfaces
-- Get class resource type (overrides common implementation)
function TE.classes.warrior.protection.get_resource_type()
    return 1 -- Rage
end
-- Get mitigation abilities for mitigation engine
function TE.classes.warrior.protection.get_mitigation_abilities()
    return {
        {
            name = "Shield Block",
            spell_id = TE.classes.warrior.protection.abilities.shield_block,
            cooldown = 16,
            duration = 6,
            charges = 2,
            resource_cost = 30,
            damage_type = "physical",
            priority = 80,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.protection.abilities.shield_block) and 
                       spell_helper:is_spell_queueable(TE.classes.warrior.protection.abilities.shield_block, TE.variables.me, TE.variables.me, true, true)
            end
        },
        {
            name = "Ignore Pain",
            spell_id = TE.classes.warrior.protection.abilities.ignore_pain,
            cooldown = 0,
            duration = 12,
            resource_cost = 40,
            damage_type = "all",
            priority = 60,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.protection.abilities.ignore_pain) and 
                       spell_helper:is_spell_queueable(TE.classes.warrior.protection.abilities.ignore_pain, TE.variables.me, TE.variables.me, true, true)
            end
        },
        {
            name = "Spell Reflection",
            spell_id = TE.classes.warrior.protection.abilities.spell_reflection,
            cooldown = 25,
            duration = 5,
            damage_type = "magic",
            priority = 70,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.protection.abilities.spell_reflection) and 
                       spell_helper:is_spell_queueable(TE.classes.warrior.protection.abilities.spell_reflection, TE.variables.me, TE.variables.me, true, true)
            end
        }
    }
end
-- Get defensive cooldowns for defensive engine
function TE.classes.warrior.protection.get_defensive_cooldowns()
    return {
        {
            name = "Shield Wall",
            spell_id = TE.classes.warrior.common.abilities.shield_wall,
            cooldown = 240,
            duration = 8,
            damage_reduction = 30,
            damage_type = "all",
            priority = 90,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.common.abilities.shield_wall)
            end
        },
        {
            name = "Last Stand",
            spell_id = TE.classes.warrior.common.abilities.last_stand,
            cooldown = 180,
            duration = 15,
            health_increase = 30,
            damage_type = "all",
            priority = 80,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.common.abilities.last_stand)
            end
        },
        {
            name = "Demoralizing Shout",
            spell_id = TE.classes.warrior.protection.abilities.demoralizing_shout,
            cooldown = 45,
            duration = 8,
            damage_reduction = 20,
            damage_type = "physical",
            priority = 70,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.protection.abilities.demoralizing_shout)
            end
        }
    }
end
-- Get interrupt abilities for interrupt engine
function TE.classes.warrior.protection.get_interrupt_abilities()
    return {
        {
            name = "Pummel",
            spell_id = TE.classes.warrior.common.abilities.pummel,
            cooldown = 15,
            interrupt_duration = 4,
            range = 5,
            priority = 90,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.common.abilities.pummel)
            end
        },
        {
            name = "Shockwave",
            spell_id = TE.classes.warrior.protection.abilities.shockwave,
            cooldown = 40,
            interrupt_duration = 2,
            range = 10,
            is_aoe = true,
            priority = 60,
            is_available = function()
                return spell_helper:has_spell_equipped(TE.classes.warrior.protection.abilities.shockwave)
            end
        }
    }
end

-- Menu render function
function TE.classes.warrior.protection.menu.on_render_menu()
    TE.classes.warrior.protection.menu.main_tree:render("Protection Warrior", function()
        -- Create header
        local header = TE.menu.header()
        header:render("Protection Warrior Settings", require("common/color").new(255, 180, 0, 255))
        
        -- Active mitigation settings
        TE.classes.warrior.protection.menu.use_shield_block:render(
            "Use Shield Block",
            "Automatically use Shield Block for physical damage mitigation"
        )
        
        TE.classes.warrior.protection.menu.use_ignore_pain:render(
            "Use Ignore Pain",
            "Automatically use Ignore Pain for general damage absorption"
        )
        
        TE.classes.warrior.protection.menu.use_spell_reflection:render(
            "Use Spell Reflection",
            "Automatically use Spell Reflection for magic damage mitigation"
        )
        
        -- Resource management
        TE.classes.warrior.protection.menu.min_rage_threshold:render(
            "Minimum Rage",
            "Minimum rage to maintain for emergency mitigation"
        )
        
        TE.classes.warrior.protection.menu.shield_block_threshold:render(
            "Shield Block Threshold",
            "Health percentage threshold to use Shield Block"
        )
        
        TE.classes.warrior.protection.menu.ignore_pain_threshold:render(
            "Ignore Pain Threshold",
            "Health percentage threshold to use Ignore Pain"
        )
    end)
end

-- Module interface for core system
TE.classes.warrior.protection = {
    get_resource_type = TE.classes.warrior.protection.get_resource_type,
    get_mitigation_abilities = TE.classes.warrior.protection.get_mitigation_abilities,
    get_defensive_cooldowns = TE.classes.warrior.protection.get_defensive_cooldowns,
    get_interrupt_abilities = TE.classes.warrior.protection.get_interrupt_abilities,
    menu = {
        on_render_menu = TE.classes.warrior.protection.menu.on_render_menu
    }
}

return TE.classes.warrior.protection













































































































