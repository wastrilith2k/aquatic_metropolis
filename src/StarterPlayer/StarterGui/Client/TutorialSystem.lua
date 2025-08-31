--[[
TutorialSystem.lua

Purpose: Tutorial system hooks for Week 4 player onboarding
Dependencies: All UI systems, RemoteEvents for server communication
Last Modified: Phase 0 - Week 4
Performance Notes: Lightweight system with event-driven progression tracking

Features:
- Progressive tutorial steps with context-sensitive guidance
- Interactive overlay system with highlighting
- Achievement-based tutorial progression
- Adaptive tutorials based on player actions
- Tutorial skipping and resuming functionality
- Integration with all Week 4 systems (Inventory, Crafting, Building, etc.)
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Module dependencies
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Remote event references (create if needed)
local GetTutorialProgressEvent = RemoteEvents:WaitForChild("GetTutorialProgress")
local UpdateTutorialProgressEvent = RemoteEvents:WaitForChild("UpdateTutorialProgress")
local CompleteTutorialStepEvent = RemoteEvents:WaitForChild("CompleteTutorialStep")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TutorialSystem = {}
TutorialSystem.__index = TutorialSystem

-- Constants
local ANIMATION_TIME = 0.5
local HIGHLIGHT_PULSE_TIME = 1.0
local TUTORIAL_Z_INDEX = 1000

-- Tutorial step definitions
local TUTORIAL_STEPS = {
    -- Phase 1: Basic Movement and Interface
    {
        id = "welcome",
        title = "Welcome to AquaticMetropolis!",
        description = "Use WASD keys to swim around and explore the underwater world.",
        type = "info",
        condition = function() return true end,
        completion = function(self) return self:hasPlayerMoved() end
    },
    
    {
        id = "open_inventory", 
        title = "Managing Your Inventory",
        description = "Press TAB to open your inventory. This is where you'll manage your resources and tools.",
        type = "keypress",
        targetKey = Enum.KeyCode.Tab,
        targetUI = "InventoryGUI",
        condition = function(self) return self:isStepCompleted("welcome") end
    },
    
    {
        id = "first_harvest",
        title = "Harvesting Resources",
        description = "Click on kelp nodes to harvest them. Look for the green plants around you!",
        type = "interaction",
        targetType = "resource_harvest",
        condition = function(self) return self:isStepCompleted("open_inventory") end,
        completion = function(self) return self:hasHarvestedResource("Kelp") end
    },
    
    {
        id = "stamina_system",
        title = "Managing Your Energy",
        description = "Notice the stamina bar in the bottom-left. Actions consume energy, so rest when needed!",
        type = "info",
        condition = function(self) return self:isStepCompleted("first_harvest") end,
        completion = function(self) return self:hasStaminaBelowPercent(0.8) end
    },
    
    -- Phase 2: Tools and Crafting
    {
        id = "open_crafting",
        title = "Crafting Your First Tool", 
        description = "Press C to open the crafting interface. You'll need tools to harvest efficiently!",
        type = "keypress",
        targetKey = Enum.KeyCode.C,
        targetUI = "CraftingGUI",
        condition = function(self) return self:hasResource("Kelp", 5) end
    },
    
    {
        id = "craft_kelp_tool",
        title = "Craft a Kelp Harvester",
        description = "Find the Kelp Tool recipe and craft it. This will make kelp harvesting much more efficient!",
        type = "craft",
        targetRecipe = "KelpTool",
        condition = function(self) return self:isStepCompleted("open_crafting") end,
        completion = function(self) return self:hasItem("KelpTool") end
    },
    
    {
        id = "equip_tool",
        title = "Equipping Tools",
        description = "Right-click the Kelp Tool in your inventory to equip it. Watch your HUD for the tool durability bar!",
        type = "interaction",
        condition = function(self) return self:isStepCompleted("craft_kelp_tool") end,
        completion = function(self) return self:hasEquippedTool("KelpTool") end
    },
    
    -- Phase 3: Advanced Systems
    {
        id = "efficient_harvest",
        title = "Efficient Harvesting",
        description = "With your tool equipped, harvest kelp again. Notice the improved speed and bonus resources!",
        type = "interaction",
        condition = function(self) return self:isStepCompleted("equip_tool") end,
        completion = function(self) return self:hasUsedTool("KelpTool") end
    },
    
    {
        id = "explore_resources",
        title = "Discovering New Resources",
        description = "Explore the area to find rock nodes and pearl beds. Different tools work better on different resources!",
        type = "exploration",
        condition = function(self) return self:isStepCompleted("efficient_harvest") end,
        completion = function(self) return self:hasDiscoveredResourceTypes(2) end
    },
    
    -- Phase 4: Building System
    {
        id = "building_intro",
        title = "Construction Basics",
        description = "You can build structures! First, craft some building materials in the crafting interface.",
        type = "info", 
        condition = function(self) return self:hasResource("Rock", 3) end,
        completion = function(self) return self:hasBuilding() end
    },
    
    {
        id = "tutorial_complete",
        title = "Tutorial Complete!",
        description = "You've mastered the basics! Continue exploring and building your underwater metropolis.",
        type = "completion",
        condition = function(self) return self:isStepCompleted("building_intro") end
    }
}

function TutorialSystem.new()
    local self = setmetatable({}, TutorialSystem)
    
    -- State management
    self.currentStep = 1
    self.completedSteps = {}
    self.isActive = true
    self.isPaused = false
    self.playerStats = {
        hasMovedDistance = 0,
        harvestedResources = {},
        craftedItems = {},
        equippedTools = {},
        usedTools = {},
        discoveredResources = {},
        placedBuildings = 0
    }
    
    -- UI references
    self.overlayGui = nil
    self.highlightBox = nil
    self.tutorialPanel = nil
    
    -- Create tutorial UI
    self:createTutorialInterface()
    
    -- Connect events
    self:connectEvents()
    
    -- Load tutorial progress from server
    self:loadTutorialProgress()
    
    return self
end

function TutorialSystem:createTutorialInterface()
    -- Main tutorial overlay
    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "TutorialOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlayGui.Parent = playerGui
    self.overlayGui = overlayGui
    
    -- Semi-transparent background for focus
    local backgroundDimmer = Instance.new("Frame")
    backgroundDimmer.Name = "BackgroundDimmer"
    backgroundDimmer.Size = UDim2.new(1, 0, 1, 0)
    backgroundDimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backgroundDimmer.BackgroundTransparency = 0.7
    backgroundDimmer.BorderSizePixel = 0
    backgroundDimmer.Visible = false
    backgroundDimmer.ZIndex = TUTORIAL_Z_INDEX
    backgroundDimmer.Parent = overlayGui
    self.backgroundDimmer = backgroundDimmer
    
    -- Tutorial panel
    local tutorialPanel = Instance.new("Frame")
    tutorialPanel.Name = "TutorialPanel"
    tutorialPanel.Size = UDim2.new(0, 400, 0, 200)
    tutorialPanel.Position = UDim2.new(0.5, -200, 0.2, 0)
    tutorialPanel.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    tutorialPanel.BorderSizePixel = 0
    tutorialPanel.Visible = false
    tutorialPanel.ZIndex = TUTORIAL_Z_INDEX + 1
    tutorialPanel.Parent = overlayGui
    self.tutorialPanel = tutorialPanel
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = tutorialPanel
    
    -- Tutorial title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Tutorial Step"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = tutorialPanel
    self.titleLabel = titleLabel
    
    -- Tutorial description
    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "DescriptionLabel"
    descriptionLabel.Size = UDim2.new(1, -20, 1, -100)
    descriptionLabel.Position = UDim2.new(0, 10, 0, 50)
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.Text = "Tutorial description goes here..."
    descriptionLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    descriptionLabel.TextSize = 14
    descriptionLabel.Font = Enum.Font.Gotham
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
    descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    descriptionLabel.TextWrapped = true
    descriptionLabel.Parent = tutorialPanel
    self.descriptionLabel = descriptionLabel
    
    -- Control buttons frame
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, -20, 0, 40)
    buttonFrame.Position = UDim2.new(0, 10, 1, -50)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = tutorialPanel
    
    -- Skip button
    local skipButton = Instance.new("TextButton")
    skipButton.Name = "SkipButton"
    skipButton.Size = UDim2.new(0, 80, 1, 0)
    skipButton.Position = UDim2.new(0, 0, 0, 0)
    skipButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    skipButton.Text = "Skip"
    skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    skipButton.TextSize = 12
    skipButton.Font = Enum.Font.GothamBold
    skipButton.Parent = buttonFrame
    self.skipButton = skipButton
    
    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 6)
    skipCorner.Parent = skipButton
    
    -- Next/Continue button
    local continueButton = Instance.new("TextButton")
    continueButton.Name = "ContinueButton"
    continueButton.Size = UDim2.new(0, 100, 1, 0)
    continueButton.Position = UDim2.new(1, -100, 0, 0)
    continueButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    continueButton.Text = "Continue"
    continueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    continueButton.TextSize = 12
    continueButton.Font = Enum.Font.GothamBold
    continueButton.Parent = buttonFrame
    self.continueButton = continueButton
    
    local continueCorner = Instance.new("UICorner")
    continueCorner.CornerRadius = UDim.new(0, 6)
    continueCorner.Parent = continueButton
    
    -- Progress indicator
    local progressFrame = Instance.new("Frame")
    progressFrame.Name = "ProgressFrame"
    progressFrame.Size = UDim2.new(0, 200, 0, 8)
    progressFrame.Position = UDim2.new(0.5, -100, 0, 2)
    progressFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    progressFrame.BorderSizePixel = 0
    progressFrame.Parent = tutorialPanel
    
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(0.1, 0, 1, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressFrame
    self.progressBar = progressBar
    
    -- Highlight system for pointing to UI elements
    local highlightBox = Instance.new("Frame")
    highlightBox.Name = "HighlightBox"
    highlightBox.Size = UDim2.new(0, 100, 0, 100)
    highlightBox.BackgroundTransparency = 1
    highlightBox.BorderSizePixel = 4
    highlightBox.BorderColor3 = Color3.fromRGB(255, 255, 100)
    highlightBox.Visible = false
    highlightBox.ZIndex = TUTORIAL_Z_INDEX + 2
    highlightBox.Parent = overlayGui
    self.highlightBox = highlightBox
    
    -- Connect button events
    self:connectButtonEvents()
end

function TutorialSystem:connectButtonEvents()
    self.skipButton.MouseButton1Click:Connect(function()
        self:skipTutorial()
    end)
    
    self.continueButton.MouseButton1Click:Connect(function()
        self:advanceStep()
    end)
end

function TutorialSystem:connectEvents()
    -- Player movement tracking
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        self:trackPlayerMovement()
    else
        player.CharacterAdded:Connect(function()
            self:trackPlayerMovement()
        end)
    end
    
    -- Server tutorial progress updates
    if GetTutorialProgressEvent then
        GetTutorialProgressEvent.OnClientEvent:Connect(function(progressData)
            self:updateTutorialProgress(progressData)
        end)
    end
    
    -- Hook into other system events for progress tracking
    self:connectSystemHooks()
end

function TutorialSystem:connectSystemHooks()
    -- Hook into inventory system
    if playerGui:FindFirstChild("InventoryGUI") then
        local inventoryGui = playerGui.InventoryGUI
        local inventoryFrame = inventoryGui:FindFirstChild("InventoryFrame")
        
        if inventoryFrame then
            local connection
            connection = inventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if inventoryFrame.Visible then
                    self:onInventoryOpened()
                end
            end)
        end
    end
    
    -- Hook into crafting system  
    if playerGui:FindFirstChild("CraftingGUI") then
        local craftingGui = playerGui.CraftingGUI
        local craftingFrame = craftingGui:FindFirstChild("CraftingFrame")
        
        if craftingFrame then
            local connection
            connection = craftingFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if craftingFrame.Visible then
                    self:onCraftingOpened()
                end
            end)
        end
    end
    
    -- Listen for resource collection events
    if RemoteEvents:FindFirstChild("ResourceCollected") then
        RemoteEvents.ResourceCollected.OnClientEvent:Connect(function(resourceType, amount)
            self:onResourceCollected(resourceType, amount)
        end)
    end
    
    -- Listen for item crafted events
    if RemoteEvents:FindFirstChild("ItemCrafted") then
        RemoteEvents.ItemCrafted.OnClientEvent:Connect(function(itemType, quality)
            self:onItemCrafted(itemType, quality)
        end)
    end
    
    -- Listen for tool equipped events
    if RemoteEvents:FindFirstChild("ToolEquipped") then
        RemoteEvents.ToolEquipped.OnClientEvent:Connect(function(toolType)
            self:onToolEquipped(toolType)
        end)
    end
