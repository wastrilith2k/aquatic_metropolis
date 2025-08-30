--[[
PlayerDataManager.lua

Purpose: Manages all player data with robust save system
Dependencies: DataStoreService
Last Modified: Phase 0 - Week 1  
Performance Notes: Handles up to 30 concurrent players efficiently

Public Methods:
- LoadPlayerData(player): Load or create player data
- SavePlayerData(player, playerData): Save with redundancy
- StartAutoSave(player, playerData): Begin auto-save loop
- GetPlayerData(player): Get cached player data
]]--

local PlayerDataManager = {}
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Triple-redundant save system (from risk mitigation)
local primaryStore = DataStoreService:GetDataStore("PlayerData_Beta_v1")
local backupStore = DataStoreService:GetDataStore("PlayerDataBackup_Beta_v1")
local emergencyStore = DataStoreService:GetDataStore("PlayerDataEmergency_Beta_v1")

-- Cache player data for performance
local playerDataCache = {}
local autoSaveConnections = {}

-- MVP Player Data Structure
local DEFAULT_PLAYER_DATA = {
    version = 1, -- For future data migrations
    
    -- Core inventory (5-slot limit from MVP)
    inventory = {
        Kelp = 0,
        Rock = 0, 
        Pearl = 0
    },
    
    -- Tools with durability tracking
    tools = {}, -- Array: {{type="KelpTool", durability=50, crafted=tick()}}
    
    -- Crafted items for buildables
    buildables = {}, -- Array of buildable item IDs player owns
    
    -- Progression tracking
    crafted = {}, -- {RecipeId = count} for achievement tracking
    buildingsPlaced = 0,
    totalPlaytime = 0,
    resourcesGathered = {
        total = 0,
        Kelp = 0,
        Rock = 0,
        Pearl = 0
    },
    
    -- Tutorial progress
    tutorial = {
        completed = false,
        currentStep = 1,
        completedSteps = {}
    },
    
    -- Unlocked areas (for future phases)
    unlockedAreas = {
        KelpForest = true -- Starting area
    },
    
    -- Session tracking
    joinDate = tick(),
    lastSave = tick(),
    sessionStart = tick(),
    sessionData = {
        count = 0,
        totalTime = 0
    },
    
    -- Beta testing specific
    betaFeedback = {
        satisfaction = nil, -- 1-10 scale
        bugs = {},
        suggestions = {},
        mostEnjoyedFeature = nil,
        leastEnjoyedFeature = nil
    }
}

function PlayerDataManager:Initialize()
    -- Set up player join/leave handlers
    game.Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    game.Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    print("✅ PlayerDataManager initialized")
end

function PlayerDataManager:OnPlayerJoined(player)
    print("👋 Player joined:", player.Name)
    
    -- Load player data
    local playerData = self:LoadPlayerData(player)
    
    -- Cache the data
    playerDataCache[player.UserId] = playerData
    
    -- Start auto-save
    self:StartAutoSave(player, playerData)
    
    -- Initialize UI
    self:InitializePlayerUI(player)
    
    print("✅ Player data loaded for:", player.Name)
end

function PlayerDataManager:OnPlayerLeaving(player)
    print("👋 Player leaving:", player.Name)
    
    local playerData = playerDataCache[player.UserId]
    if playerData then
        -- Final save before leaving
        self:SavePlayerData(player, playerData)
        
        -- Stop auto-save
        if autoSaveConnections[player.UserId] then
            autoSaveConnections[player.UserId]:Disconnect()
            autoSaveConnections[player.UserId] = nil
        end
        
        -- Clear cache
        playerDataCache[player.UserId] = nil
    end
    
    print("💾 Final save completed for:", player.Name)
end

function PlayerDataManager:LoadPlayerData(player)
    local playerData = nil
    local loadSuccess = false
    
    -- Try primary store first
    local success, result = pcall(function()
        return primaryStore:GetAsync(player.UserId)
    end)
    
    if success and result then
        playerData = result
        loadSuccess = true
        print("📖 Loaded from primary store:", player.Name)
    else
        -- Try backup store
        success, result = pcall(function()
            return backupStore:GetAsync(player.UserId)
        end)
        
        if success and result then
            playerData = result
            loadSuccess = true
            print("📖 Loaded from backup store:", player.Name)
        else
            -- Try emergency store
            success, result = pcall(function()
                return emergencyStore:GetAsync(player.UserId)
            end)
            
            if success and result then
                playerData = result
                loadSuccess = true
                print("📖 Loaded from emergency store:", player.Name)
            end
        end
    end
    
    -- Use default if all stores fail
    if not loadSuccess or not playerData then
        playerData = self:DeepCopy(DEFAULT_PLAYER_DATA)
        playerData.joinDate = tick()
        print("📝 Created new player data:", player.Name)
    else
        -- Merge with defaults for any missing fields
        playerData = self:MergeWithDefaults(playerData)
        print("🔄 Merged player data with defaults:", player.Name)
    end
    
    -- Update session tracking
    playerData.sessionData.count = (playerData.sessionData.count or 0) + 1
    playerData.sessionStart = tick()
    
    return playerData
