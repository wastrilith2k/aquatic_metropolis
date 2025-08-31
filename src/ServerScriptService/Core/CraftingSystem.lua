--[[
CraftingSystem.lua

Purpose: Server-side crafting system for recipe processing and validation
Dependencies: CraftingData, PlayerDataManager, ToolSystem
Last Modified: Phase 0 - Week 3
Performance Notes: Efficient recipe validation, secure server-side processing

Public Methods:
- Initialize(): Set up crafting system and events
- ProcessCraftingRequest(player, recipeId, quantity): Handle crafting attempts
- ValidateRecipe(player, recipeId): Check if player can craft recipe
- GetAvailableRecipes(player): Return craftable recipes for player
- StartCraftingProcess(player, recipeId): Begin crafting with progress tracking
]]--

local CraftingSystem = {}

-- Import dependencies
local CraftingData = require(game.ReplicatedStorage.SharedModules.CraftingData)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crafting state tracking
local activeCraftingProcesses = {} -- [playerId] = {recipeId, startTime, duration, quantity}
local craftingStations = {} -- Future expansion for crafting station requirements

-- Events
local craftingEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local CraftingRequestEvent, CraftingProgressEvent, CraftingCompleteEvent

-- Crafting configuration
local CRAFTING_CONFIG = {
    -- Base crafting times (can be modified by player skills)
    baseCraftTime = 1.0, -- seconds per craft time unit in recipe
    
    -- Quality system (future expansion)
    qualityLevels = {"Basic", "Good", "Excellent", "Perfect"},
    
    -- Batch crafting limits
    maxBatchSize = 5,
    batchTimeReduction = 0.1, -- 10% time reduction per additional item in batch
    
    -- Failure rates
    baseFailureRate = 0.05, -- 5% base chance to fail and waste materials
    
    -- Experience rewards
    baseExperience = 25, -- Base XP per successful craft
    
    -- Performance limits
    maxConcurrentCrafts = 3, -- Per player
    craftingYieldInterval = 0.1 -- Update frequency for progress
}

function CraftingSystem:Initialize()
    print("🔧 Initializing CraftingSystem...")
    
    -- Create or get crafting events
    if not craftingEvents then
        craftingEvents = Instance.new("Folder")
        craftingEvents.Name = "RemoteEvents"
        craftingEvents.Parent = ReplicatedStorage
    end
    
    -- Create crafting events
    CraftingRequestEvent = craftingEvents:FindFirstChild("CraftingRequest") or Instance.new("RemoteEvent")
    CraftingRequestEvent.Name = "CraftingRequest"
    CraftingRequestEvent.Parent = craftingEvents
    
    CraftingProgressEvent = craftingEvents:FindFirstChild("CraftingProgress") or Instance.new("RemoteEvent")
    CraftingProgressEvent.Name = "CraftingProgress"
    CraftingProgressEvent.Parent = craftingEvents
    
    CraftingCompleteEvent = craftingEvents:FindFirstChild("CraftingComplete") or Instance.new("RemoteEvent")
    CraftingCompleteEvent.Name = "CraftingComplete"
    CraftingCompleteEvent.Parent = craftingEvents
    
    -- Connect event handlers
    CraftingRequestEvent.OnServerEvent:Connect(function(player, action, ...)
        self:HandleCraftingRequest(player, action, ...)
    end)
    
    -- Start crafting progress monitoring
    self:StartProgressMonitoring()
    
    print("✅ CraftingSystem initialized with", CraftingData:GetRecipeCount(), "recipes")
end

function CraftingSystem:HandleCraftingRequest(player, action, ...)
    local args = {...}
    
    if action == "StartCrafting" then
        local recipeId = args[1]
        local quantity = args[2] or 1
        self:ProcessCraftingRequest(player, recipeId, quantity)
        
    elseif action == "CancelCrafting" then
        self:CancelCraftingProcess(player)
        
    elseif action == "GetAvailableRecipes" then
        local recipes = self:GetAvailableRecipes(player)
        CraftingProgressEvent:FireClient(player, "RecipeList", recipes)
        
    elseif action == "ValidateRecipe" then
        local recipeId = args[1]
        local isValid, reason = self:ValidateRecipe(player, recipeId)
        CraftingProgressEvent:FireClient(player, "RecipeValidation", {
            recipeId = recipeId,
            valid = isValid,
            reason = reason
        })
    end
