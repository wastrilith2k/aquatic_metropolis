--[[
StaminaSystem.lua

Purpose: Player energy management system for Week 4 gameplay mechanics
Dependencies: PlayerDataManager, ToolSystem
Last Modified: Phase 0 - Week 4
Performance Notes: Efficient stamina tracking, smooth regeneration, client synchronization

Public Methods:
- Initialize(): Set up stamina system and events
- ConsumeStamina(player, amount, activity): Reduce player stamina
- RegenerateStamina(player, amount): Restore player stamina
- GetPlayerStamina(player): Return current stamina information
- SetStaminaModifier(player, modifier, duration): Apply temporary effects
]]--

local StaminaSystem = {}

-- Import dependencies
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Stamina system state tracking
local playerStaminaData = {} -- [playerId] = {current, max, regenRate, modifiers, lastUpdate}
local staminaModifiers = {} -- [playerId] = {[modifierId] = {multiplier, expiration}}

-- Events
local staminaEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local StaminaRequestEvent, StaminaUpdateEvent

-- Stamina system configuration
local STAMINA_CONFIG = {
    -- Base stamina values
    maxStamina = 100,
    startingStamina = 100,
    
    -- Regeneration settings
    baseRegenRate = 8, -- Stamina per second when idle
    restingRegenRate = 15, -- Enhanced regen when specifically resting
    regenDelay = 2, -- Seconds after activity before regen starts
    
    -- Activity costs
    activityCosts = {
        harvest = 12,        -- Per harvest attempt
        craft = 8,           -- Per crafting action
        build = 15,          -- Per building placement
        run = 4,             -- Per second while running
        swim_fast = 5,       -- Per second while swimming quickly
        tool_use = 10        -- Base tool usage cost
    },
    
    -- Efficiency thresholds
    efficiencyThresholds = {
        excellent = 0.8,     -- 80%+ stamina = 120% efficiency
        good = 0.6,          -- 60%+ stamina = 100% efficiency  
        tired = 0.4,         -- 40%+ stamina = 80% efficiency
        exhausted = 0.2,     -- 20%+ stamina = 60% efficiency
        -- Below 20% = 40% efficiency
    },
    
    -- Status effects
    statusEffects = {
        energized = {threshold = 0.9, duration = 30}, -- Above 90% stamina
        tired = {threshold = 0.3, duration = 10},      -- Below 30% stamina
        exhausted = {threshold = 0.1, duration = 20}   -- Below 10% stamina
    },
    
    -- Rest mechanics
    restingRequirements = {
        minDuration = 5,     -- Must rest for 5+ seconds to get bonus
        movementThreshold = 2, -- Max movement allowed while "resting"
        actionCooldown = 3   -- Seconds after action before resting begins
    },
    
    -- Progression bonuses (future expansion)
    levelBonuses = {
        maxStaminaPerLevel = 5,
        regenBonusPerLevel = 0.5,
        efficiencyBonusPerLevel = 0.02
    }
}

-- Player stamina data template
local STAMINA_TEMPLATE = {
    current = 100,
    max = 100,
    regenRate = 8,
    lastUpdate = 0,
    lastActivity = 0,
    isResting = false,
    restStartTime = 0,
    efficiency = 1.0,
    status = "normal", -- "normal", "energized", "tired", "exhausted"
    
    -- Activity tracking
    totalActivities = 0,
    staminaSpent = 0,
    restingTime = 0,
    
    -- Modifiers
    activeModifiers = {}
}

function StaminaSystem:Initialize()
    print("⚡ Initializing StaminaSystem...")
    
    -- Create or get stamina events
    if not staminaEvents then
        staminaEvents = Instance.new("Folder")
        staminaEvents.Name = "RemoteEvents"
        staminaEvents.Parent = ReplicatedStorage
    end
    
    -- Create stamina events
    StaminaRequestEvent = staminaEvents:FindFirstChild("StaminaRequest") or Instance.new("RemoteEvent")
    StaminaRequestEvent.Name = "StaminaRequest"
    StaminaRequestEvent.Parent = staminaEvents
    
    StaminaUpdateEvent = staminaEvents:FindFirstChild("StaminaUpdate") or Instance.new("RemoteEvent")
    StaminaUpdateEvent.Name = "StaminaUpdate"
    StaminaUpdateEvent.Parent = staminaEvents
    
    -- Connect event handlers
    StaminaRequestEvent.OnServerEvent:Connect(function(player, action, ...)
        self:HandleStaminaRequest(player, action, ...)
    end)
    
    -- Initialize player stamina on join
    game.Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerStamina(player)
    end)
    
    -- Cleanup on player leave
    game.Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerStamina(player)
    end)
    
    -- Start stamina regeneration loop
    self:StartStaminaLoop()
    
    print("✅ StaminaSystem initialized")