end

function PlayerDataManager:SavePlayerData(player, playerData)
    -- Update session time
    if playerData.sessionStart then
        local sessionTime = tick() - playerData.sessionStart
        playerData.sessionData.totalTime = (playerData.sessionData.totalTime or 0) + sessionTime
        playerData.totalPlaytime = (playerData.totalPlaytime or 0) + sessionTime
        playerData.sessionStart = tick() -- Reset for next save
    end
    
    playerData.lastSave = tick()
    
    -- Save to all three stores (fire-and-forget for backup/emergency)
    local primarySuccess = false
    local backupSuccess = false
    local emergencySuccess = false
    
    -- Primary save (wait for result)
    local success, errorMsg = pcall(function()
        primaryStore:SetAsync(player.UserId, playerData)
    end)
    primarySuccess = success
    
    if not success then
        warn("Primary save failed for " .. player.Name .. ":", errorMsg)
    end
    
    -- Backup save (async)
    spawn(function()
        local success = pcall(function()
            backupStore:SetAsync(player.UserId, playerData)
        end)
        backupSuccess = success
        if not success then
            warn("Backup save failed for " .. player.Name)
        end
    end)
    
    -- Emergency save (async)
    spawn(function()
        local success = pcall(function()
            emergencyStore:SetAsync(player.UserId, playerData)
        end)
        emergencySuccess = success
        if not success then
            warn("Emergency save failed for " .. player.Name)
        end
    end)
    
    -- Return success if at least primary succeeded
    return primarySuccess
end

function PlayerDataManager:StartAutoSave(player, playerData)
    -- Auto-save every 30 seconds
    local connection = RunService.Heartbeat:Connect(function()
        wait(30)
        if playerDataCache[player.UserId] then
            self:SavePlayerData(player, playerDataCache[player.UserId])
        end
    end)
    
    autoSaveConnections[player.UserId] = connection
    print("🔄 Auto-save started for:", player.Name)
end

function PlayerDataManager:GetPlayerData(player)
    return playerDataCache[player.UserId]
end

function PlayerDataManager:UpdatePlayerData(player, updateFunction)
    local playerData = playerDataCache[player.UserId]
    if playerData then
        updateFunction(playerData)
        playerDataCache[player.UserId] = playerData
    end
end

-- Utility functions
function PlayerDataManager:DeepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = self:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function PlayerDataManager:MergeWithDefaults(playerData)
    local function mergeRecursive(data, defaults)
        for key, defaultValue in pairs(defaults) do
            if data[key] == nil then
                if type(defaultValue) == "table" then
                    data[key] = self:DeepCopy(defaultValue)
                else
                    data[key] = defaultValue
                end
            elseif type(defaultValue) == "table" and type(data[key]) == "table" then
                mergeRecursive(data[key], defaultValue)
            end
        end
    end
    
    mergeRecursive(playerData, DEFAULT_PLAYER_DATA)
    return playerData
end

function PlayerDataManager:InitializePlayerUI(player)
    -- Signal client to create UI (will be implemented in UI system)
    local initUIEvent = game.ReplicatedStorage:FindFirstChild("InitializeUI")
    if initUIEvent then
        initUIEvent:FireClient(player, playerDataCache[player.UserId])
    end
end

function PlayerDataManager:GetPlayerStats(player)
    local playerData = self:GetPlayerData(player)
    if not playerData then return nil end
    
    return {
        totalPlaytime = math.floor(playerData.totalPlaytime / 60), -- minutes
        resourcesGathered = playerData.resourcesGathered.total,
        itemsCrafted = self:GetTotalCrafted(playerData),
        buildingsPlaced = playerData.buildingsPlaced,
        sessionsPlayed = playerData.sessionData.count
    }
end

function PlayerDataManager:GetTotalCrafted(playerData)
    local total = 0
    for _, count in pairs(playerData.crafted) do
        total = total + count
    end
    return total
end

return PlayerDataManager