end

function CraftingSystem:ProcessCraftingRequest(player, recipeId, quantity)
    quantity = math.min(quantity or 1, CRAFTING_CONFIG.maxBatchSize)
    
    -- Validate player isn't already crafting too much
    local playerCraftingCount = self:GetPlayerCraftingCount(player)
    if playerCraftingCount >= CRAFTING_CONFIG.maxConcurrentCrafts then
        CraftingCompleteEvent:FireClient(player, "CraftingFailed", {
            reason = "Too many active crafting processes",
            recipeId = recipeId
        })
        return false
    end
    
    -- Validate recipe and ingredients
    local isValid, validationResult = self:ValidateRecipe(player, recipeId, quantity)
    if not isValid then
        CraftingCompleteEvent:FireClient(player, "CraftingFailed", {
            reason = validationResult,
            recipeId = recipeId
        })
        return false
    end
    
    -- Get recipe data
    local recipe = CraftingData:GetRecipe(recipeId)
    if not recipe then
        warn("Invalid recipe ID:", recipeId)
        return false
    end
    
    -- Calculate crafting time with batch reduction
    local baseCraftTime = recipe.craftTime * CRAFTING_CONFIG.baseCraftTime
    local totalCraftTime = baseCraftTime * quantity
    
    -- Apply batch time reduction
    if quantity > 1 then
        local reduction = (quantity - 1) * CRAFTING_CONFIG.batchTimeReduction
        totalCraftTime = totalCraftTime * (1 - math.min(reduction, 0.5)) -- Max 50% reduction
    end
    
    -- Consume ingredients
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local consumed = self:ConsumeIngredients(player, recipe, quantity)
    if not consumed then
        CraftingCompleteEvent:FireClient(player, "CraftingFailed", {
            reason = "Failed to consume ingredients",
            recipeId = recipeId
        })
        return false
    end
    
    -- Start crafting process
    self:StartCraftingProcess(player, recipeId, quantity, totalCraftTime)
    return true
end

function CraftingSystem:ValidateRecipe(player, recipeId, quantity)
    quantity = quantity or 1
    
    local recipe = CraftingData:GetRecipe(recipeId)
    if not recipe then
        return false, "Recipe not found"
    end
    
    -- Get player inventory
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    if not playerData then
        return false, "Player data not found"
    end
    
    local playerInventory = playerData.inventory or {}
    
    -- Check ingredient requirements
    local missingIngredients = {}
    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        local totalRequired = requiredAmount * quantity
        local playerAmount = playerInventory[ingredient] or 0
        
        if playerAmount < totalRequired then
            table.insert(missingIngredients, {
                resource = ingredient,
                have = playerAmount,
                need = totalRequired,
                missing = totalRequired - playerAmount
            })
        end
    end
    
    if #missingIngredients > 0 then
        return false, {
            type = "MissingIngredients",
            missing = missingIngredients
        }
    end
    
    -- Check inventory space for output (if applicable)
    local outputItemCount = 1 * quantity
    local currentItemCount = 0
    for _, amount in pairs(playerInventory) do
        currentItemCount = currentItemCount + amount
    end
    
    -- Assume max inventory is 50 slots for now (should be configurable)
    local maxInventorySlots = playerData.inventorySlots or 50
    if currentItemCount + outputItemCount > maxInventorySlots then
        return false, "Not enough inventory space"
    end
    
    -- Future: Check crafting skill requirements
    -- Future: Check crafting station requirements
    
    return true, "Recipe can be crafted"
end

function CraftingSystem:ConsumeIngredients(player, recipe, quantity)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.inventory then
        return false
    end
    
    -- Double-check ingredients are still available (prevent race conditions)
    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        local totalRequired = requiredAmount * quantity
        local playerAmount = playerData.inventory[ingredient] or 0
        
        if playerAmount < totalRequired then
            return false
        end
    end
    
    -- Consume ingredients
    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        local totalRequired = requiredAmount * quantity
        playerData.inventory[ingredient] = (playerData.inventory[ingredient] or 0) - totalRequired
        
        -- Remove ingredient entirely if amount reaches 0
        if playerData.inventory[ingredient] <= 0 then
            playerData.inventory[ingredient] = nil
        end
    end
    
    -- Save updated player data
    PlayerDataManager:SavePlayerData(player, playerData)
    return true
end