end

function TutorialSystem:trackPlayerMovement()
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart then
        local lastPosition = humanoidRootPart.Position
        
        game:GetService("RunService").Heartbeat:Connect(function()
            if humanoidRootPart.Parent then
                local currentPosition = humanoidRootPart.Position
                local distance = (currentPosition - lastPosition).Magnitude
                
                if distance > 0.1 then -- Threshold to avoid micro-movements
                    self.playerStats.hasMovedDistance = self.playerStats.hasMovedDistance + distance
                    lastPosition = currentPosition
                    self:checkStepCompletion()
                end
            end
        end)
    end
end

function TutorialSystem:loadTutorialProgress()
    if GetTutorialProgressEvent then
        GetTutorialProgressEvent:FireServer()
    end
end

function TutorialSystem:updateTutorialProgress(progressData)
    self.currentStep = progressData.currentStep or 1
    self.completedSteps = progressData.completedSteps or {}
    self.playerStats = progressData.playerStats or self.playerStats
    
    -- Update display
    self:updateCurrentStep()
end

function TutorialSystem:getCurrentStep()
    return TUTORIAL_STEPS[self.currentStep]
end

function TutorialSystem:updateCurrentStep()
    if not self.isActive or self.isPaused then return end
    
    local step = self:getCurrentStep()
    if not step then
        self:completeTutorial()
        return
    end
    
    -- Check if step condition is met
    if step.condition and not step.condition(self) then
        return -- Wait for condition
    end
    
    -- Show tutorial step
    self:showTutorialStep(step)
    
    -- Start checking for completion
    self:startStepCompletion(step)
