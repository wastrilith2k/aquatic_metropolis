--[[
CraftingData.lua

Purpose: MVP crafting recipes and tool definitions
Dependencies: ResourceData (for validation)
Last Modified: Phase 0 - Week 1
Performance Notes: Static recipe data, efficient lookup

Recipe Properties:
- displayName: User-friendly name
- ingredients: Table of {ResourceType = Amount}
- craftTime: Seconds to craft (for UI feedback)
- durability: Uses before breaking (tools only)
- effect: Gameplay effects (speed multipliers, bonuses)
- description: Tooltip for players
- category: "tools" or "building" for UI organization
- buildable: Boolean, can be placed in world
]]--

local CraftingData = {
    -- Tools (Progression enablers)
    KelpTool = {
        displayName = "Kelp Harvester",
        ingredients = {Kelp = 3},
        craftTime = 2, -- seconds
        durability = 50, -- uses before breaking
        effect = {harvestSpeed = 1.5}, -- 50% faster kelp gathering
        description = "Woven kelp tool for faster harvesting. Breaks after 50 uses.",
        category = "tools",
        buildable = false
    },
    
    RockHammer = {
        displayName = "Stone Hammer", 
        ingredients = {Rock = 2},
        craftTime = 3,
        durability = 40,
        effect = {harvestSpeed = 1.3, rockBonus = true}, -- Better rock harvesting
        description = "Simple hammer for efficient rock breaking. Breaks after 40 uses.",
        category = "tools",
        buildable = false
    },
    
    PearlNet = {
        displayName = "Pearl Diving Net",
        ingredients = {Kelp = 2, Rock = 1},
        craftTime = 4,
        durability = 30,
        effect = {pearlChance = 2.0}, -- Double pearl find rate
        description = "Specialized net for deep pearl diving. Breaks after 30 uses.",
        category = "tools",
        buildable = false
    },
    
    -- Buildables (Expression enablers)
    BasicWall = {
        displayName = "Stone Wall",
        ingredients = {Rock = 3},
        craftTime = 2,
        durability = nil, -- Buildings don't break
        effect = {structural = true},
        buildable = true,
        size = Vector3.new(4, 4, 1),
        description = "Sturdy wall for underwater construction",
        category = "building",
        
        -- Building properties
        visual = {
            shape = "Block",
            color = Color3.fromRGB(120, 120, 120),
            material = Enum.Material.Concrete
        }
    },
    
    KelpCarpet = {
        displayName = "Kelp Floor Mat",
        ingredients = {Kelp = 5},
        craftTime = 3,
        durability = nil,
        effect = {comfort = true},
        buildable = true,
        size = Vector3.new(4, 0.2, 4),
        description = "Soft flooring woven from kelp",
        category = "building",
        
        visual = {
            shape = "Block", 
            color = Color3.fromRGB(60, 120, 60),
            material = Enum.Material.Fabric
        }
    }
}

-- Utility functions
local CraftingDataModule = {}

function CraftingDataModule:GetRecipe(recipeId)
    return CraftingData[recipeId]
end

function CraftingDataModule:GetAllRecipes()
    return CraftingData
end

function CraftingDataModule:GetRecipesByCategory(category)
    local filtered = {}
    for recipeId, recipe in pairs(CraftingData) do
        if recipe.category == category then
            filtered[recipeId] = recipe
        end
    end
    return filtered
end

function CraftingDataModule:GetBuildableRecipes()
    local buildable = {}
    for recipeId, recipe in pairs(CraftingData) do
        if recipe.buildable then
            buildable[recipeId] = recipe
        end
    end
    return buildable
end

function CraftingDataModule:GetToolRecipes()
    return self:GetRecipesByCategory("tools")
end

function CraftingDataModule:ValidateIngredients(recipeId, playerInventory)
    local recipe = CraftingData[recipeId]
    if not recipe then return false, "Recipe not found" end
    
    local missing = {}
    for ingredient, required in pairs(recipe.ingredients) do
        local playerAmount = playerInventory[ingredient] or 0
        if playerAmount < required then
            table.insert(missing, {
                resource = ingredient,
                have = playerAmount,
                need = required
            })
        end
    end
    
    if #missing > 0 then
        return false, missing
    end
    
    return true
end

function CraftingDataModule:GetRecipeCount()
    local count = 0
    for _ in pairs(CraftingData) do
        count = count + 1
    end
    return count
end

-- Return both data and module
CraftingDataModule.Data = CraftingData
return CraftingDataModule