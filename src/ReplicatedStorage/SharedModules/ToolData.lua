--[[
ToolData.lua

Purpose: Tool definitions and upgrade paths for Week 4 tool system
Dependencies: None (pure configuration data)
Last Modified: Phase 0 - Week 4
Performance Notes: Static data for efficient tool system operations

Tool Properties:
- baseStats: Core tool effectiveness values
- durabilityInfo: Durability calculations and wear patterns
- upgradeRequirements: Materials needed for enhancements
- visualProperties: Appearance and UI display information
]]--

local ToolData = {}

-- Tool categories and their characteristics
ToolData.Categories = {
    Harvesting = {
        description = "Tools for gathering resources from the underwater environment",
        color = Color3.fromRGB(100, 200, 100),
        icon = "🌿"
    },
    
    Construction = {
        description = "Tools for building and construction activities", 
        color = Color3.fromRGB(200, 150, 100),
        icon = "🔨"
    },
    
    Exploration = {
        description = "Tools for exploring deeper areas and finding rare resources",
        color = Color3.fromRGB(100, 150, 200),
        icon = "🔍"
    }
}

-- Detailed tool specifications
ToolData.Tools = {
    KelpTool = {
        -- Basic information
        displayName = "Kelp Harvester",
        description = "Woven tool optimized for efficient kelp gathering",
        category = "Harvesting",
        
        -- Base statistics
        baseStats = {
            durability = 50,
            harvestSpeed = 1.5,        -- Multiplier for harvest time
            bonusChance = 0.10,        -- 10% chance for bonus resources
            resourceSpecialty = "Kelp", -- Primary resource type
            efficiency = 1.0           -- Base tool efficiency
        },
        
        -- Durability characteristics
        durabilityInfo = {
            wearRate = 0.8,           -- Lower = more durable
            repairDifficulty = 1.0,   -- Standard repair requirements
            breakWarningThreshold = 10, -- Warn when durability drops to 10
            criticalThreshold = 5     -- Critical condition at 5 durability
        },
        
        -- Quality bonuses per tier
        qualityBonuses = {
            Basic = {durabilityMultiplier = 1.0, efficiencyBonus = 0.0},
            Good = {durabilityMultiplier = 1.2, efficiencyBonus = 0.15},
            Excellent = {durabilityMultiplier = 1.5, efficiencyBonus = 0.35},
            Perfect = {durabilityMultiplier = 2.0, efficiencyBonus = 0.60}
        },
        
        -- Enhancement requirements
        enhancementRequirements = {
            [1] = {materials = {Kelp = 5, Rock = 2}, bonus = "10% faster kelp harvesting"},
            [2] = {materials = {Kelp = 8, Rock = 4, Pearl = 1}, bonus = "Chance for rare kelp varieties"},
            [3] = {materials = {Kelp = 12, Rock = 6, Pearl = 2}, bonus = "15% bonus resource chance"},
            [4] = {materials = {Kelp = 20, Rock = 10, Pearl = 3}, bonus = "Harvest multiple kelp at once"},
            [5] = {materials = {Kelp = 30, Rock = 15, Pearl = 5}, bonus = "Perfect kelp harvesting mastery"}
        },
        
        -- Visual and UI properties
        visualProperties = {
            model = "cylinder", -- Basic shape for now
            baseColor = Color3.fromRGB(50, 150, 50),
            size = Vector3.new(0.8, 3, 0.8),
            material = Enum.Material.Grass,
            
            -- Condition-based appearance
            conditionColors = {
                Excellent = Color3.fromRGB(0, 255, 0),
                Good = Color3.fromRGB(150, 255, 0), 
                Worn = Color3.fromRGB(255, 255, 0),
                Damaged = Color3.fromRGB(255, 150, 0),
                Broken = Color3.fromRGB(255, 0, 0)
            }
        },
        
        -- Repair information
        repairInfo = {
            baseMaterials = {Kelp = 2},
            repairEfficiency = 0.9,    -- 90% durability restoration per repair
            maxRepairs = 10           -- Tool becomes unrepairable after 10 repairs
        }
    },
    
    RockHammer = {
        displayName = "Stone Hammer",
        description = "Sturdy hammer for breaking rocks and hard materials",
        category = "Harvesting",
        
        baseStats = {
            durability = 40,
            harvestSpeed = 1.3,
            bonusChance = 0.15,
            resourceSpecialty = "Rock",
            efficiency = 1.0
        },
        
        durabilityInfo = {
            wearRate = 1.2,           -- Rocks are harder on tools
            repairDifficulty = 1.1,
            breakWarningThreshold = 8,
            criticalThreshold = 4
        },
        
        qualityBonuses = {
            Basic = {durabilityMultiplier = 1.0, efficiencyBonus = 0.0},
            Good = {durabilityMultiplier = 1.3, efficiencyBonus = 0.20},
            Excellent = {durabilityMultiplier = 1.7, efficiencyBonus = 0.40},
            Perfect = {durabilityMultiplier = 2.2, efficiencyBonus = 0.70}
        },
        
        enhancementRequirements = {
            [1] = {materials = {Rock = 3, Kelp = 2}, bonus = "15% faster rock breaking"},
            [2] = {materials = {Rock = 6, Kelp = 3, Pearl = 1}, bonus = "Chance for crystal shards"},
            [3] = {materials = {Rock = 10, Kelp = 5, Pearl = 2}, bonus = "20% bonus resource chance"},
            [4] = {materials = {Rock = 16, Kelp = 8, Pearl = 4}, bonus = "Break multiple rocks efficiently"},
            [5] = {materials = {Rock = 25, Kelp = 12, Pearl = 6}, bonus = "Master stone breaking techniques"}
        },
        
        visualProperties = {
            model = "block",
            baseColor = Color3.fromRGB(120, 120, 120),
            size = Vector3.new(1.5, 1.2, 0.8),
            material = Enum.Material.Rock,
            
            conditionColors = {
                Excellent = Color3.fromRGB(180, 180, 180),
                Good = Color3.fromRGB(150, 150, 150),
                Worn = Color3.fromRGB(120, 120, 120),
                Damaged = Color3.fromRGB(90, 90, 90),
                Broken = Color3.fromRGB(60, 60, 60)
            }
        },
        
        repairInfo = {
            baseMaterials = {Rock = 1, Kelp = 1},
            repairEfficiency = 0.85,
            maxRepairs = 8
        }
    },
    
    PearlNet = {
        displayName = "Pearl Diving Net",
        description = "Specialized net for finding pearls in the deep waters",
        category = "Exploration",
        
        baseStats = {
            durability = 30,
            harvestSpeed = 1.0,        -- Same speed but much better success rate
            bonusChance = 0.25,
            resourceSpecialty = "Pearl",
            efficiency = 2.0          -- Doubles pearl finding success rate
        },
        
        durabilityInfo = {
            wearRate = 1.5,           -- Nets are delicate
            repairDifficulty = 0.8,   -- Easier to repair
            breakWarningThreshold = 6,
            criticalThreshold = 3
        },
        
        qualityBonuses = {
            Basic = {durabilityMultiplier = 1.0, efficiencyBonus = 0.0},
            Good = {durabilityMultiplier = 1.4, efficiencyBonus = 0.25},
            Excellent = {durabilityMultiplier = 1.8, efficiencyBonus = 0.50},
            Perfect = {durabilityMultiplier = 2.5, efficiencyBonus = 1.0}
        },
        
        enhancementRequirements = {
            [1] = {materials = {Kelp = 4, Pearl = 1}, bonus = "25% better pearl detection"},
            [2] = {materials = {Kelp = 7, Pearl = 2, Rock = 2}, bonus = "Chance for multiple pearls"},
            [3] = {materials = {Kelp = 12, Pearl = 4, Rock = 4}, bonus = "Rare pearl varieties"},
            [4] = {materials = {Kelp = 18, Pearl = 6, Rock = 6}, bonus = "Deep water pearl access"},
            [5] = {materials = {Kelp = 28, Pearl = 10, Rock = 10}, bonus = "Legendary pearl mastery"}
        },
        
        visualProperties = {
            model = "ball", -- Net represented as sphere
            baseColor = Color3.fromRGB(200, 200, 255),
            size = Vector3.new(1.2, 1.2, 1.2),
            material = Enum.Material.Neon,
            
            conditionColors = {
                Excellent = Color3.fromRGB(255, 255, 255),
                Good = Color3.fromRGB(230, 230, 255),
                Worn = Color3.fromRGB(200, 200, 255),
                Damaged = Color3.fromRGB(170, 170, 200),
                Broken = Color3.fromRGB(120, 120, 150)
            }
        },
        
        repairInfo = {
            baseMaterials = {Kelp = 3},
            repairEfficiency = 0.95,  -- Nets repair well
            maxRepairs = 12
        }
    }
}

