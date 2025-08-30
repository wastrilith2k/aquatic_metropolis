--[[
MainUI.client.lua

Purpose: Main client-side UI controller for MVP
Dependencies: RemoteEvents
Last Modified: Phase 0 - Week 1

Features:
- Basic inventory display (5 slots)
- Resource counters
- Harvest feedback messages
- Tutorial hints
]]--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remote events
local initializeUI = ReplicatedStorage:WaitForChild("InitializeUI")
local harvestSuccess = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("HarvestSuccess")
local harvestFailure = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("HarvestFailure")

-- UI state
local currentPlayerData = nil
local mainGui = nil

-- Initialize UI when player data is received
initializeUI.OnClientEvent:Connect(function(playerData)
    currentPlayerData = playerData
    createMainInterface()
    updateInventoryDisplay()
    
    if not playerData.tutorial.completed then
        showTutorialHint("Welcome to AquaticMetropolis! Click on glowing resources to harvest them.")
    end
end)

-- Handle successful harvests
harvestSuccess.OnClientEvent:Connect(function(harvestResult)
    showHarvestMessage("+" .. harvestResult.amount .. " " .. harvestResult.displayName, Color3.fromRGB(0, 255, 0))
    
    -- Update local inventory count (will be confirmed by server)
    if currentPlayerData then
        local resourceType = harvestResult.resourceType
        currentPlayerData.inventory[resourceType] = (currentPlayerData.inventory[resourceType] or 0) + harvestResult.amount
        updateInventoryDisplay()
    end
end)

-- Handle failed harvests
harvestFailure.OnClientEvent:Connect(function(errorMessage)
    showHarvestMessage(errorMessage, Color3.fromRGB(255, 100, 100))
end)

function createMainInterface()
    if mainGui then
        mainGui:Destroy()
    end
    
    -- Main screen GUI
    mainGui = Instance.new("ScreenGui")
    mainGui.Name = "AquaticMetropolisUI"
    mainGui.ResetOnSpawn = false
    mainGui.DisplayOrder = 100
    mainGui.Parent = playerGui
    
    -- Create UI elements
    createInventoryPanel()
    createResourceCounters()
    createMessageArea()
    createTutorialArea()
    
    print("✅ Main UI created")
end

function createInventoryPanel()
    local inventoryFrame = Instance.new("Frame")
    inventoryFrame.Name = "InventoryPanel"
    inventoryFrame.Size = UDim2.new(0, 320, 0, 120)
    inventoryFrame.Position = UDim2.new(0, 20, 1, -140)
    inventoryFrame.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
    inventoryFrame.BackgroundTransparency = 0.2
    inventoryFrame.BorderSizePixel = 0
    inventoryFrame.Parent = mainGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = inventoryFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 25)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🎒 Inventory (5 slots)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = inventoryFrame
    
    -- Inventory slots container
    local slotsFrame = Instance.new("Frame")
    slotsFrame.Name = "SlotsFrame"
    slotsFrame.Size = UDim2.new(1, -20, 1, -35)
    slotsFrame.Position = UDim2.new(0, 10, 0, 30)
    slotsFrame.BackgroundTransparency = 1
    slotsFrame.Parent = inventoryFrame
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 50, 0, 50)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 5)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = slotsFrame
    
    -- Create 5 inventory slots
    for i = 1, 5 do
        createInventorySlot(i, slotsFrame)
    end
end

