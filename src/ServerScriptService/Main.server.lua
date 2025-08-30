--[[
Main.server.lua

Purpose: Main server initialization script for AquaticMetropolis MVP
Dependencies: All core systems
Last Modified: Phase 0 - Week 1

This script runs when the server starts and initializes all game systems.
]]--

print("🌊 AquaticMetropolis MVP Beta v1.0 Starting...")
print("📅 Phase 0 - Week 1 Implementation")

-- Wait for all required services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Initialize core systems in order
local function initializeServer()
    print("⚡ Initializing server systems...")
    
    -- 1. Initialize GameManager (coordinates everything else)
    local GameManager = require(script.Parent.Core.GameManager)
    local success = GameManager:Initialize()
    
    if not success then
        error("❌ Failed to initialize GameManager - server startup aborted")
    end
    
    -- 2. Initialize ResourceSpawner
    local ResourceSpawner = require(script.Parent.Core.ResourceSpawner)
    ResourceSpawner:Initialize()
    ResourceSpawner:SpawnInitialResources()
    
    -- 3. Initialize PlayerDataManager
    local PlayerDataManager = require(script.Parent.Core.PlayerDataManager)
    PlayerDataManager:Initialize()
    
    print("✅ All server systems initialized successfully!")
    
    -- Start monitoring systems
    monitorServerHealth()
    
    return true
end

-- Monitor server performance and health
local function monitorServerHealth()
    spawn(function()
        local lastReport = tick()
        
        while true do
            wait(60) -- Check every minute
            
            local currentTime = tick()
            if currentTime - lastReport >= 300 then -- Report every 5 minutes
                local GameManager = require(script.Parent.Core.GameManager)
                local stats = GameManager:GetPerformanceStats()
                
                print("📊 Server Health Report:")
                print("   Players Online:", stats.playersOnline)
                print("   Parts in Workspace:", stats.partsInWorkspace)
                print("   Memory Usage:", math.floor(stats.memoryUsage), "MB")
                print("   Uptime:", math.floor(stats.serverUptime / 60), "minutes")
                
                lastReport = currentTime
            end
        end
    end)
end

-- Handle any initialization errors
local function handleError(err)
    warn("💥 Server initialization error:", err)
    warn("🔧 Attempting emergency recovery...")
    
    -- Try to continue with minimal systems
    local success = pcall(function()
        -- Just create basic world without resources
        local WorldGenerator = require(script.Parent.Core.WorldGenerator)
        WorldGenerator:CreateBasicTerrain()
        WorldGenerator:SetupEnvironment()
    end)
    
    if success then
        warn("⚠️ Emergency recovery successful - limited functionality available")
    else
        error("💀 Emergency recovery failed - server cannot start")
    end
end

-- Start server initialization
local initSuccess, initError = pcall(initializeServer)

if not initSuccess then
    handleError(initError)
else
    print("🎉 AquaticMetropolis server is ready for players!")
    print("🎯 MVP Beta objectives:")
    print("   • Test core resource gathering loop")
    print("   • Validate basic crafting system")
    print("   • Measure player engagement metrics")
    print("   • Collect feedback for Phase 1")
end

-- Handle server shutdown gracefully
game:BindToClose(function()
    print("🌊 Server shutting down...")
    
    -- Save all player data
    local PlayerDataManager = require(script.Parent.Core.PlayerDataManager)
    for _, player in pairs(Players:GetPlayers()) do
        local playerData = PlayerDataManager:GetPlayerData(player)
        if playerData then
            PlayerDataManager:SavePlayerData(player, playerData)
            print("💾 Final save completed for:", player.Name)
        end
    end
    
    print("✅ Server shutdown complete")
end)