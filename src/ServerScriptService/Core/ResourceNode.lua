--[[
ResourceNode.lua

Purpose: Enhanced resource node system for Week 3 advanced crafting
Dependencies: ResourceData, CraftingData, ToolData
Last Modified: Phase 0 - Week 3
Performance Notes: Efficient state management, coroutine-based respawn system

Public Methods:
- new(resourceType, position, rarity): Create new resource node
- harvest(player, tool): Attempt to harvest with tool validation
- respawn(): Begin respawn process with appropriate timing
- updateState(): Manage node state transitions
- getInfo(): Return node information for client display
]]--

local ResourceNode = {}
ResourceNode.__index = ResourceNode

-- Import dependencies
local ResourceData = require(game.ReplicatedStorage.SharedModules.ResourceData)
local CraftingData = require(game.ReplicatedStorage.SharedModules.CraftingData)
local RunService = game:GetService("RunService")

-- Node states
local NodeState = {
    AVAILABLE = "Available",
    HARVESTING = "Harvesting", 
    HARVESTED = "Harvested",
    RESPAWNING = "Respawning"
}

-- Rarity definitions with multipliers
local RarityData = {
    Common = {
        probability = 0.8,
        respawnMultiplier = 1.0,
        bonusChance = 0.05,
        harvestDifficulty = 1.0,
        displayColor = Color3.fromRGB(200, 200, 200)
    },
    Uncommon = {
        probability = 0.15,
        respawnMultiplier = 1.5,
        bonusChance = 0.15,
        harvestDifficulty = 1.3,
        displayColor = Color3.fromRGB(100, 255, 100)
    },
    Rare = {
        probability = 0.05,
        respawnMultiplier = 2.5,
        bonusChance = 0.35,
        harvestDifficulty = 2.0,
        displayColor = Color3.fromRGB(255, 100, 255)
    }
}

-- Base respawn times by resource type (seconds)
local BaseRespawnTimes = {
    Kelp = 45,
    Rock = 60,
    Pearl = 90
}

function ResourceNode.new(resourceType, position, rarity, nodeId)
    local self = setmetatable({}, ResourceNode)
    
    -- Core properties
    self.id = nodeId or ("node_" .. tick() .. "_" .. math.random(1000, 9999))
    self.resourceType = resourceType
    self.position = position
    self.rarity = rarity or ResourceNode.determineRarity()
    
    -- State management
    self.currentState = NodeState.AVAILABLE
    self.creationTime = tick()
    self.lastHarvested = 0
    self.lastHarvestedBy = nil
    self.harvestCount = 0
    
    -- Calculated properties
    local rarityInfo = RarityData[self.rarity]
    self.harvestDifficulty = rarityInfo.harvestDifficulty
    self.bonusChance = rarityInfo.bonusChance
    self.respawnTime = (BaseRespawnTimes[resourceType] or 60) * rarityInfo.respawnMultiplier
    
    -- Special properties
    self.toolRequirement = nil -- Can be set for special nodes
    self.enhancementLevel = 0 -- For future upgrade system
    
    -- Visual representation
    self.visualModel = nil
    self.respawnCoroutine = nil
    
    -- Create the visual model
    self:createVisualModel()
    
    -- Performance tracking
    self.lastUpdateTime = tick()
    
    return self
end

function ResourceNode:createVisualModel()
    if self.visualModel then
        self.visualModel:Destroy()
    end
    
    -- Get the appropriate folder
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then
        resourceFolder = Instance.new("Folder")
        resourceFolder.Name = "ResourceNodes"
        resourceFolder.Parent = workspace
    end
    
    local typeFolder = resourceFolder:FindFirstChild(self.resourceType)
    if not typeFolder then
        typeFolder = Instance.new("Folder")
        typeFolder.Name = self.resourceType
        typeFolder.Parent = resourceFolder
    end
    
    -- Create the visual model based on resource type and rarity
    local model = Instance.new("Part")
    model.Name = self.id
    model.Anchored = true
    model.CanCollide = false
    model.Position = self.position
    
    -- Set appearance based on resource type
    if self.resourceType == "Kelp" then
        model.Size = Vector3.new(1.2, math.random(35, 70)/10, 1.2) -- Varied height
        model.Material = Enum.Material.Neon
        model.Shape = Enum.PartType.Cylinder
        model.Color = self:getVisualColor()
        
    elseif self.resourceType == "Rock" then
        model.Size = Vector3.new(
            math.random(18, 28)/10,
            math.random(12, 22)/10,
            math.random(18, 28)/10
        )
        model.Material = Enum.Material.Rock
        model.Shape = Enum.PartType.Block
        model.Color = self:getVisualColor()
        
    elseif self.resourceType == "Pearl" then
        model.Size = Vector3.new(1.0, 1.0, 1.0)
        model.Material = Enum.Material.Neon
        model.Shape = Enum.PartType.Ball
        model.Color = self:getVisualColor()
        
        -- Add special glow for pearls
        local pointLight = Instance.new("PointLight")
        pointLight.Color = self:getVisualColor()
        pointLight.Brightness = self.rarity == "Rare" and 1.0 or 0.6
        pointLight.Range = self.rarity == "Rare" and 12 or 8
        pointLight.Parent = model
    end
    
    -- Set node attributes for identification
    model:SetAttribute("ResourceType", self.resourceType)
    model:SetAttribute("NodeId", self.id)
    model:SetAttribute("Rarity", self.rarity)
    model:SetAttribute("Harvestable", self.currentState == NodeState.AVAILABLE)
    model:SetAttribute("CreationTime", self.creationTime)
    
    model.Parent = typeFolder
    self.visualModel = model
    
    -- Start visual animations
    self:startVisualAnimations()