-- Tool effectiveness matrices (how well each tool works on each resource)
ToolData.EffectivenessMatrix = {
    -- [ToolType][ResourceType] = {speedMultiplier, successMultiplier, bonusChance}
    KelpTool = {
        Kelp = {speed = 1.5, success = 1.2, bonus = 0.1},
        Rock = {speed = 0.7, success = 0.8, bonus = 0.0},
        Pearl = {speed = 0.6, success = 0.6, bonus = 0.0}
    },
    
    RockHammer = {
        Kelp = {speed = 0.8, success = 0.9, bonus = 0.0},
        Rock = {speed = 1.4, success = 1.4, bonus = 0.15},
        Pearl = {speed = 0.5, success = 0.7, bonus = 0.0}
    },
    
    PearlNet = {
        Kelp = {speed = 0.6, success = 0.8, bonus = 0.0},
        Rock = {speed = 0.4, success = 0.5, bonus = 0.0},
        Pearl = {speed = 1.0, success = 2.0, bonus = 0.25}
    }
}

-- Tool upgrade paths and progression
ToolData.UpgradeTree = {
    -- Basic progression path
    Beginner = {
        recommended = {"KelpTool"},
        description = "Start with kelp harvesting for basic materials"
    },
    
    -- Intermediate tools
    Intermediate = {
        recommended = {"KelpTool", "RockHammer"},
        description = "Expand to rock breaking for construction materials"
    },
    
    -- Advanced tool setup
    Advanced = {
        recommended = {"KelpTool", "RockHammer", "PearlNet"},
        description = "Complete tool set for all resource types"
    },
    
    -- Specialized builds
    Specialist = {
        KelpMaster = {
            focus = "KelpTool",
            bonuses = "Enhanced kelp harvesting with rare material chances"
        },
        
        StoneCrusher = {
            focus = "RockHammer", 
            bonuses = "Superior rock breaking with crystal discoveries"
        },
        
        PearlDiver = {
            focus = "PearlNet",
            bonuses = "Master pearl hunting in dangerous deep waters"
        }
    }
}

