--[[
ToolSystem.lua

Purpose: Complete tool management system with durability tracking for Week 4
Dependencies: CraftingData, PlayerDataManager, ResourceNode
Last Modified: Phase 0 - Week 4
Performance Notes: Efficient durability tracking, client-server synchronization

Public Methods:
- Initialize(): Set up tool system and events
- CreateTool(toolType, quality): Generate new tool with attributes
- UseTool(player, toolId, targetResource): Process tool usage with durability
- RepairTool(player, toolId, materials): Repair damaged tools
- GetPlayerTools(player): Return player's tool inventory
- EquipTool(player, toolId): Equip tool for active use
]]--

local ToolSystem = {}

-- Import dependencies
local CraftingData = require(game.ReplicatedStorage.SharedModules.CraftingData)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tool system state tracking
local playerEquippedTools = {} -- [playerId] = {slot1, slot2, slot3}
local toolInstances = {} -- [toolId] = toolData
local nextToolId = 1

-- Events
local toolEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local ToolRequestEvent, ToolUpdateEvent, ToolEquipEvent

-- Tool system configuration
local TOOL_CONFIG = {
    -- Tool slots per player
    maxToolSlots = 3,
    quickAccessSlots = 3, -- Hotkey accessible slots (1, 2, 3)
    
    -- Durability system
    durabilityWarningThreshold = 0.2, -- Warn at 20% durability
    breakagePreventionTime = 5, -- Seconds to prevent accidental usage of broken tools
    
    -- Repair system
    repairCostMultiplier = 0.3, -- 30% of original crafting cost
    repairEfficiencyBonus = 0.1, -- 10% durability bonus when professionally repaired
    
    -- Enhancement system
    maxEnhancementLevel = 5,
    enhancementCostBase = {
        [1] = {Kelp = 5, Rock = 2},
        [2] = {Kelp = 8, Rock = 4, Pearl = 1},
        [3] = {Kelp = 12, Rock = 6, Pearl = 2},
        [4] = {Kelp = 20, Rock = 10, Pearl = 3},
        [5] = {Kelp = 30, Rock = 15, Pearl = 5}
    },
    
    -- Tool effectiveness bonuses
    qualityMultipliers = {
        Basic = 1.0,
        Good = 1.15,
        Excellent = 1.35,
        Perfect = 1.6
    },
    
    enhancementMultipliers = {
        [0] = 1.0,
        [1] = 1.1,
        [2] = 1.25,
        [3] = 1.45,
        [4] = 1.7,
        [5] = 2.0
    }
}

-- Tool data structure template
local TOOL_TEMPLATE = {
    toolId = "",
    toolType = "", -- "KelpTool", "RockHammer", "PearlNet"
    displayName = "",
    currentDurability = 0,
    maxDurability = 0,
    quality = "Basic", -- "Basic", "Good", "Excellent", "Perfect"
    enhancementLevel = 0,
    creationTime = 0,
    lastUsed = 0,
    usageCount = 0,
    repairCount = 0,
    craftedBy = 0, -- UserId of creator
    
    -- Calculated properties
    effectiveness = 1.0,
    speedMultiplier = 1.0,
    bonusChance = 0.0,
    
    -- Visual properties
    condition = "Excellent", -- "Excellent", "Good", "Worn", "Damaged", "Broken"
    conditionColor = Color3.fromRGB(0, 255, 0)
}

function ToolSystem:Initialize()
    print("🔧 Initializing ToolSystem...")
    
    -- Create or get tool events
    if not toolEvents then
        toolEvents = Instance.new("Folder")
        toolEvents.Name = "RemoteEvents"
        toolEvents.Parent = ReplicatedStorage
    end
    
    -- Create tool management events
    ToolRequestEvent = toolEvents:FindFirstChild("ToolRequest") or Instance.new("RemoteEvent")
    ToolRequestEvent.Name = "ToolRequest"
    ToolRequestEvent.Parent = toolEvents
    
    ToolUpdateEvent = toolEvents:FindFirstChild("ToolUpdate") or Instance.new("RemoteEvent")
    ToolUpdateEvent.Name = "ToolUpdate"
    ToolUpdateEvent.Parent = toolEvents
    
    ToolEquipEvent = toolEvents:FindFirstChild("ToolEquip") or Instance.new("RemoteEvent")
    ToolEquipEvent.Name = "ToolEquip"
    ToolEquipEvent.Parent = toolEvents
    
    -- Connect event handlers
    ToolRequestEvent.OnServerEvent:Connect(function(player, action, ...)
        self:HandleToolRequest(player, action, ...)
    end)
    
    ToolEquipEvent.OnServerEvent:Connect(function(player, action, ...)
        self:HandleToolEquip(player, action, ...)
    end)
    
    -- Initialize player tool slots
    game.Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerTools(player)
    end)
    
    -- Cleanup on player leave
    game.Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerTools(player)
    end)
    
    -- Start tool condition monitoring
    self:StartToolMonitoring()
    
    print("✅ ToolSystem initialized")
