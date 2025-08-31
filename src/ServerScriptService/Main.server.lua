--[[
Main.server.lua

Purpose: Main server initialization script for AquaticMetropolis
Dependencies: All core systems
Last Modified: Phase 0 - Week 4

This script runs when the server starts and initializes all game systems.
Supports all Phase 0 systems including Week 4 UI and building systems.
]]--

-- Configuration: Set to true to use enhanced features
local USE_ENHANCED_GENERATION = true
local ENABLE_WEEK4_SYSTEMS = true

if ENABLE_WEEK4_SYSTEMS then
    print("🌊 AquaticMetropolis UI & Building Beta v4.0 Starting...")
    print("📅 Phase 0 - Week 4 Implementation")
elseif USE_ENHANCED_GENERATION then
    print("🌊 AquaticMetropolis Enhanced Beta v2.0 Starting...")
    print("📅 Phase 0 - Week 2 Implementation")
else
    print("🌊 AquaticMetropolis MVP Beta v1.0 Starting...")
    print("📅 Phase 0 - Week 1 Implementation")
end

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
    
    -- 2. Initialize ResourceSpawner with appropriate system
    local ResourceSpawner = require(script.Parent.Core.ResourceSpawner)
    
    if USE_ENHANCED_GENERATION then
        print("🎆 Using enhanced procedural world generation...")
        ResourceSpawner:InitializeEnhanced()
        ResourceSpawner:SpawnEnhancedResources()
    else
        print("🎆 Using legacy world generation...")
        ResourceSpawner:Initialize()
        ResourceSpawner:SpawnInitialResources()
    end
    
    -- 3. Initialize PlayerDataManager
    local PlayerDataManager = require(script.Parent.Core.PlayerDataManager)
    PlayerDataManager:Initialize()
    
    -- 4. Initialize Week 4 systems if enabled
    if ENABLE_WEEK4_SYSTEMS then
        print("🔧 Initializing Week 4 systems...")
        
        -- Initialize Tool System
        local ToolSystem = require(script.Parent.Core.ToolSystem)
        ToolSystem:Initialize()
        print("   ✅ Tool System initialized")
        
        -- Initialize Stamina System
        local StaminaSystem = require(script.Parent.Core.StaminaSystem)
        StaminaSystem:Initialize()
        print("   ✅ Stamina System initialized")
        
        -- Initialize Crafting System
        local CraftingSystem = require(script.Parent.Core.CraftingSystem)
        CraftingSystem:Initialize()
        print("   ✅ Crafting System initialized")
        
        -- Initialize Building System
        local BuildingSystem = require(script.Parent.Core.BuildingSystem)
        BuildingSystem:Initialize()
        print("   ✅ Building System initialized")
        
        print("🎉 Week 4 systems ready!")
    end
    
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
        
        if USE_ENHANCED_GENERATION then
            WorldGenerator:CreateEnhancedTerrain()
        else
            WorldGenerator:CreateBasicTerrain()
            WorldGenerator:SetupEnvironment()
        end
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
    
    if ENABLE_WEEK4_SYSTEMS then
        print("🎯 Week 4 UI & Building objectives:")
        print("   • Test enhanced inventory with drag-and-drop")
        print("   • Validate crafting interface with progress indicators")
        print("   • Test tool durability and stamina integration")
        print("   • Validate building placement system")
        print("   • Test tutorial system for new player onboarding")
        print("   • Measure UI performance and responsiveness")
        print("   • Collect feedback for Phase 1 preparation")
    elseif USE_ENHANCED_GENERATION then
        print("🎯 Enhanced Beta objectives:")
        print("   • Test enhanced procedural world generation")
        print("   • Validate improved resource placement")
        print("   • Measure performance with larger worlds")
        print("   • Test enhanced visual effects and animations")
        print("   • Collect feedback for Week 3 features")
    else
        print("🎯 MVP Beta objectives:")
        print("   • Test core resource gathering loop")
        print("   • Validate basic crafting system")
        print("   • Measure player engagement metrics")
        print("   • Collect feedback for Phase 1")
    end
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