end

function StaminaSystem:HandleStaminaRequest(player, action, ...)
    local args = {...}
    
    if action == "GetStamina" then
        local staminaInfo = self:GetPlayerStamina(player)
        StaminaUpdateEvent:FireClient(player, "StaminaInfo", staminaInfo)
        
    elseif action == "StartResting" then
        self:StartResting(player)
        
    elseif action == "StopResting" then
        self:StopResting(player)
        
    elseif action == "ConsumeStamina" then
        local amount = args[1]
        local activity = args[2]
        local success = self:ConsumeStamina(player, amount, activity)
        StaminaUpdateEvent:FireClient(player, "StaminaConsumed", {success = success, amount = amount})
        
    elseif action == "CheckCanPerform" then
        local activity = args[1]
        local canPerform, reason = self:CanPerformActivity(player, activity)
        StaminaUpdateEvent:FireClient(player, "ActivityCheck", {activity = activity, canPerform = canPerform, reason = reason})
    end
end

function StaminaSystem:InitializePlayerStamina(player)
    local playerId = player.UserId
    
    -- Load existing stamina data or create new
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    local staminaData = {}
    for key, value in pairs(STAMINA_TEMPLATE) do
        staminaData[key] = value
    end
    
    -- Load saved stamina or use defaults
    if playerData and playerData.stamina then
        staminaData.current = math.min(playerData.stamina.current or STAMINA_CONFIG.maxStamina, STAMINA_CONFIG.maxStamina)
        staminaData.max = playerData.stamina.max or STAMINA_CONFIG.maxStamina
        staminaData.totalActivities = playerData.stamina.totalActivities or 0
        staminaData.staminaSpent = playerData.stamina.staminaSpent or 0
        staminaData.restingTime = playerData.stamina.restingTime or 0
    end
    
    staminaData.lastUpdate = tick()
    
    -- Apply any player level bonuses (future expansion)
    local playerLevel = (playerData and playerData.level) or 1
    staminaData.max = STAMINA_CONFIG.maxStamina + ((playerLevel - 1) * STAMINA_CONFIG.levelBonuses.maxStaminaPerLevel)
    staminaData.regenRate = STAMINA_CONFIG.baseRegenRate + ((playerLevel - 1) * STAMINA_CONFIG.levelBonuses.regenBonusPerLevel)
    
    playerStaminaData[playerId] = staminaData
    
    -- Update efficiency based on current stamina
    self:UpdatePlayerEfficiency(player)
    
    -- Send initial stamina data to client
    StaminaUpdateEvent:FireClient(player, "StaminaInitialized", self:GetPlayerStamina(player))
    
    print("⚡ Initialized stamina for player:", player.Name, "Current:", staminaData.current)
end

function StaminaSystem:CleanupPlayerStamina(player)
    local playerId = player.UserId
    
    -- Save stamina data before cleanup
    self:SavePlayerStamina(player)
    
    -- Remove from active tracking
    playerStaminaData[playerId] = nil
    staminaModifiers[playerId] = nil
end

function StaminaSystem:ConsumeStamina(player, amount, activity)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then
        warn("No stamina data for player:", player.Name)
        return false
    end
    
    -- Check if player has enough stamina
    if staminaData.current < amount then
        StaminaUpdateEvent:FireClient(player, "StaminaInsufficient", {
            required = amount,
            current = staminaData.current,
            activity = activity
        })
        return false
    end
    
    -- Apply stamina cost modifiers
    local modifiedAmount = self:ApplyStaminaModifiers(player, amount, activity)
    
    -- Consume stamina
    staminaData.current = math.max(0, staminaData.current - modifiedAmount)
    staminaData.lastActivity = tick()
    staminaData.totalActivities = staminaData.totalActivities + 1
    staminaData.staminaSpent = staminaData.staminaSpent + modifiedAmount
    
    -- Stop resting if currently resting
    if staminaData.isResting then
        self:StopResting(player)
    end
    
    -- Update efficiency
    self:UpdatePlayerEfficiency(player)
    
    -- Update status effects
    self:UpdateStatusEffects(player)
    
    -- Send update to client
    StaminaUpdateEvent:FireClient(player, "StaminaChanged", {
        current = staminaData.current,
        max = staminaData.max,
        consumed = modifiedAmount,
        activity = activity,
        efficiency = staminaData.efficiency,
        status = staminaData.status
    })
    
    return true
end