function createInventorySlot(slotNumber, parent)
    local slot = Instance.new("Frame")
    slot.Name = "Slot_" .. slotNumber
    slot.LayoutOrder = slotNumber
    slot.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
    slot.BorderSizePixel = 1
    slot.BorderColor3 = Color3.fromRGB(100, 150, 200)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = slot
    
    -- Item icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 0.65, 0)
    icon.Position = UDim2.new(0, 0, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.Parent = slot
    
    -- Item count
    local count = Instance.new("TextLabel")
    count.Name = "Count"
    count.Size = UDim2.new(1, 0, 0.35, 0)
    count.Position = UDim2.new(0, 0, 0.65, 0)
    count.BackgroundTransparency = 1
    count.Text = ""
    count.TextColor3 = Color3.fromRGB(200, 200, 200)
    count.TextScaled = true
    count.Font = Enum.Font.Gotham
    count.Parent = slot
    
    slot.Parent = parent
    return slot
end

function createResourceCounters()
    local counterFrame = Instance.new("Frame")
    counterFrame.Name = "ResourceCounters"
    counterFrame.Size = UDim2.new(0, 180, 0, 80)
    counterFrame.Position = UDim2.new(1, -200, 0, 20)
    counterFrame.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
    counterFrame.BackgroundTransparency = 0.3
    counterFrame.BorderSizePixel = 0
    counterFrame.Parent = mainGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = counterFrame
    
    -- Resource displays
    local resources = {
        {name = "Kelp", icon = "🌿", color = Color3.fromRGB(50, 150, 50)},
        {name = "Rock", icon = "🪨", color = Color3.fromRGB(120, 120, 120)},
        {name = "Pearl", icon = "⚪", color = Color3.fromRGB(255, 255, 200)}
    }
    
    for i, resource in ipairs(resources) do
        local counter = Instance.new("TextLabel")
        counter.Name = resource.name .. "Counter"
        counter.Size = UDim2.new(1, -10, 0, 22)
        counter.Position = UDim2.new(0, 5, 0, (i-1) * 25 + 5)
        counter.BackgroundTransparency = 1
        counter.Text = resource.icon .. " " .. resource.name .. ": 0"
        counter.TextColor3 = resource.color
        counter.TextScaled = true
        counter.Font = Enum.Font.Gotham
        counter.TextXAlignment = Enum.TextXAlignment.Left
        counter.Parent = counterFrame
    end
end

function createMessageArea()
    local messageFrame = Instance.new("Frame")
    messageFrame.Name = "MessageArea"
    messageFrame.Size = UDim2.new(0, 300, 0, 50)
    messageFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
    messageFrame.BackgroundTransparency = 1
    messageFrame.Parent = mainGui
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "MessageLabel"
    messageLabel.Size = UDim2.new(1, 0, 1, 0)
    messageLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    messageLabel.BackgroundTransparency = 0.3
    messageLabel.BorderSizePixel = 0
    messageLabel.Text = ""
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextScaled = true
    messageLabel.Font = Enum.Font.GothamBold
    messageLabel.Visible = false
    messageLabel.Parent = messageFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = messageLabel
end

function createTutorialArea()
    local tutorialFrame = Instance.new("Frame")
    tutorialFrame.Name = "TutorialArea"
    tutorialFrame.Size = UDim2.new(0, 400, 0, 60)
    tutorialFrame.Position = UDim2.new(0.5, -200, 0, 20)
    tutorialFrame.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
    tutorialFrame.BackgroundTransparency = 0.2
    tutorialFrame.BorderSizePixel = 0
    tutorialFrame.Visible = false
    tutorialFrame.Parent = mainGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = tutorialFrame
    
    local tutorialLabel = Instance.new("TextLabel")
    tutorialLabel.Name = "TutorialLabel"
    tutorialLabel.Size = UDim2.new(1, -20, 1, -10)
    tutorialLabel.Position = UDim2.new(0, 10, 0, 5)
    tutorialLabel.BackgroundTransparency = 1
    tutorialLabel.Text = ""
    tutorialLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    tutorialLabel.TextScaled = true
    tutorialLabel.Font = Enum.Font.Gotham
    tutorialLabel.TextWrapped = true
    tutorialLabel.Parent = tutorialFrame
end

function updateInventoryDisplay()
    if not currentPlayerData or not mainGui then return end
    
    local inventoryPanel = mainGui:FindFirstChild("InventoryPanel")
    if not inventoryPanel then return end
    
    local slotsFrame = inventoryPanel:FindFirstChild("SlotsFrame")
    if not slotsFrame then return end
    
    -- Clear all slots
    for i = 1, 5 do
        local slot = slotsFrame:FindFirstChild("Slot_" .. i)
        if slot then
            slot.Icon.Text = ""
            slot.Count.Text = ""
            slot.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
        end
    end
    
    -- Update resource counters
    local counterFrame = mainGui:FindFirstChild("ResourceCounters")
    if counterFrame then
        local kelpCounter = counterFrame:FindFirstChild("KelpCounter")
        local rockCounter = counterFrame:FindFirstChild("RockCounter")
        local pearlCounter = counterFrame:FindFirstChild("PearlCounter")
        
        if kelpCounter then kelpCounter.Text = "🌿 Kelp: " .. (currentPlayerData.inventory.Kelp or 0) end
        if rockCounter then rockCounter.Text = "🪨 Rock: " .. (currentPlayerData.inventory.Rock or 0) end
        if pearlCounter then pearlCounter.Text = "⚪ Pearl: " .. (currentPlayerData.inventory.Pearl or 0) end
    end
    
    -- Fill inventory slots
    local slotIndex = 1
    local resourceIcons = {Kelp = "🌿", Rock = "🪨", Pearl = "⚪"}
    local resourceColors = {
        Kelp = Color3.fromRGB(80, 150, 80),
        Rock = Color3.fromRGB(120, 120, 120),
        Pearl = Color3.fromRGB(200, 200, 150)
    }
    
    for resourceType, count in pairs(currentPlayerData.inventory) do
        if count > 0 and slotIndex <= 5 then
            local slot = slotsFrame:FindFirstChild("Slot_" .. slotIndex)
            if slot then
                slot.Icon.Text = resourceIcons[resourceType] or "❓"
                slot.Count.Text = tostring(count)
                slot.BackgroundColor3 = resourceColors[resourceType] or Color3.fromRGB(100, 100, 100)
                slotIndex = slotIndex + 1
            end
        end
    end
end

function showHarvestMessage(message, color)
    if not mainGui then return end
    
    local messageArea = mainGui:FindFirstChild("MessageArea")
    if not messageArea then return end
    
    local messageLabel = messageArea:FindFirstChild("MessageLabel")
    if not messageLabel then return end
    
    messageLabel.Text = message
    messageLabel.TextColor3 = color
    messageLabel.Visible = true
    
    -- Animate message
    messageLabel.Size = UDim2.new(0, 0, 1, 0)
    local expandTween = TweenService:Create(messageLabel, TweenInfo.new(0.3), {
        Size = UDim2.new(1, 0, 1, 0)
    })
    
    expandTween:Play()
    
    -- Hide after 2 seconds
    delay(2, function()
        local fadeTween = TweenService:Create(messageLabel, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
            TextTransparency = 1
        })
        
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            messageLabel.Visible = false
            messageLabel.BackgroundTransparency = 0.3
            messageLabel.TextTransparency = 0
        end)
    end)
end

function showTutorialHint(message)
    if not mainGui then return end
    
    local tutorialArea = mainGui:FindFirstChild("TutorialArea")
    if not tutorialArea then return end
    
    local tutorialLabel = tutorialArea:FindFirstChild("TutorialLabel")
    if not tutorialLabel then return end
    
    tutorialLabel.Text = "💡 " .. message
    tutorialArea.Visible = true
    
    -- Auto-hide after 10 seconds
    delay(10, function()
        if tutorialArea then
            tutorialArea.Visible = false
        end
    end)
end

print("✅ Main UI client script loaded")