end

function ToolSystem:HandleToolRequest(player, action, ...)
    local args = {...}
    
    if action == "GetPlayerTools" then
        local tools = self:GetPlayerTools(player)
        ToolUpdateEvent:FireClient(player, "PlayerToolsUpdate", tools)
        
    elseif action == "UseTool" then
        local toolId = args[1]
        local targetResourceId = args[2]
        self:UseTool(player, toolId, targetResourceId)
        
    elseif action == "RepairTool" then
        local toolId = args[1]
        local materialOffer = args[2]
        self:RepairTool(player, toolId, materialOffer)
        
    elseif action == "EnhanceTool" then
        local toolId = args[1]
        local materials = args[2]
        self:EnhanceTool(player, toolId, materials)
        
    elseif action == "GetToolInfo" then
        local toolId = args[1]
        local toolInfo = self:GetToolInfo(toolId)
        ToolUpdateEvent:FireClient(player, "ToolInfoUpdate", {toolId = toolId, info = toolInfo})
    end
end

function ToolSystem:HandleToolEquip(player, action, ...)
    local args = {...}
    
    if action == "EquipTool" then
        local toolId = args[1]
        local slot = args[2] or 1
        self:EquipTool(player, toolId, slot)
        
    elseif action == "UnequipTool" then
        local slot = args[1] or 1
        self:UnequipTool(player, slot)
        
    elseif action == "SwapTools" then
        local slot1 = args[1]
        local slot2 = args[2]
        self:SwapToolSlots(player, slot1, slot2)
        
    elseif action == "QuickEquip" then
        local hotkey = args[1] -- 1, 2, or 3
        self:QuickEquipTool(player, hotkey)
    end
end

function ToolSystem:CreateTool(toolType, quality, enhancementLevel, craftedBy)
    quality = quality or "Basic"
    enhancementLevel = enhancementLevel or 0
    
    local recipe = CraftingData:GetRecipe(toolType)
    if not recipe then
        warn("Invalid tool type:", toolType)
        return nil
    end
    
    -- Generate unique tool ID
    local toolId = "tool_" .. tick() .. "_" .. nextToolId
    nextToolId = nextToolId + 1
    
    -- Create tool data
    local toolData = {}
    for key, value in pairs(TOOL_TEMPLATE) do
        toolData[key] = value
    end
    
    toolData.toolId = toolId
    toolData.toolType = toolType
    toolData.displayName = recipe.displayName
    toolData.quality = quality
    toolData.enhancementLevel = enhancementLevel
    toolData.creationTime = tick()
    toolData.craftedBy = craftedBy or 0
    
    -- Calculate durability with quality bonus
    local baseDurability = recipe.durability or 50
    local qualityMultiplier = TOOL_CONFIG.qualityMultipliers[quality] or 1.0
    local enhancementMultiplier = TOOL_CONFIG.enhancementMultipliers[enhancementLevel] or 1.0
    
    toolData.maxDurability = math.floor(baseDurability * qualityMultiplier * enhancementMultiplier)
    toolData.currentDurability = toolData.maxDurability
    
    -- Calculate effectiveness values
    self:RecalculateToolStats(toolData)
    
    -- Store tool instance
    toolInstances[toolId] = toolData
    
    print("🔨 Created tool:", toolData.displayName, "Quality:", quality, "Durability:", toolData.maxDurability)
    return toolData
end

function ToolSystem:RecalculateToolStats(toolData)
    local recipe = CraftingData:GetRecipe(toolData.toolType)
    if not recipe then return end
    
    -- Base effectiveness from recipe
    local baseEffect = recipe.effect or {}
    
    -- Apply quality multiplier
    local qualityMultiplier = TOOL_CONFIG.qualityMultipliers[toolData.quality] or 1.0
    
    -- Apply enhancement multiplier
    local enhancementMultiplier = TOOL_CONFIG.enhancementMultipliers[toolData.enhancementLevel] or 1.0
    
    -- Calculate final stats
    toolData.effectiveness = qualityMultiplier * enhancementMultiplier
    toolData.speedMultiplier = (baseEffect.harvestSpeed or 1.0) * toolData.effectiveness
    toolData.bonusChance = (baseEffect.pearlChance or 0) * toolData.effectiveness * 0.5
    
    -- Update condition based on durability
    self:UpdateToolCondition(toolData)
