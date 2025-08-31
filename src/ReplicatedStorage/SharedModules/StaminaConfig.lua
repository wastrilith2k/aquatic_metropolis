--[[
StaminaConfig.lua

Purpose: Stamina system configuration for Week 4 energy management
Dependencies: None (pure configuration data)
Last Modified: Phase 0 - Week 4
Performance Notes: Static configuration for efficient stamina calculations

Configuration includes:
- Activity stamina costs and recovery rates
- Player progression bonuses and efficiency thresholds
- Status effects and their gameplay impacts
- Rest mechanics and regeneration parameters
]]--

local StaminaConfig = {}

-- Base stamina system parameters
StaminaConfig.Base = {
    -- Starting values for new players
    maxStamina = 100,
    startingStamina = 100,
    
    -- Core regeneration rates
    baseRegenRate = 8,      -- Stamina per second when idle
    restingRegenRate = 15,  -- Enhanced regen when actively resting
    regenDelay = 2,         -- Seconds after activity before regen starts
    
    -- Critical thresholds
    lowStaminaWarning = 20, -- Warn player when stamina drops below 20
    exhaustionThreshold = 10, -- Special restrictions below 10 stamina
    emergencyReserve = 5    -- Always keep 5 stamina for emergency actions
}

-- Activity-specific stamina costs
StaminaConfig.ActivityCosts = {
    -- Resource gathering
    harvest_kelp = 10,
    harvest_rock = 15,      -- Rocks require more energy
    harvest_pearl = 12,
    
    -- Tool usage modifiers
    tool_bonus_kelp = 0.8,  -- Using right tool reduces cost
    tool_bonus_rock = 0.7,
    tool_bonus_pearl = 0.9,
    
    -- Crafting activities
    craft_simple = 8,       -- Basic recipes
    craft_complex = 15,     -- Advanced recipes
    craft_batch = 5,        -- Per additional item in batch
    
    -- Building activities  
    build_place = 20,       -- Placing structures
    build_remove = 10,      -- Removing structures
    build_upgrade = 25,     -- Upgrading buildings
    
    -- Movement and exploration
    walk = 0,               -- Normal walking costs no stamina
    run = 4,                -- Per second while running
    swim_fast = 5,          -- Per second while swimming quickly
    climb = 8,              -- Per climbing action
    deep_dive = 12,         -- Accessing deep areas
    
    -- Social and interaction
    trade = 5,              -- Player-to-player trading
    chat = 0,               -- Communication is free
    emote = 2,              -- Expressive actions cost a little
    
    -- Emergency actions (always possible)
    emergency_surface = 0,  -- Getting to safety is free
    emergency_heal = 0      -- Basic healing doesn't require stamina
}

-- Efficiency thresholds and their effects
StaminaConfig.Efficiency = {
    -- Stamina percentage thresholds
    thresholds = {
        {min = 0.8, max = 1.0, level = "energized", multiplier = 1.20},
        {min = 0.6, max = 0.8, level = "good", multiplier = 1.00},
        {min = 0.4, max = 0.6, level = "tired", multiplier = 0.85},
        {min = 0.2, max = 0.4, level = "exhausted", multiplier = 0.65},
        {min = 0.0, max = 0.2, level = "depleted", multiplier = 0.40}
    },
    
    -- What efficiency affects
    effects = {
        harvest_speed = true,     -- How fast resources are gathered
        craft_success = true,     -- Chance of successful crafting
        tool_effectiveness = true, -- How well tools perform
        movement_speed = true,    -- Player movement rate
        resource_yield = false    -- Amount of resources (unchanged)
    }
}