-- Utility functions for tool data access
local ToolDataModule = {}

function ToolDataModule:GetToolData(toolType)
    return ToolData.Tools[toolType]
end

function ToolDataModule:GetAllTools()
    return ToolData.Tools
end

function ToolDataModule:GetToolsByCategory(category)
    local tools = {}
    for toolType, toolData in pairs(ToolData.Tools) do
        if toolData.category == category then
            tools[toolType] = toolData
        end
    end
    return tools
end

function ToolDataModule:GetToolEffectiveness(toolType, resourceType)
    local matrix = ToolData.EffectivenessMatrix[toolType]
    if matrix then
        return matrix[resourceType] or {speed = 0.5, success = 0.5, bonus = 0.0}
    end
    return {speed = 0.5, success = 0.5, bonus = 0.0}
end

function ToolDataModule:GetUpgradeRequirements(toolType, level)
    local toolData = ToolData.Tools[toolType]
    if toolData and toolData.enhancementRequirements then
        return toolData.enhancementRequirements[level]
    end
    return nil
end

function ToolDataModule:GetRepairCost(toolType, condition)
    local toolData = ToolData.Tools[toolType]
    if not toolData then return {} end
    
    local baseMaterials = toolData.repairInfo.baseMaterials
    local repairCost = {}
    
    -- Scale repair cost based on condition
    local conditionMultipliers = {
        Excellent = 0.2, -- Very cheap to maintain
        Good = 0.4,
        Worn = 0.6, 
        Damaged = 0.8,
        Broken = 1.0     -- Full repair cost when broken
    }
    
    local multiplier = conditionMultipliers[condition] or 1.0
    
    for material, amount in pairs(baseMaterials) do
        repairCost[material] = math.max(1, math.floor(amount * multiplier))
    end
    
    return repairCost
end

function ToolDataModule:CalculateToolStats(toolType, quality, enhancementLevel, currentDurability, maxDurability)
    local toolData = ToolData.Tools[toolType]
    if not toolData then return {} end
    
    local baseStats = toolData.baseStats
    local qualityBonus = toolData.qualityBonuses[quality] or toolData.qualityBonuses.Basic
    
    -- Calculate quality-modified stats
    local stats = {
        durability = math.floor(baseStats.durability * qualityBonus.durabilityMultiplier),
        harvestSpeed = baseStats.harvestSpeed * (1 + qualityBonus.efficiencyBonus),
        bonusChance = baseStats.bonusChance * (1 + qualityBonus.efficiencyBonus),
        efficiency = baseStats.efficiency
    }
    
    -- Apply enhancement bonuses
    local enhancementBonus = 1 + (enhancementLevel * 0.1) -- 10% per level
    stats.harvestSpeed = stats.harvestSpeed * enhancementBonus
    stats.bonusChance = stats.bonusChance * enhancementBonus
    
    -- Apply durability condition penalty
    if currentDurability and maxDurability and maxDurability > 0 then
        local conditionRatio = currentDurability / maxDurability
        local conditionMultiplier = math.max(0.3, conditionRatio) -- Minimum 30% effectiveness
        
        stats.harvestSpeed = stats.harvestSpeed * conditionMultiplier
        stats.efficiency = stats.efficiency * conditionMultiplier
    end
    
    return stats
end

-- Export both the data and the module
ToolDataModule.Data = ToolData
return ToolDataModule