end

function ToolSystem:UpdateToolCondition(toolData)
    local durabilityPercent = toolData.currentDurability / toolData.maxDurability
    
    if durabilityPercent > 0.8 then
        toolData.condition = "Excellent"
        toolData.conditionColor = Color3.fromRGB(0, 255, 0)
    elseif durabilityPercent > 0.6 then
        toolData.condition = "Good"
        toolData.conditionColor = Color3.fromRGB(150, 255, 0)
    elseif durabilityPercent > 0.4 then
        toolData.condition = "Worn"
        toolData.conditionColor = Color3.fromRGB(255, 255, 0)
    elseif durabilityPercent > 0.2 then
        toolData.condition = "Damaged"
        toolData.conditionColor = Color3.fromRGB(255, 150, 0)
    else
        toolData.condition = "Broken"
        toolData.conditionColor = Color3.fromRGB(255, 0, 0)
    end
    
    -- Reduce effectiveness based on condition
    local conditionMultiplier = math.max(0.3, durabilityPercent) -- Minimum 30% effectiveness
    toolData.effectiveness = toolData.effectiveness * conditionMultiplier
end

function ToolSystem:UseTool(player, toolId, targetResourceId)
    local toolData = toolInstances[toolId]
    if not toolData then
        ToolUpdateEvent:FireClient(player, "ToolError", "Tool not found")
        return false
    end
    
    -- Check if tool is broken
    if toolData.currentDurability <= 0 then
        ToolUpdateEvent:FireClient(player, "ToolError", "Tool is broken and needs repair")
        return false
    end
    
    -- Validate tool ownership
    if not self:PlayerOwnsTool(player, toolId) then
        ToolUpdateEvent:FireClient(player, "ToolError", "You don't own this tool")
        return false
    end
    
    -- Calculate durability loss (varies by tool type and action)
    local durabilityLoss = self:CalculateDurabilityLoss(toolData, targetResourceId)
    
    -- Apply durability loss
    toolData.currentDurability = math.max(0, toolData.currentDurability - durabilityLoss)
    toolData.lastUsed = tick()
    toolData.usageCount = toolData.usageCount + 1
    
    -- Update tool condition
    self:UpdateToolCondition(toolData)
    
    -- Check for durability warnings
    local durabilityPercent = toolData.currentDurability / toolData.maxDurability
    if durabilityPercent <= TOOL_CONFIG.durabilityWarningThreshold and durabilityPercent > 0 then
        ToolUpdateEvent:FireClient(player, "ToolWarning", {
            toolId = toolId,
            condition = toolData.condition,
            durability = toolData.currentDurability,
            maxDurability = toolData.maxDurability
        })
    end
    
    -- If tool breaks, notify player
    if toolData.currentDurability <= 0 then
        ToolUpdateEvent:FireClient(player, "ToolBroken", {
            toolId = toolId,
            toolName = toolData.displayName
        })
        
        -- Auto-unequip broken tool
        self:AutoUnequipBrokenTool(player, toolId)
    end
    
    -- Update player's tool data
    self:SavePlayerToolData(player)
    
    -- Send updated tool info to client
    ToolUpdateEvent:FireClient(player, "ToolUsed", {
        toolId = toolId,
        durabilityLoss = durabilityLoss,
        currentDurability = toolData.currentDurability,
        condition = toolData.condition,
        effectiveness = toolData.effectiveness
    })
    
    return true, toolData
end

function ToolSystem:CalculateDurabilityLoss(toolData, targetResourceId)
    -- Base durability loss
    local baseLoss = 1
    
    -- Tool-specific loss rates
    local toolLossRates = {
        KelpTool = 0.8,    -- Kelp tools are gentler
        RockHammer = 1.2,  -- Hammers wear faster
        PearlNet = 1.5     -- Nets are fragile
    }
    
    local toolMultiplier = toolLossRates[toolData.toolType] or 1.0
    
    -- Quality affects durability loss (better quality tools last longer)
    local qualityMultipliers = {
        Basic = 1.0,
        Good = 0.9,
        Excellent = 0.75,
        Perfect = 0.6
    }
    
    local qualityMultiplier = qualityMultipliers[toolData.quality] or 1.0
    
    -- Enhancement level reduces durability loss
    local enhancementMultiplier = 1.0 - (toolData.enhancementLevel * 0.05) -- 5% reduction per level
    
    -- Random variation (±20%)
    local randomMultiplier = math.random(80, 120) / 100
    
    local finalLoss = baseLoss * toolMultiplier * qualityMultiplier * enhancementMultiplier * randomMultiplier
    return math.max(0.1, finalLoss) -- Minimum loss of 0.1