end

function ResourceNode:getVisualColor()
    local rarityInfo = RarityData[self.rarity]
    local baseColor
    
    -- Base color by resource type
    if self.resourceType == "Kelp" then
        baseColor = Color3.fromRGB(50, 200, 50)
    elseif self.resourceType == "Rock" then  
        baseColor = Color3.fromRGB(120, 120, 120)
    elseif self.resourceType == "Pearl" then
        baseColor = Color3.fromRGB(255, 255, 240)
    else
        baseColor = Color3.fromRGB(150, 150, 150)
    end
    
    -- Blend with rarity color
    local rarityColor = rarityInfo.displayColor
    local blendFactor = 0.3
    
    return Color3.new(
        baseColor.R * (1 - blendFactor) + rarityColor.R * blendFactor,
        baseColor.G * (1 - blendFactor) + rarityColor.G * blendFactor,
        baseColor.B * (1 - blendFactor) + rarityColor.B * blendFactor
    )
end

function ResourceNode:startVisualAnimations()
    if not self.visualModel then return end
    
    spawn(function()
        local startTime = tick()
        local model = self.visualModel
        local originalCFrame = model.CFrame
        local originalPosition = model.Position
        
        while model.Parent and self.currentState == NodeState.AVAILABLE do
            local time = tick() - startTime
            
            if self.resourceType == "Kelp" then
                -- Enhanced kelp swaying with rarity-based intensity
                local intensity = self.rarity == "Rare" and 0.5 or 0.3
                local swayX = math.sin(time * 1.2) * intensity
                local swayZ = math.cos(time * 0.8) * (intensity * 0.7)
                
                model.CFrame = originalCFrame * CFrame.Angles(math.rad(swayX * 12), 0, math.rad(swayZ * 8))
                
            elseif self.resourceType == "Pearl" then
                -- Enhanced floating with rarity-based effects
                local intensity = self.rarity == "Rare" and 0.4 or 0.25
                local bobHeight = math.sin(time * 2) * intensity
                local rotateY = time * (self.rarity == "Rare" and 50 or 30)
                
                model.Position = originalPosition + Vector3.new(0, bobHeight, 0)
                model.CFrame = CFrame.new(model.Position) * CFrame.Angles(0, math.rad(rotateY), 0)
                
                -- Animate glow intensity
                local pointLight = model:FindFirstChild("PointLight")
                if pointLight then
                    local baseBrightness = self.rarity == "Rare" and 1.0 or 0.6
                    pointLight.Brightness = baseBrightness + math.sin(time * 3) * 0.3
                end
                
            elseif self.resourceType == "Rock" then
                -- Subtle effects for rocks
                if self.rarity == "Rare" then
                    -- Rare rocks have a slight glow
                    if not model:FindFirstChild("PointLight") then
                        local pointLight = Instance.new("PointLight")
                        pointLight.Color = self:getVisualColor()
                        pointLight.Brightness = 0.3
                        pointLight.Range = 6
                        pointLight.Parent = model
                    end
                end
                
                -- Very slow rotation
                local rotateY = time * 5
                model.CFrame = originalCFrame * CFrame.Angles(0, math.rad(rotateY), 0)
            end
            
            wait(0.1) -- 10 FPS animation for performance
        end
    end)
end