end

function TutorialSystem:showTutorialStep(step)
    -- Update tutorial panel content
    self.titleLabel.Text = step.title
    self.descriptionLabel.Text = step.description
    
    -- Update progress bar
    local progress = self.currentStep / #TUTORIAL_STEPS
    local progressTween = TweenService:Create(self.progressBar,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(progress, 0, 1, 0)}
    )
    progressTween:Play()
    
    -- Show tutorial panel with animation
    self.backgroundDimmer.Visible = true
    self.tutorialPanel.Visible = true
    
    self.tutorialPanel.Position = UDim2.new(0.5, -200, 0.1, 0)
    self.tutorialPanel.BackgroundTransparency = 1
    self.titleLabel.TextTransparency = 1
    self.descriptionLabel.TextTransparency = 1
    
    local showTween = TweenService:Create(self.tutorialPanel,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, -200, 0.2, 0),
            BackgroundTransparency = 0
        }
    )
    showTween:Play()
    
    local textTween = TweenService:Create(self.titleLabel,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 0}
    )
    textTween:Play()
    
    local descTween = TweenService:Create(self.descriptionLabel,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 0}
    )
    descTween:Play()
    
    -- Handle special step types
    self:handleSpecialStepType(step)
end

function TutorialSystem:handleSpecialStepType(step)
    if step.type == "keypress" then
        self:highlightKeyPress(step.targetKey)
    elseif step.type == "interaction" and step.targetUI then
        self:highlightUIElement(step.targetUI)
    end