end

function ToolSystem:RepairTool(player, toolId, materialOffer)
    local toolData = toolInstances[toolId]
    if not toolData then
        ToolUpdateEvent:FireClient(player, "RepairError", "Tool not found")
        return false
    end
    
    if not self:PlayerOwnsTool(player, toolId) then
        ToolUpdateEvent:FireClient(player, "RepairError", "You don't own this tool")
        return false
    end
    
    -- Calculate repair requirements
    local repairCost = self:CalculateRepairCost(toolData)
    
    -- Validate materials
    if not self:ValidateRepairMaterials(player, repairCost, materialOffer) then
        ToolUpdateEvent:FireClient(player, "RepairError", "Insufficient materials")
        return false
    end
    
    -- Consume materials
    if not self:ConsumeRepairMaterials(player, repairCost) then
        ToolUpdateEvent:FireClient(player, "RepairError", "Failed to consume materials")
        return false
    end
    
    -- Repair tool
    local repairAmount = toolData.maxDurability - toolData.currentDurability
    toolData.currentDurability = toolData.maxDurability
    toolData.repairCount = toolData.repairCount + 1
    
    -- Possible durability bonus for quality repairs
    if math.random() < 0.1 then -- 10% chance
        toolData.maxDurability = toolData.maxDurability + 1
        ToolUpdateEvent:FireClient(player, "RepairBonus", "Tool has been improved through expert repair!")
    end
    
    -- Update tool condition
    self:UpdateToolCondition(toolData)
    
    -- Save updated data
    self:SavePlayerToolData(player)
    
    -- Notify client
    ToolUpdateEvent:FireClient(player, "ToolRepaired", {
        toolId = toolId,
        repairedAmount = repairAmount,
        newDurability = toolData.currentDurability,
        maxDurability = toolData.maxDurability
    })
    
    print("🔧 Player", player.Name, "repaired tool:", toolData.displayName)
    return true
end

function ToolSystem:CalculateRepairCost(toolData)
    local recipe = CraftingData:GetRecipe(toolData.toolType)
    if not recipe then return {} end
    
    local repairCost = {}
    local damagePercent = 1 - (toolData.currentDurability / toolData.maxDurability)
    local costMultiplier = TOOL_CONFIG.repairCostMultiplier * damagePercent
    
    for ingredient, amount in pairs(recipe.ingredients) do
        repairCost[ingredient] = math.max(1, math.floor(amount * costMultiplier))
    end
    
    return repairCost
end

function ToolSystem:ValidateRepairMaterials(player, repairCost, materialOffer)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.inventory then return false end
    
    for material, required in pairs(repairCost) do
        local available = playerData.inventory[material] or 0
        if available < required then
            return false
        end
    end
    
    return true
end

function ToolSystem:ConsumeRepairMaterials(player, repairCost)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return false end
    
    for material, required in pairs(repairCost) do
        playerData.inventory[material] = (playerData.inventory[material] or 0) - required
        if playerData.inventory[material] <= 0 then
            playerData.inventory[material] = nil
        end
    end
    
    PlayerDataManager:SavePlayerData(player, playerData)
    return true
end

function ToolSystem:EquipTool(player, toolId, slot)
    slot = math.min(math.max(slot or 1, 1), TOOL_CONFIG.maxToolSlots)
    
    local playerId = player.UserId
    
    -- Initialize player tool slots if needed
    if not playerEquippedTools[playerId] then
        playerEquippedTools[playerId] = {}
    end
    
    -- Validate tool ownership
    if not self:PlayerOwnsTool(player, toolId) then
        ToolEquipEvent:FireClient(player, "EquipError", "You don't own this tool")
        return false
    end
    
    -- Check if tool is broken
    local toolData = toolInstances[toolId]
    if toolData and toolData.currentDurability <= 0 then
        ToolEquipEvent:FireClient(player, "EquipError", "Cannot equip broken tool")
        return false
    end
    
    -- Equip tool
    local previousTool = playerEquippedTools[playerId][slot]
    playerEquippedTools[playerId][slot] = toolId
    
    -- Notify client
    ToolEquipEvent:FireClient(player, "ToolEquipped", {
        toolId = toolId,
        slot = slot,
        previousTool = previousTool
    })
    
    print("⚡ Player", player.Name, "equipped tool in slot", slot, ":", toolData and toolData.displayName or toolId)
    return true
