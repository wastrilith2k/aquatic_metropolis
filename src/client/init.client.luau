--[[
init.client.luau

Purpose: Main client initialization script for Week 4 UI systems
Dependencies: All UI systems and RemoteEvents
Last Modified: Phase 0 - Week 4

This script initializes all client-side systems including:
- Enhanced inventory UI with drag-and-drop
- Crafting interface with progress indicators  
- Player HUD with stamina and tool durability
- Resource interaction system with tool validation
- Tutorial system for new player onboarding
]]--

print("🎮 AquaticMetropolis Client Starting...")
print("📅 Phase 0 - Week 4 UI & Building Systems")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Wait for required modules to load
local function waitForModules()
    -- Wait for UI modules
    local starterGui = player:WaitForChild("PlayerGui").Parent:WaitForChild("StarterGui")
    local uiFolder = starterGui:WaitForChild("UI")
    
    uiFolder:WaitForChild("InventoryInterface")
    uiFolder:WaitForChild("CraftingInterface") 
    uiFolder:WaitForChild("PlayerHUD")
    uiFolder:WaitForChild("FeedbackSystem")
    
    local clientFolder = starterGui:WaitForChild("Client")
    clientFolder:WaitForChild("ResourceInteraction")
    clientFolder:WaitForChild("TutorialSystem")
    clientFolder:WaitForChild("TutorialSystemEnhanced")
    
    print("✅ All UI modules loaded")
end

-- Initialize client systems
local function initializeClient()
    print("⚡ Initializing client systems...")
    
    -- Load UI modules
    local InventoryInterface = require(StarterGui.UI.InventoryInterface)
    local CraftingInterface = require(StarterGui.UI.CraftingInterface) 
    local PlayerHUD = require(StarterGui.UI.PlayerHUD)
    local FeedbackSystem = require(StarterGui.UI.FeedbackSystem)
    local ResourceInteraction = require(StarterGui.Client.ResourceInteraction)
    local TutorialSystem = require(StarterGui.Client.TutorialSystem)
    local TutorialSystemEnhanced = require(StarterGui.Client.TutorialSystemEnhanced)
    
    -- Initialize systems
    local inventoryUI = InventoryInterface.new()
    print("   ✅ Inventory UI initialized")
    
    local craftingUI = CraftingInterface.new()
    print("   ✅ Crafting UI initialized")
    
    local playerHUD = PlayerHUD.new()
    print("   ✅ Player HUD initialized")
    
    local feedbackSystem = FeedbackSystem.new()
    print("   ✅ Feedback System initialized")
    
    local resourceInteraction = ResourceInteraction.new()
    print("   ✅ Resource Interaction initialized")
    
    -- Use enhanced tutorial system for Week 6
    local tutorialSystemEnhanced = TutorialSystemEnhanced.new()
    print("   ✅ Enhanced Tutorial System initialized")
    
    print("🎉 All client systems ready!")
    
    return {
        inventoryUI = inventoryUI,
        craftingUI = craftingUI, 
        playerHUD = playerHUD,
        feedbackSystem = feedbackSystem,
        resourceInteraction = resourceInteraction,
        tutorialSystemEnhanced = tutorialSystemEnhanced
    }
end

-- Handle initialization errors
local function handleError(err)
    warn("💥 Client initialization error:", err)
    warn("🔧 Attempting minimal recovery...")
    
    -- Create basic message for player
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ErrorMessage"
    screenGui.Parent = player.PlayerGui
    
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Size = UDim2.new(0, 400, 0, 100)
    errorLabel.Position = UDim2.new(0.5, -200, 0.5, -50)
    errorLabel.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    errorLabel.Text = "⚠️ Some UI features may not work properly.\nTry refreshing or contact support."
    errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    errorLabel.TextSize = 14
    errorLabel.Font = Enum.Font.GothamBold
    errorLabel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = errorLabel
end

-- Start client initialization  
spawn(function()
    local success, result = pcall(function()
        waitForModules()
        return initializeClient()
    end)
    
    if not success then
        handleError(result)
    else
        print("🎮 Client ready for interaction!")
        print("🎯 Week 4 Features Available:")
        print("   • TAB - Open/Close Inventory") 
        print("   • C - Open/Close Crafting")
        print("   • Click resources to harvest with tools")
        print("   • Tutorial will guide new players")
        print("   • HUD shows stamina and tool durability")
    end
end)