function StaminaSystem:RegenerateStamina(player, amount)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return false end
    
    local oldStamina = staminaData.current
    staminaData.current = math.min(staminaData.max, staminaData.current + amount)
    
    -- Update efficiency if stamina changed significantly
    if math.abs(staminaData.current - oldStamina) >= 5 then
        self:UpdatePlayerEfficiency(player)
        self:UpdateStatusEffects(player)
        
        -- Send update to client
        StaminaUpdateEvent:FireClient(player, "StaminaRegened", {
            current = staminaData.current,
            max = staminaData.max,
            regenerated = staminaData.current - oldStamina,
            efficiency = staminaData.efficiency,
            status = staminaData.status
        })
    end
    
    return true
end

function StaminaSystem:StartResting(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return false end
    
    -- Check if enough time has passed since last activity
    local timeSinceActivity = tick() - staminaData.lastActivity
    if timeSinceActivity < STAMINA_CONFIG.restingRequirements.actionCooldown then
        StaminaUpdateEvent:FireClient(player, "RestingBlocked", {
            reason = "Too soon after activity",
            waitTime = STAMINA_CONFIG.restingRequirements.actionCooldown - timeSinceActivity
        })
        return false
    end
    
    staminaData.isResting = true
    staminaData.restStartTime = tick()
    
    StaminaUpdateEvent:FireClient(player, "RestingStarted", {
        restingRegenRate = STAMINA_CONFIG.restingRegenRate
    })
    
    return true
end

function StaminaSystem:StopResting(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData or not staminaData.isResting then return false end
    
    local restDuration = tick() - staminaData.restStartTime
    staminaData.restingTime = staminaData.restingTime + restDuration
    staminaData.isResting = false
    staminaData.restStartTime = 0
    
    -- Award bonus stamina for successful resting
    if restDuration >= STAMINA_CONFIG.restingRequirements.minDuration then
        local bonusStamina = math.min(5, restDuration * 0.5) -- Bonus for good rest
        self:RegenerateStamina(player, bonusStamina)
        
        StaminaUpdateEvent:FireClient(player, "RestingBonus", {
            duration = restDuration,
            bonus = bonusStamina
        })
    end
    
    StaminaUpdateEvent:FireClient(player, "RestingStopped", {
        duration = restDuration
    })
    
    return true
end

function StaminaSystem:CanPerformActivity(player, activity)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then
        return false, "Stamina data not found"
    end
    
    local requiredStamina = STAMINA_CONFIG.activityCosts[activity] or 0
    
    if staminaData.current < requiredStamina then
        return false, string.format("Need %d stamina (have %d)", requiredStamina, staminaData.current)
    end
    
    -- Check for status effect restrictions
    if staminaData.status == "exhausted" and (activity == "run" or activity == "swim_fast") then
        return false, "Too exhausted for intense activity"
    end
    
    return true, "Can perform activity"
end

function StaminaSystem:ApplyStaminaModifiers(player, amount, activity)
    local playerId = player.UserId
    local modifiers = staminaModifiers[playerId]
    
    if not modifiers then return amount end
    
    local multiplier = 1.0
    local currentTime = tick()
    
    -- Apply active modifiers and clean up expired ones
    for modifierId, modifierData in pairs(modifiers) do
        if modifierData.expiration > currentTime then
            multiplier = multiplier * modifierData.multiplier
        else
            modifiers[modifierId] = nil -- Clean up expired modifier
        end
    end
    
    return amount * multiplier
end

function StaminaSystem:UpdatePlayerEfficiency(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return end
    
    local staminaPercent = staminaData.current / staminaData.max
    
    -- Calculate efficiency based on stamina level
    if staminaPercent >= STAMINA_CONFIG.efficiencyThresholds.excellent then
        staminaData.efficiency = 1.2 -- 20% bonus
    elseif staminaPercent >= STAMINA_CONFIG.efficiencyThresholds.good then
        staminaData.efficiency = 1.0 -- Normal efficiency
    elseif staminaPercent >= STAMINA_CONFIG.efficiencyThresholds.tired then
        staminaData.efficiency = 0.8 -- 20% penalty
    elseif staminaPercent >= STAMINA_CONFIG.efficiencyThresholds.exhausted then
        staminaData.efficiency = 0.6 -- 40% penalty
    else
        staminaData.efficiency = 0.4 -- 60% penalty
    end
end

function StaminaSystem:UpdateStatusEffects(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return end
    
    local staminaPercent = staminaData.current / staminaData.max
    local newStatus = "normal"
    
    -- Determine status based on thresholds
    if staminaPercent >= STAMINA_CONFIG.statusEffects.energized.threshold then
        newStatus = "energized"
    elseif staminaPercent <= STAMINA_CONFIG.statusEffects.exhausted.threshold then
        newStatus = "exhausted"
    elseif staminaPercent <= STAMINA_CONFIG.statusEffects.tired.threshold then
        newStatus = "tired"
    end
    
    -- Update status if changed
    if newStatus ~= staminaData.status then
        local oldStatus = staminaData.status
        staminaData.status = newStatus
        
        StaminaUpdateEvent:FireClient(player, "StatusChanged", {
            oldStatus = oldStatus,
            newStatus = newStatus,
            staminaPercent = staminaPercent
        })
    end
end

function StaminaSystem:SetStaminaModifier(player, modifierId, multiplier, duration)
    local playerId = player.UserId
    
    if not staminaModifiers[playerId] then
        staminaModifiers[playerId] = {}
    end
    
    staminaModifiers[playerId][modifierId] = {
        multiplier = multiplier,
        expiration = tick() + duration
    }
    
    StaminaUpdateEvent:FireClient(player, "ModifierApplied", {
        modifierId = modifierId,
        multiplier = multiplier,
        duration = duration
    })
end

function StaminaSystem:GetPlayerStamina(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return nil end
    
    return {
        current = staminaData.current,
        max = staminaData.max,
        percent = staminaData.current / staminaData.max,
        regenRate = staminaData.regenRate,
        efficiency = staminaData.efficiency,
        status = staminaData.status,
        isResting = staminaData.isResting,
        lastActivity = staminaData.lastActivity,
        
        -- Statistics
        totalActivities = staminaData.totalActivities,
        staminaSpent = staminaData.staminaSpent,
        restingTime = staminaData.restingTime
    }
end

function StaminaSystem:StartStaminaLoop()
    spawn(function()
        while true do
            local currentTime = tick()
            
            -- Process stamina regeneration for all players
            for playerId, staminaData in pairs(playerStaminaData) do
                local player = game.Players:GetPlayerByUserId(playerId)
                if player and player.Parent then
                    -- Only regenerate if player hasn't been active recently
                    local timeSinceActivity = currentTime - staminaData.lastActivity
                    
                    if timeSinceActivity >= STAMINA_CONFIG.regenDelay then
                        local regenRate = staminaData.regenRate
                        
                        -- Enhanced regen if resting
                        if staminaData.isResting then
                            regenRate = STAMINA_CONFIG.restingRegenRate
                        end
                        
                        -- Apply regeneration
                        if staminaData.current < staminaData.max then
                            self:RegenerateStamina(player, regenRate * 0.5) -- 0.5 second intervals
                        end
                    end
                else
                    -- Clean up disconnected players
                    playerStaminaData[playerId] = nil
                    if staminaModifiers[playerId] then
                        staminaModifiers[playerId] = nil
                    end
                end
            end
            
            wait(0.5) -- Update every 0.5 seconds for smooth regen
        end
    end)
end

function StaminaSystem:SavePlayerStamina(player)
    local playerId = player.UserId
    local staminaData = playerStaminaData[playerId]
    
    if not staminaData then return end
    
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if playerData then
        playerData.stamina = {
            current = staminaData.current,
            max = staminaData.max,
            totalActivities = staminaData.totalActivities,
            staminaSpent = staminaData.staminaSpent,
            restingTime = staminaData.restingTime
        }
        
        PlayerDataManager:SavePlayerData(player, playerData)
    end
end

function StaminaSystem:GetSystemStats()
    local totalPlayers = 0
    local avgStamina = 0
    local restingPlayers = 0
    local exhaustedPlayers = 0
    
    for _, staminaData in pairs(playerStaminaData) do
        totalPlayers = totalPlayers + 1
        avgStamina = avgStamina + (staminaData.current / staminaData.max)
        
        if staminaData.isResting then
            restingPlayers = restingPlayers + 1
        end
        
        if staminaData.status == "exhausted" then
            exhaustedPlayers = exhaustedPlayers + 1
        end
    end
    
    if totalPlayers > 0 then
        avgStamina = avgStamina / totalPlayers
    end
    
    return {
        totalPlayers = totalPlayers,
        averageStaminaPercent = avgStamina,
        restingPlayers = restingPlayers,
        exhaustedPlayers = exhaustedPlayers
    }
end

-- Utility function for other systems to check stamina requirements
function StaminaSystem:CheckStaminaForActivity(player, activity)
    local requiredStamina = STAMINA_CONFIG.activityCosts[activity] or 0
    local staminaInfo = self:GetPlayerStamina(player)
    
    if not staminaInfo then return false, 0 end
    
    return staminaInfo.current >= requiredStamina, staminaInfo.efficiency
end

-- Function to consume stamina with activity-specific costs
function StaminaSystem:ConsumeActivityStamina(player, activity)
    local cost = STAMINA_CONFIG.activityCosts[activity] or 0
    if cost > 0 then
        return self:ConsumeStamina(player, cost, activity)
    end
    return true
end

return StaminaSystem