end

function ToolSystem:UnequipTool(player, slot)
    local playerId = player.UserId
    
    if playerEquippedTools[playerId] and playerEquippedTools[playerId][slot] then
        local toolId = playerEquippedTools[playerId][slot]
        playerEquippedTools[playerId][slot] = nil
        
        ToolEquipEvent:FireClient(player, "ToolUnequipped", {
            toolId = toolId,
            slot = slot
        })
        
        return true
    end
    
    return false
end

function ToolSystem:QuickEquipTool(player, hotkey)
    if hotkey < 1 or hotkey > TOOL_CONFIG.quickAccessSlots then
        return false
    end
    
    local playerId = player.UserId
    if not playerEquippedTools[playerId] then
        return false
    end
    
    local toolId = playerEquippedTools[playerId][hotkey]
    if toolId then
        ToolEquipEvent:FireClient(player, "QuickToolActivated", {
            toolId = toolId,
            hotkey = hotkey
        })
        return true
    end
    
    return false
end

function ToolSystem:AutoUnequipBrokenTool(player, brokenToolId)
    local playerId = player.UserId
    if not playerEquippedTools[playerId] then return end
    
    for slot, equippedToolId in pairs(playerEquippedTools[playerId]) do
        if equippedToolId == brokenToolId then
            playerEquippedTools[playerId][slot] = nil
            ToolEquipEvent:FireClient(player, "ToolAutoUnequipped", {
                toolId = brokenToolId,
                slot = slot,
                reason = "Tool broken"
            })
        end
    end
end

function ToolSystem:GetPlayerTools(player)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.tools then return {} end
    
    local tools = {}
    for _, toolData in ipairs(playerData.tools) do
        if toolInstances[toolData.toolId] then
            table.insert(tools, toolInstances[toolData.toolId])
        end
    end
    
    return tools
end

function ToolSystem:PlayerOwnsTool(player, toolId)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.tools then return false end
    
    for _, toolData in ipairs(playerData.tools) do
        if toolData.toolId == toolId then
            return true
        end
    end
    
    return false
end

function ToolSystem:SavePlayerToolData(player)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return end
    
    -- Update player's tool data with current tool states
    playerData.tools = playerData.tools or {}
    
    for i, toolRef in ipairs(playerData.tools) do
        local toolData = toolInstances[toolRef.toolId]
        if toolData then
            playerData.tools[i] = toolData
        end
    end
    
    PlayerDataManager:SavePlayerData(player, playerData)
end

function ToolSystem:InitializePlayerTools(player)
    local playerId = player.UserId
    playerEquippedTools[playerId] = {}
    
    -- Load player's existing tools into tool instances
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if playerData and playerData.tools then
        for _, toolData in ipairs(playerData.tools) do
            if toolData.toolId then
                toolInstances[toolData.toolId] = toolData
                -- Recalculate stats in case of system updates
                self:RecalculateToolStats(toolData)
            end
        end
    end
end

function ToolSystem:CleanupPlayerTools(player)
    local playerId = player.UserId
    playerEquippedTools[playerId] = nil
end

function ToolSystem:StartToolMonitoring()
    spawn(function()
        while true do
            wait(30) -- Check every 30 seconds
            
            -- Clean up unused tool instances
            local activeToolIds = {}
            
            -- Collect active tools from all players
            for _, player in pairs(game.Players:GetPlayers()) do
                local tools = self:GetPlayerTools(player)
                for _, tool in ipairs(tools) do
                    activeToolIds[tool.toolId] = true
                end
            end
            
            -- Remove unused tool instances
            for toolId, _ in pairs(toolInstances) do
                if not activeToolIds[toolId] then
                    toolInstances[toolId] = nil
                end
            end
        end
    end)
end

function ToolSystem:GetToolInfo(toolId)
    return toolInstances[toolId]
end

function ToolSystem:GetSystemStats()
    local totalTools = 0
    local brokenTools = 0
    local toolsByType = {}
    
    for _, toolData in pairs(toolInstances) do
        totalTools = totalTools + 1
        
        if toolData.currentDurability <= 0 then
            brokenTools = brokenTools + 1
        end
        
        toolsByType[toolData.toolType] = (toolsByType[toolData.toolType] or 0) + 1
    end
    
    return {
        totalTools = totalTools,
        brokenTools = brokenTools,
        toolsByType = toolsByType,
        activeInstances = totalTools
    }
end

return ToolSystem