-- Status effects and their gameplay impacts
StaminaConfig.StatusEffects = {
    energized = {
        displayName = "Energized",
        description = "Feeling great! All actions are more efficient.",
        color = Color3.fromRGB(100, 255, 100),
        icon = "⚡",
        
        effects = {
            harvestSpeedBonus = 0.2,  -- 20% faster
            craftSpeedBonus = 0.15,   -- 15% faster
            bonusResourceChance = 0.05 -- 5% chance for bonus
        },
        
        restrictions = {} -- No restrictions when energized
    },
    
    good = {
        displayName = "Good",
        description = "Normal energy levels. All systems functioning optimally.",
        color = Color3.fromRGB(150, 255, 150),
        icon = "👍",
        
        effects = {},           -- No bonuses or penalties
        restrictions = {}       -- No restrictions
    },
    
    tired = {
        displayName = "Tired", 
        description = "Getting tired. Actions take more effort.",
        color = Color3.fromRGB(255, 255, 100),
        icon = "😴",
        
        effects = {
            harvestSpeedPenalty = 0.15,  -- 15% slower
            craftFailChance = 0.05       -- 5% chance to fail
        },
        
        restrictions = {
            no_running = false,      -- Can still run, but costs more
            reduced_efficiency = true
        }
    },
    
    exhausted = {
        displayName = "Exhausted",
        description = "Very tired! Need to rest before intense activities.",
        color = Color3.fromRGB(255, 150, 100),
        icon = "💤",
        
        effects = {
            harvestSpeedPenalty = 0.35,  -- 35% slower
            craftFailChance = 0.15,      -- 15% chance to fail
            staminaCostIncrease = 0.25   -- 25% more stamina per action
        },
        
        restrictions = {
            no_running = true,           -- Cannot run
            no_deep_diving = true,       -- Cannot access deep areas
            limited_crafting = true      -- Can only do simple crafts
        }
    },
    
    depleted = {
        displayName = "Depleted",
        description = "Critically low energy. Must rest immediately!",
        color = Color3.fromRGB(255, 100, 100),
        icon = "🔋",
        
        effects = {
            harvestSpeedPenalty = 0.60,  -- 60% slower
            craftFailChance = 0.30,      -- 30% chance to fail
            staminaCostIncrease = 0.50   -- 50% more stamina per action
        },
        
        restrictions = {
            no_running = true,
            no_deep_diving = true,
            no_building = true,          -- Cannot place buildings
            emergency_only = true        -- Only emergency actions allowed
        }
    }
}

-- Rest mechanics and recovery bonuses
StaminaConfig.Rest = {
    -- Requirements to start resting
    requirements = {
        minTimeSinceActivity = 3,    -- Seconds after last action
        maxMovementSpeed = 2,        -- Studs per second max movement
        noActiveTools = false,       -- Can rest with tools equipped
        safeLocation = false         -- Don't require safe areas (yet)
    },
    
    -- Rest effectiveness
    effectiveness = {
        minRestDuration = 5,         -- Seconds for rest bonus
        maxRestBonus = 20,           -- Maximum bonus stamina from resting
        restBonusRate = 2,           -- Bonus stamina per second of quality rest
        interruptionPenalty = 0.5    -- Multiplier if rest is interrupted
    },
    
    -- Environmental rest bonuses (future expansion)
    environmentalBonuses = {
        surface = 1.2,               -- 20% better regen at surface
        shelter = 1.15,              -- 15% better regen in built shelters
        kelp_bed = 1.1,              -- 10% better regen in kelp forests
        deep_water = 0.9             -- 10% worse regen in deep water
    }
}

-- Player progression and stamina improvements
StaminaConfig.Progression = {
    -- Bonuses per player level
    levelBonuses = {
        maxStaminaIncrease = 5,      -- +5 max stamina per level
        regenRateImprovement = 0.3,  -- +0.3 regen per second per level
        efficiencyBonus = 0.01,      -- +1% efficiency per level
        costReduction = 0.01         -- -1% stamina costs per level
    },
    
    -- Activity mastery system
    masteryBonuses = {
        harvest = {
            threshold = 100,         -- Actions needed for mastery
            bonus = 0.2             -- 20% stamina cost reduction
        },
        
        craft = {
            threshold = 50,
            bonus = 0.15
        },
        
        build = {
            threshold = 25,
            bonus = 0.25
        }
    },
    
    -- Stamina-related achievements
    achievements = {
        "Energetic" = {
            description = "Maintain high stamina for 30 minutes",
            reward = {maxStaminaBonus = 10}
        },
        
        "Restful" = {
            description = "Successfully rest 50 times",
            reward = {regenRateBonus = 2}
        },
        
        "Efficient" = {
            description = "Perform 100 actions while energized", 
            reward = {efficiencyBonus = 0.05}
        }
    }
}

-- Special stamina events and modifiers
StaminaConfig.Events = {
    -- Temporary modifiers that can be applied
    modifiers = {
        food_boost = {
            duration = 300,          -- 5 minutes
            regenMultiplier = 1.5,   -- 50% better regen
            costReduction = 0.2      -- 20% less stamina costs
        },
        
        tool_mastery = {
            duration = 180,          -- 3 minutes
            specificActivity = true, -- Only affects one activity type
            costReduction = 0.3      -- 30% reduction for mastered activity
        },
        
        environmental_hazard = {
            duration = 60,           -- 1 minute
            regenMultiplier = 0.5,   -- 50% worse regen
            costIncrease = 0.4       -- 40% more stamina costs
        }
    },
    
    -- Random events that can affect stamina
    randomEvents = {
        energy_surge = {
            chance = 0.02,           -- 2% chance per minute
            effect = {instantRestore = 25, bonusDuration = 60}
        },
        
        fatigue_wave = {
            chance = 0.01,           -- 1% chance per minute
            effect = {instantDrain = 15, penaltyDuration = 120}
        }
    }
}