function ResourceNode:harvest(player, tool, staminaLevel)
    if self.currentState ~= NodeState.AVAILABLE then
        return false, "Resource not available", nil
    end
    
    local harvestStartTime = tick()
    self.currentState = NodeState.HARVESTING
    
    -- Update visual state
    if self.visualModel then
        self.visualModel:SetAttribute("Harvestable", false)
    end
    
    -- Calculate harvest success based on tool, stamina, and difficulty
    local harvestInfo = self:calculateHarvestOutcome(player, tool, staminaLevel)
    
    if harvestInfo.success then
        -- Successful harvest
        self.currentState = NodeState.HARVESTED
        self.lastHarvested = harvestStartTime
        self.lastHarvestedBy = player.UserId
        self.harvestCount = self.harvestCount + 1
        
        -- Hide visual model
        if self.visualModel then
            self.visualModel.Transparency = 1
            local pointLight = self.visualModel:FindFirstChild("PointLight")
            if pointLight then
                pointLight.Enabled = false
            end
        end
        
        -- Start respawn process
        self:beginRespawn()
        
        return true, "Successfully harvested", harvestInfo
    else
        -- Failed harvest - return to available state
        self.currentState = NodeState.AVAILABLE
        if self.visualModel then
            self.visualModel:SetAttribute("Harvestable", true)
        end
        
        return false, harvestInfo.failureReason, harvestInfo
    end
end

function ResourceNode:calculateHarvestOutcome(player, tool, staminaLevel)
    local harvestInfo = {
        success = false,
        resources = {},
        bonusResources = {},
        experience = 0,
        toolDurabilityLoss = 1,
        staminaCost = 10,
        harvestTime = 2.0,
        failureReason = nil
    }
    
    -- Base success chance
    local successChance = 0.8
    
    -- Tool effectiveness
    local toolMultiplier = 1.0
    local toolBonus = 0.0
    
    if tool then
        -- Check if tool is appropriate for resource type
        local toolEffectiveness = self:getToolEffectiveness(tool)
        toolMultiplier = toolEffectiveness.speedMultiplier
        toolBonus = toolEffectiveness.bonusChance
        successChance = successChance * toolEffectiveness.successMultiplier
        
        harvestInfo.toolDurabilityLoss = toolEffectiveness.durabilityLoss
        harvestInfo.harvestTime = harvestInfo.harvestTime / toolMultiplier
    else
        -- No tool penalty
        successChance = successChance * 0.6
        harvestInfo.harvestTime = harvestInfo.harvestTime * 1.5
    end
    
    -- Stamina effect
    local staminaMultiplier = math.max(0.3, staminaLevel / 100)
    successChance = successChance * staminaMultiplier
    harvestInfo.staminaCost = math.floor(harvestInfo.staminaCost / staminaMultiplier)
    
    -- Difficulty adjustment
    successChance = successChance / self.harvestDifficulty
    
    -- Determine success
    local randomRoll = math.random()
    harvestInfo.success = randomRoll < successChance
    
    if harvestInfo.success then
        -- Basic resource yield
        local baseYield = self:getBaseResourceYield()
        harvestInfo.resources[self.resourceType] = baseYield
        
        -- Bonus resource check
        local bonusRoll = math.random()
        local totalBonusChance = self.bonusChance + toolBonus
        
        if bonusRoll < totalBonusChance then
            local bonusAmount = math.random(1, math.max(1, math.floor(baseYield * 0.5)))
            harvestInfo.bonusResources[self.resourceType] = bonusAmount
        end
        
        -- Rare material bonus for high-rarity nodes
        if self.rarity == "Rare" and math.random() < 0.2 then
            local rareResource = self:getRareMaterial()
            if rareResource then
                harvestInfo.bonusResources[rareResource] = 1
            end
        end
        
        -- Experience calculation
        local baseExp = 10
        local rarityExp = (self.rarity == "Common" and 1) or (self.rarity == "Uncommon" and 2) or 5
        harvestInfo.experience = baseExp * rarityExp
        
    else
        -- Failure reason
        if staminaLevel < 20 then
            harvestInfo.failureReason = "Too tired to harvest effectively"
        elseif not tool and self.harvestDifficulty > 1.5 then
            harvestInfo.failureReason = "This resource requires proper tools"
        else
            harvestInfo.failureReason = "Harvest attempt failed"
        end
    end
    
    return harvestInfo
end