function CraftingSystem:StartCraftingProcess(player, recipeId, quantity, craftTime)
    local playerId = player.UserId
    
    -- Create crafting process
    activeCraftingProcesses[playerId] = {
        player = player,
        recipeId = recipeId,
        quantity = quantity,
        startTime = tick(),
        duration = craftTime,
        progress = 0,
        stage = "Crafting" -- "Crafting", "Finalizing", "Complete"
    }
    
    -- Notify client that crafting started
    CraftingProgressEvent:FireClient(player, "CraftingStarted", {
        recipeId = recipeId,
        quantity = quantity,
        duration = craftTime
    })
    
    print("🔨 Player", player.Name, "started crafting", quantity, "x", recipeId, "- Duration:", craftTime, "seconds")
end

function CraftingSystem:StartProgressMonitoring()
    spawn(function()
        while true do
            local currentTime = tick()
            local completedProcesses = {}
            
            for playerId, process in pairs(activeCraftingProcesses) do
                local elapsedTime = currentTime - process.startTime
                local progress = math.min(elapsedTime / process.duration, 1.0)
                
                -- Update progress
                process.progress = progress
                
                -- Send progress update to client
                if process.player and process.player.Parent then
                    CraftingProgressEvent:FireClient(process.player, "CraftingProgress", {
                        recipeId = process.recipeId,
                        progress = progress,
                        stage = process.stage
                    })
                end
                
                -- Check if crafting is complete
                if progress >= 1.0 then
                    table.insert(completedProcesses, playerId)
                end
            end
            
            -- Process completed crafting
            for _, playerId in ipairs(completedProcesses) do
                self:CompleteCraftingProcess(playerId)
            end
            
            wait(CRAFTING_CONFIG.craftingYieldInterval)
        end
    end)
end

function CraftingSystem:CompleteCraftingProcess(playerId)
    local process = activeCraftingProcesses[playerId]
    if not process then return end
    
    local player = process.player
    local recipeId = process.recipeId
    local quantity = process.quantity
    
    -- Remove from active processes
    activeCraftingProcesses[playerId] = nil
    
    if not player or not player.Parent then
        -- Player left during crafting
        return
    end
    
    local recipe = CraftingData:GetRecipe(recipeId)
    if not recipe then
        warn("Recipe not found during completion:", recipeId)
        return
    end
    
    -- Calculate success/failure
    local craftingResults = self:CalculateCraftingResults(player, recipe, quantity)
    
    if craftingResults.success then
        -- Add crafted items to inventory
        self:AddCraftedItemsToInventory(player, recipeId, craftingResults)
        
        -- Award experience
        self:AwardCraftingExperience(player, recipe, craftingResults)
        
        -- Notify client of success
        CraftingCompleteEvent:FireClient(player, "CraftingSuccess", {
            recipeId = recipeId,
            quantity = craftingResults.producedItems,
            qualityLevel = craftingResults.quality,
            bonusItems = craftingResults.bonusItems,
            experience = craftingResults.experience
        })
        
        print("✅ Player", player.Name, "completed crafting", craftingResults.producedItems, "x", recipeId)
        
    else
        -- Crafting failed - ingredients were already consumed
        CraftingCompleteEvent:FireClient(player, "CraftingFailed", {
            recipeId = recipeId,
            reason = craftingResults.failureReason
        })
        
        print("❌ Player", player.Name, "failed crafting", recipeId, "-", craftingResults.failureReason)
    end
end

function CraftingSystem:CalculateCraftingResults(player, recipe, quantity)
    local results = {
        success = true,
        producedItems = quantity,
        quality = "Basic",
        bonusItems = 0,
        experience = 0,
        failureReason = nil
    }
    
    -- Calculate base success rate
    local successRate = 1.0 - CRAFTING_CONFIG.baseFailureRate
    
    -- Future: Apply player skill bonuses
    -- Future: Apply crafting station bonuses
    -- Future: Apply tool bonuses
    
    -- Roll for success
    local successRoll = math.random()
    if successRoll > successRate then
        results.success = false
        results.failureReason = "Crafting attempt failed"
        results.producedItems = 0
        return results
    end
    
    -- Calculate quality (future feature)
    local qualityRoll = math.random()
    if qualityRoll < 0.05 then
        results.quality = "Perfect"
        results.bonusItems = math.floor(quantity * 0.5) -- 50% bonus items
    elseif qualityRoll < 0.15 then
        results.quality = "Excellent"
        results.bonusItems = math.floor(quantity * 0.25) -- 25% bonus items
    elseif qualityRoll < 0.4 then
        results.quality = "Good"
        results.bonusItems = math.floor(quantity * 0.1) -- 10% bonus items
    end
    
    -- Calculate experience
    local baseExp = CRAFTING_CONFIG.baseExperience
    local qualityMultiplier = (results.quality == "Perfect" and 2.0) or 
                             (results.quality == "Excellent" and 1.5) or
                             (results.quality == "Good" and 1.2) or 1.0
    
    results.experience = math.floor(baseExp * quantity * qualityMultiplier)
    
    return results