end

function TutorialSystem:highlightKeyPress(keyCode)
    -- Could create visual key press indicator
    -- For now, just pulse the continue button
    self:pulseElement(self.continueButton)
end

function TutorialSystem:highlightUIElement(targetUI)
    local targetGui = playerGui:FindFirstChild(targetUI)
    if targetGui then
        local targetFrame = targetGui:GetChildren()[1] -- Get first frame
        if targetFrame and targetFrame:IsA("GuiObject") then
            -- Position highlight box over target
            self.highlightBox.Size = UDim2.new(0, targetFrame.AbsoluteSize.X + 20, 0, targetFrame.AbsoluteSize.Y + 20)
            self.highlightBox.Position = UDim2.new(0, targetFrame.AbsolutePosition.X - 10, 0, targetFrame.AbsolutePosition.Y - 10)
            self.highlightBox.Visible = true
            
            -- Pulse animation
            self:pulseElement(self.highlightBox)
        end
    end
end

function TutorialSystem:pulseElement(element)
    local pulseTween = TweenService:Create(element,
        TweenInfo.new(HIGHLIGHT_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BorderTransparency = 0.2}
    )
    pulseTween:Play()
end

function TutorialSystem:startStepCompletion(step)
    -- Start checking for step completion conditions
    game:GetService("RunService").Heartbeat:Connect(function()
        if self:checkStepCompletion(step) then
            self:completeCurrentStep()
        end
    end)
end

function TutorialSystem:checkStepCompletion(step)
    local currentStep = step or self:getCurrentStep()
    if not currentStep or not currentStep.completion then return false end
    
    return currentStep.completion(self)
end

function TutorialSystem:completeCurrentStep()
    local step = self:getCurrentStep()
    if not step then return end
    
    -- Mark step as completed
    self.completedSteps[step.id] = true
    
    -- Send completion to server
    if CompleteTutorialStepEvent then
        CompleteTutorialStepEvent:FireServer(step.id, self.playerStats)
    end
    
    -- Hide current tutorial UI
    self:hideTutorialPanel()
    
    -- Advance to next step
    task.wait(1) -- Brief pause
    self:advanceStep()
end

function TutorialSystem:advanceStep()
    self.currentStep = self.currentStep + 1
    self:hideTutorialPanel()
    
    task.wait(0.5)
    self:updateCurrentStep()
end