-- Debug and balancing configuration
StaminaConfig.Debug = {
    -- Testing overrides
    enableInstantRegen = false,      -- For testing UI
    disableStaminaCosts = false,     -- For debugging other systems
    showDetailedStats = false,       -- Extra client information
    logActivityCosts = false,        -- Server-side activity logging
    
    -- Balancing parameters
    globalCostMultiplier = 1.0,      -- Scale all costs by this factor
    globalRegenMultiplier = 1.0,     -- Scale all regen by this factor
    
    -- Performance monitoring
    maxUpdatesPerSecond = 10,        -- Client update frequency limit
    batchUpdateThreshold = 5         -- Group small changes together
}

-- Utility functions for stamina calculations
local StaminaConfigModule = {}

function StaminaConfigModule:GetActivityCost(activity, hasCorrectTool, playerLevel)
    local baseCost = StaminaConfig.ActivityCosts[activity] or 10
    
    -- Apply tool bonus
    if hasCorrectTool then
        local toolBonus = StaminaConfig.ActivityCosts["tool_bonus_" .. activity] or 1.0
        baseCost = baseCost * toolBonus
    end
    
    -- Apply level reduction
    if playerLevel and playerLevel > 1 then
        local reduction = (playerLevel - 1) * StaminaConfig.Progression.levelBonuses.costReduction
        baseCost = baseCost * (1 - math.min(reduction, 0.5)) -- Max 50% reduction
    end
    
    -- Apply global multiplier
    baseCost = baseCost * StaminaConfig.Debug.globalCostMultiplier
    
    return math.max(1, math.floor(baseCost))
end

function StaminaConfigModule:GetEfficiencyInfo(staminaPercent)
    for _, threshold in ipairs(StaminaConfig.Efficiency.thresholds) do
        if staminaPercent >= threshold.min and staminaPercent < threshold.max then
            return {
                level = threshold.level,
                multiplier = threshold.multiplier,
                effects = StaminaConfig.Efficiency.effects
            }
        end
    end
    
    return {level = "unknown", multiplier = 1.0, effects = {}}
end

function StaminaConfigModule:GetStatusEffect(staminaPercent)
    local efficiencyInfo = self:GetEfficiencyInfo(staminaPercent)
    return StaminaConfig.StatusEffects[efficiencyInfo.level] or StaminaConfig.StatusEffects.good
end

function StaminaConfigModule:CanPerformActivity(activity, staminaPercent, currentStamina)
    local cost = self:GetActivityCost(activity)
    
    -- Check stamina availability
    if currentStamina < cost then
        return false, "Insufficient stamina"
    end
    
    -- Check status effect restrictions
    local statusEffect = self:GetStatusEffect(staminaPercent)
    local restrictions = statusEffect.restrictions
    
    if restrictions.emergency_only and not string.find(activity, "emergency") then
        return false, "Too exhausted - emergency actions only"
    end
    
    if restrictions.no_running and (activity == "run" or activity == "swim_fast") then
        return false, "Too tired for intense movement"
    end
    
    if restrictions.no_deep_diving and activity == "deep_dive" then
        return false, "Too exhausted for deep water exploration"
    end
    
    if restrictions.no_building and string.find(activity, "build") then
        return false, "Too tired for construction work"
    end
    
    if restrictions.limited_crafting and activity == "craft_complex" then
        return false, "Too tired for complex crafting"
    end
    
    return true, "Can perform activity"
end

function StaminaConfigModule:GetRegenRate(staminaPercent, isResting, playerLevel, environmentModifier)
    local baseRate = StaminaConfig.Base.baseRegenRate
    
    -- Resting bonus
    if isResting then
        baseRate = StaminaConfig.Base.restingRegenRate
    end
    
    -- Player level bonus
    if playerLevel and playerLevel > 1 then
        local levelBonus = (playerLevel - 1) * StaminaConfig.Progression.levelBonuses.regenRateImprovement
        baseRate = baseRate + levelBonus
    end
    
    -- Environmental modifier
    if environmentModifier then
        baseRate = baseRate * environmentModifier
    end
    
    -- Global multiplier
    baseRate = baseRate * StaminaConfig.Debug.globalRegenMultiplier
    
    return baseRate
end

-- Export the configuration and utility functions
StaminaConfigModule.Config = StaminaConfig
return StaminaConfigModule