function ResourceNode:getToolEffectiveness(tool)
    local effectiveness = {
        speedMultiplier = 1.0,
        successMultiplier = 1.0,
        bonusChance = 0.0,
        durabilityLoss = 1
    }
    
    if not tool then return effectiveness end
    
    local toolType = tool:GetAttribute("ToolType")
    
    -- Tool-specific bonuses
    if toolType == "KelpTool" and self.resourceType == "Kelp" then
        effectiveness.speedMultiplier = 1.5
        effectiveness.successMultiplier = 1.2
        effectiveness.bonusChance = 0.1
        
    elseif toolType == "RockHammer" and self.resourceType == "Rock" then
        effectiveness.speedMultiplier = 1.3
        effectiveness.successMultiplier = 1.4
        effectiveness.bonusChance = 0.15
        
    elseif toolType == "PearlNet" and self.resourceType == "Pearl" then
        effectiveness.speedMultiplier = 1.0
        effectiveness.successMultiplier = 2.0 -- Much better pearl success
        effectiveness.bonusChance = 0.25
        effectiveness.durabilityLoss = 2 -- Nets wear out faster
        
    else
        -- Wrong tool or generic tool
        effectiveness.speedMultiplier = 0.8
        effectiveness.successMultiplier = 0.9
    end
    
    -- Tool quality/enhancement modifiers
    local toolLevel = tool:GetAttribute("EnhancementLevel") or 0
    local levelMultiplier = 1 + (toolLevel * 0.1)
    
    effectiveness.speedMultiplier = effectiveness.speedMultiplier * levelMultiplier
    effectiveness.successMultiplier = effectiveness.successMultiplier * levelMultiplier
    
    return effectiveness
end

function ResourceNode:getBaseResourceYield()
    local baseYields = {
        Kelp = {Common = 1, Uncommon = 2, Rare = 3},
        Rock = {Common = 1, Uncommon = 1, Rare = 2},
        Pearl = {Common = 1, Uncommon = 1, Rare = 1}
    }
    
    return baseYields[self.resourceType][self.rarity] or 1
end

function ResourceNode:getRareMaterial()
    local rareMaterials = {
        Kelp = "PremiumKelp",
        Rock = "CrystalOre", 
        Pearl = "PerfectPearl"
    }
    
    return rareMaterials[self.resourceType]
end

function ResourceNode:beginRespawn()
    if self.respawnCoroutine then
        coroutine.close(self.respawnCoroutine)
    end
    
    self.currentState = NodeState.RESPAWNING
    
    self.respawnCoroutine = coroutine.create(function()
        -- Wait for respawn time
        local respawnDelay = self.respawnTime + math.random(-5, 5) -- Small variation
        wait(respawnDelay)
        
        -- Respawn the node
        self:respawn()
    end)
    
    coroutine.resume(self.respawnCoroutine)
end

function ResourceNode:respawn()
    if self.currentState ~= NodeState.RESPAWNING then
        return false
    end
    
    self.currentState = NodeState.AVAILABLE
    
    -- Restore visual model
    if self.visualModel then
        self.visualModel.Transparency = 0
        self.visualModel:SetAttribute("Harvestable", true)
        
        local pointLight = self.visualModel:FindFirstChild("PointLight")
        if pointLight then
            pointLight.Enabled = true
        end
        
        -- Restart animations
        self:startVisualAnimations()
    end
    
    return true
end

function ResourceNode:updateState()
    self.lastUpdateTime = tick()
    
    -- Handle any state-specific logic
    if self.currentState == NodeState.RESPAWNING then
        -- Check if respawn coroutine is still running
        if self.respawnCoroutine and coroutine.status(self.respawnCoroutine) == "dead" then
            self.respawnCoroutine = nil
        end
    end
end

function ResourceNode:getInfo()
    return {
        id = self.id,
        resourceType = self.resourceType,
        rarity = self.rarity,
        position = self.position,
        currentState = self.currentState,
        harvestDifficulty = self.harvestDifficulty,
        bonusChance = self.bonusChance,
        respawnTime = self.respawnTime,
        harvestCount = self.harvestCount,
        creationTime = self.creationTime,
        lastHarvested = self.lastHarvested
    }
end

function ResourceNode:destroy()
    if self.respawnCoroutine then
        coroutine.close(self.respawnCoroutine)
        self.respawnCoroutine = nil
    end
    
    if self.visualModel then
        self.visualModel:Destroy()
        self.visualModel = nil
    end
end

-- Static methods
function ResourceNode.determineRarity()
    local roll = math.random()
    
    if roll < RarityData.Common.probability then
        return "Common"
    elseif roll < RarityData.Common.probability + RarityData.Uncommon.probability then
        return "Uncommon"
    else
        return "Rare"
    end
end

function ResourceNode.getRarityInfo(rarity)
    return RarityData[rarity]
end

function ResourceNode.getNodeStates()
    return NodeState
end

return ResourceNode