function TutorialSystem:hideTutorialPanel()
    self.highlightBox.Visible = false
    
    local hideTween = TweenService:Create(self.tutorialPanel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Position = UDim2.new(0.5, -200, 0.1, 0),
            BackgroundTransparency = 1
        }
    )
    hideTween:Play()
    
    hideTween.Completed:Connect(function()
        self.tutorialPanel.Visible = false
        self.backgroundDimmer.Visible = false
    end)
end

function TutorialSystem:skipTutorial()
    self.isActive = false
    self:hideTutorialPanel()
    
    -- Send skip event to server
    if UpdateTutorialProgressEvent then
        UpdateTutorialProgressEvent:FireServer("skipped")
    end
end

function TutorialSystem:completeTutorial()
    self.isActive = false
    self:hideTutorialPanel()
    
    -- Show completion message
    self:showCompletionMessage()
    
    -- Send completion to server
    if UpdateTutorialProgressEvent then
        UpdateTutorialProgressEvent:FireServer("completed")
    end
end

function TutorialSystem:showCompletionMessage()
    -- Create completion celebration
    local completionGui = Instance.new("ScreenGui")
    completionGui.Name = "TutorialCompletion"
    completionGui.Parent = playerGui
    
    local completionLabel = Instance.new("TextLabel")
    completionLabel.Size = UDim2.new(0, 400, 0, 100)
    completionLabel.Position = UDim2.new(0.5, -200, 0.5, -50)
    completionLabel.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    completionLabel.Text = "🎉 Tutorial Complete! 🎉\nEnjoy exploring AquaticMetropolis!"
    completionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    completionLabel.TextSize = 20
    completionLabel.Font = Enum.Font.GothamBold
    completionLabel.Parent = completionGui
    
    local completionCorner = Instance.new("UICorner")
    completionCorner.CornerRadius = UDim.new(0, 15)
    completionCorner.Parent = completionLabel
    
    -- Animate completion message
    completionLabel.BackgroundTransparency = 1
    completionLabel.TextTransparency = 1
    
    local showTween = TweenService:Create(completionLabel,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0, TextTransparency = 0}
    )
    showTween:Play()
    
    -- Auto-remove after delay
    task.wait(5)
    completionGui:Destroy()
end

-- Event handlers for tracking player progress
function TutorialSystem:onInventoryOpened()
    if self:isCurrentStep("open_inventory") then
        self:completeCurrentStep()
    end
end

function TutorialSystem:onCraftingOpened()
    if self:isCurrentStep("open_crafting") then
        self:completeCurrentStep()
    end
end

function TutorialSystem:onResourceCollected(resourceType, amount)
    self.playerStats.harvestedResources[resourceType] = (self.playerStats.harvestedResources[resourceType] or 0) + amount
    
    if not self.playerStats.discoveredResources[resourceType] then
        self.playerStats.discoveredResources[resourceType] = true
    end
end

function TutorialSystem:onItemCrafted(itemType, quality)
    self.playerStats.craftedItems[itemType] = (self.playerStats.craftedItems[itemType] or 0) + 1
end

function TutorialSystem:onToolEquipped(toolType)
    self.playerStats.equippedTools[toolType] = true
end

-- Helper functions for step completion checks
function TutorialSystem:hasPlayerMoved()
    return self.playerStats.hasMovedDistance > 10
end

function TutorialSystem:hasHarvestedResource(resourceType)
    return (self.playerStats.harvestedResources[resourceType] or 0) > 0
end

function TutorialSystem:hasStaminaBelowPercent(percent)
    -- Would need to hook into stamina system for this
    return true -- Placeholder
end

function TutorialSystem:hasResource(resourceType, amount)
    return (self.playerStats.harvestedResources[resourceType] or 0) >= amount
end

function TutorialSystem:hasItem(itemType)
    return (self.playerStats.craftedItems[itemType] or 0) > 0
end

function TutorialSystem:hasEquippedTool(toolType)
    return self.playerStats.equippedTools[toolType] == true
end

function TutorialSystem:hasUsedTool(toolType)
    return self.playerStats.usedTools[toolType] == true
end

function TutorialSystem:hasDiscoveredResourceTypes(count)
    local discoveredCount = 0
    for _ in pairs(self.playerStats.discoveredResources) do
        discoveredCount = discoveredCount + 1
    end
    return discoveredCount >= count
end

function TutorialSystem:hasBuilding()
    return self.playerStats.placedBuildings > 0
end

function TutorialSystem:isStepCompleted(stepId)
    return self.completedSteps[stepId] == true
end

function TutorialSystem:isCurrentStep(stepId)
    local step = self:getCurrentStep()
    return step and step.id == stepId
end

-- Export the class
return TutorialSystem