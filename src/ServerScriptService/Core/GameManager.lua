--[[
GameManager.lua

Purpose: Central coordinator for all game systems
Dependencies: All core systems
Last Modified: Phase 0 - Week 1
Performance Notes: Handles server initialization and system coordination

Public Methods:
- Initialize(): Start all game systems
- GetGameState(): Returns current server state
- MonitorPerformance(): Continuous performance monitoring
]]--

local GameManager = {}
local RunService = game:GetService("RunService")

-- Global game state
local GAME_STATE = {
    initialized = false,
    playersOnline = 0,
    worldGenerated = false,
    resourcesSpawned = false,
    serverStartTime = tick(),
    version = "MVP_Beta_v1"
}

-- Performance budget enforcement (from risk mitigation)
local PERFORMANCE_BUDGET = {
    maxPartsInWorkspace = 1000,
    maxActiveScripts = 25, 
    maxNetworkEventsPerSecond = 15,
    targetFPS = 30
}

function GameManager:Initialize()
    print("🌊 AquaticMetropolis Server Starting...")
    print("📋 Version:", GAME_STATE.version)
    
    -- Initialize core systems in order
    local success = true
    
    -- 1. World generation
    print("⚙️ Initializing world...")
    success = success and self:InitializeWorld()
    
    -- 2. Resource spawning  
    print("⚙️ Initializing resources...")
    success = success and self:InitializeResources()
    
    -- 3. Player data system
    print("⚙️ Initializing player systems...")
    success = success and self:InitializePlayerSystem()
    
    -- 4. Performance monitoring
    print("⚙️ Starting performance monitoring...")
    success = success and self:InitializeMonitoring()
    
    if success then
        GAME_STATE.initialized = true
        print("✅ Server initialization complete")
        print("🎯 Performance target: " .. PERFORMANCE_BUDGET.targetFPS .. " FPS")
    else
        error("❌ Server initialization failed")
    end
    
    return success
end

function GameManager:InitializeWorld()
    local WorldGenerator = require(script.Parent.WorldGenerator)
    
    -- Create basic underwater environment
    WorldGenerator:CreateBasicTerrain()
    WorldGenerator:SetupEnvironment() 
    WorldGenerator:SpawnAmbientFish()
    
    GAME_STATE.worldGenerated = true
    print("✅ World generation complete")
    return true
end

function GameManager:InitializeResources()
    local ResourceSpawner = require(script.Parent.ResourceSpawner)
    
    -- Spawn initial resource nodes
    ResourceSpawner:SpawnInitialResources()
    
    GAME_STATE.resourcesSpawned = true
    print("✅ Resource spawning complete")
    return true
end

function GameManager:InitializePlayerSystem()
    local PlayerManager = require(script.Parent.PlayerManager)
    
    -- Set up player join/leave handlers
    PlayerManager:Initialize()
    
    print("✅ Player system initialized")
    return true
end

function GameManager:InitializeMonitoring()
    -- Start performance monitoring
    self:MonitorPerformance()
    
    print("✅ Performance monitoring started")
    return true
end

function GameManager:MonitorPerformance()
    spawn(function()
        while true do
            wait(5) -- Check every 5 seconds
            
            local partCount = #workspace:GetDescendants()
            if partCount > PERFORMANCE_BUDGET.maxPartsInWorkspace then
                warn("⚠️ Part count exceeded:", partCount)
                self:CleanupExcessParts()
            end
            
            -- Monitor FPS (simplified check)
            local fps = 1 / RunService.Heartbeat:Wait()
            if fps < PERFORMANCE_BUDGET.targetFPS then
                warn("⚠️ Low FPS detected:", math.floor(fps))
                self:ReduceGraphicsQuality()
            end
        end
    end)
end

function GameManager:CleanupExcessParts()
    -- Simple cleanup: remove oldest non-essential parts
    local nonEssentialFolders = {"EnvironmentalAssets", "PlayerBuildings"}
    
    for _, folderName in ipairs(nonEssentialFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local children = folder:GetChildren()
            if #children > 50 then -- Keep only 50 most recent
                table.sort(children, function(a, b)
                    return (a:GetAttribute("SpawnTime") or 0) < (b:GetAttribute("SpawnTime") or 0)
                end)
                
                -- Remove oldest 25%
                local removeCount = math.floor(#children * 0.25)
                for i = 1, removeCount do
                    if children[i] then
                        children[i]:Destroy()
                    end
                end
                
                print("🧹 Cleaned up", removeCount, "parts from", folderName)
            end
        end
    end
end

function GameManager:ReduceGraphicsQuality()
    -- Reduce visual effects when performance drops
    local lighting = game:GetService("Lighting")
    
    -- Reduce lighting quality
    if lighting.Brightness > 1.0 then
        lighting.Brightness = 1.0
        warn("🔧 Reduced lighting brightness for performance")
    end
    
    -- Reduce particle effects
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            obj.Rate = obj.Rate * 0.5
        end
    end
end

function GameManager:GetGameState()
    GAME_STATE.playersOnline = #game.Players:GetPlayers()
    return GAME_STATE
end

function GameManager:GetPerformanceStats()
    return {
        partsInWorkspace = #workspace:GetDescendants(),
        playersOnline = #game.Players:GetPlayers(),
        serverUptime = tick() - GAME_STATE.serverStartTime,
        memoryUsage = game:GetService("Stats"):GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances)
    }
end

return GameManager