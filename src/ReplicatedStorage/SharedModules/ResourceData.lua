--[[
ResourceData.lua

Purpose: Core MVP resource definitions and spawn rules
Dependencies: None (standalone data module)
Last Modified: Phase 0 - Week 1
Performance Notes: Static data tables, minimal memory usage

Resource Properties:
- displayName: User-friendly name
- spawnChance: Probability of spawning (0-1)
- respawnTime: Seconds until respawn after harvest
- harvestValue: Amount gained per harvest
- harvestSound: Roblox sound ID for feedback
- description: Tooltip text for players
- requiresTool: Tool needed to harvest (nil if none)
]]--

local ResourceData = {
    Kelp = {
        displayName = "Glowing Kelp",
        spawnChance = 0.3, -- 30% of valid positions
        respawnTime = 60, -- 1 minute
        harvestValue = 1,
        harvestSound = "rbxassetid://131961136", -- Default Roblox pop sound
        description = "Bioluminescent seaweed, essential for basic tools and crafting",
        requiresTool = nil, -- Can be gathered by hand
        
        -- Visual properties for procedural models
        visual = {
            shape = "Cylinder",
            size = Vector3.new(0.5, 6, 0.5),
            color = Color3.fromRGB(50, 150, 50),
            material = Enum.Material.Grass,
            glow = true
        }
    },
    
    Rock = {
        displayName = "Smooth Rock",
        spawnChance = 0.2, -- 20% of valid positions
        respawnTime = 120, -- 2 minutes  
        harvestValue = 2,
        harvestSound = "rbxassetid://131961136",
        description = "Dense stone perfect for construction and tool crafting",
        requiresTool = nil, -- Can be gathered by hand initially
        
        visual = {
            shape = "Block",
            size = Vector3.new(2, 1.5, 2),
            color = Color3.fromRGB(100, 100, 100),
            material = Enum.Material.Rock,
            glow = false
        }
    },
    
    Pearl = {
        displayName = "Deep Pearl",
        spawnChance = 0.1, -- 10% of valid positions (rare)
        respawnTime = 300, -- 5 minutes
        harvestValue = 5,
        harvestSound = "rbxassetid://131961136",
        description = "Precious ocean gem, highly valuable for advanced crafts",
        requiresTool = nil, -- Can be gathered by hand initially
        
        visual = {
            shape = "Ball",
            size = Vector3.new(1, 1, 1),
            color = Color3.fromRGB(255, 255, 240),
            material = Enum.Material.Neon,
            glow = true
        }
    }
}

-- Utility functions
local ResourceDataModule = {}

function ResourceDataModule:GetResourceData(resourceType)
    return ResourceData[resourceType]
end

function ResourceDataModule:GetAllResources()
    return ResourceData
end

function ResourceDataModule:GetSpawnableResources()
    local spawnable = {}
    for resourceType, data in pairs(ResourceData) do
        if data.spawnChance and data.spawnChance > 0 then
            spawnable[resourceType] = data
        end
    end
    return spawnable
end

function ResourceDataModule:GetResourceValue(resourceType)
    local data = ResourceData[resourceType]
    return data and data.harvestValue or 0
end

function ResourceDataModule:RequiresTool(resourceType)
    local data = ResourceData[resourceType]
    return data and data.requiresTool or nil
end

-- Validation functions
function ResourceDataModule:ValidateResourceType(resourceType)
    return ResourceData[resourceType] ~= nil
end

function ResourceDataModule:GetTotalResourceTypes()
    local count = 0
    for _ in pairs(ResourceData) do
        count = count + 1
    end
    return count
end

-- Return both the data and the module
ResourceDataModule.Data = ResourceData
return ResourceDataModule