end

function CraftingSystem:AddCraftedItemsToInventory(player, recipeId, results)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return false end
    
    playerData.inventory = playerData.inventory or {}
    
    -- Add main crafted items
    local totalItems = results.producedItems + results.bonusItems
    
    if recipeId == "KelpTool" or recipeId == "RockHammer" or recipeId == "PearlNet" then
        -- Tools are stored differently with durability
        playerData.tools = playerData.tools or {}
        
        for i = 1, totalItems do
            local toolData = self:CreateToolData(recipeId, results.quality)
            table.insert(playerData.tools, toolData)
        end
    else
        -- Regular items go to inventory
        local itemName = recipeId -- Or get display name from recipe
        playerData.inventory[itemName] = (playerData.inventory[itemName] or 0) + totalItems
    end
    
    PlayerDataManager:SavePlayerData(player, playerData)
    return true
end

function CraftingSystem:CreateToolData(recipeId, quality)
    local recipe = CraftingData:GetRecipe(recipeId)
    local toolData = {
        toolType = recipeId,
        durability = recipe.durability,
        maxDurability = recipe.durability,
        quality = quality,
        enhancementLevel = 0,
        crafted = tick(),
        crafterId = nil -- Future: Track who crafted it
    }
    
    -- Quality affects tool stats
    local qualityMultipliers = {
        Basic = 1.0,
        Good = 1.1,
        Excellent = 1.25,
        Perfect = 1.5
    }
    
    local multiplier = qualityMultipliers[quality] or 1.0
    toolData.maxDurability = math.floor(toolData.maxDurability * multiplier)
    toolData.durability = toolData.maxDurability
    
    return toolData
end

function CraftingSystem:AwardCraftingExperience(player, recipe, results)
    -- Future: Implement experience system
    -- For now, just track in player data
    
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if playerData then
        playerData.craftingExperience = (playerData.craftingExperience or 0) + results.experience
        playerData.totalCrafted = (playerData.totalCrafted or 0) + results.producedItems
        
        PlayerDataManager:SavePlayerData(player, playerData)
    end
end

function CraftingSystem:GetAvailableRecipes(player)
    local allRecipes = CraftingData:GetAllRecipes()
    local availableRecipes = {}
    
    for recipeId, recipe in pairs(allRecipes) do
        local canCraft, reason = self:ValidateRecipe(player, recipeId)
        
        availableRecipes[recipeId] = {
            recipe = recipe,
            canCraft = canCraft,
            reason = type(reason) == "string" and reason or nil,
            missingIngredients = type(reason) == "table" and reason.missing or nil
        }
    end
    
    return availableRecipes
end

function CraftingSystem:CancelCraftingProcess(player)
    local playerId = player.UserId
    local process = activeCraftingProcesses[playerId]
    
    if not process then
        return false
    end
    
    -- Remove process
    activeCraftingProcesses[playerId] = nil
    
    -- Note: Ingredients are already consumed and not refunded
    -- This is intentional to prevent crafting cancellation abuse
    
    CraftingCompleteEvent:FireClient(player, "CraftingCancelled", {
        recipeId = process.recipeId
    })
    
    return true
end

function CraftingSystem:GetPlayerCraftingCount(player)
    local count = 0
    local playerId = player.UserId
    
    for pId, process in pairs(activeCraftingProcesses) do
        if pId == playerId then
            count = count + 1
        end
    end
    
    return count
end

function CraftingSystem:GetCraftingStats()
    return {
        activeProcesses = 0, -- Count active processes
        totalRecipes = CraftingData:GetRecipeCount(),
        completedToday = 0, -- Future: Track daily stats
        averageCraftTime = 0 -- Future: Calculate averages
    }
end

return CraftingSystem