--[[
PlayerHUD.lua

Purpose: Player HUD with tool durability and stamina bars for Week 4
Dependencies: StaminaSystem, ToolSystem (via RemoteEvents)
Last Modified: Phase 0 - Week 4
Performance Notes: Optimized with efficient update cycles and minimal UI recreation

Features:
- Real-time stamina bar with status effects
- Tool durability indicators for equipped tools
- Resource collection notifications
- Status effect indicators with icons
- Compact layout for minimal screen space usage
- Smooth animations and visual feedback
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

-- Module dependencies
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local StaminaConfig = require(SharedModules:WaitForChild("StaminaConfig"))

-- Remote event references
local StaminaUpdateEvent = RemoteEvents:WaitForChild("StaminaUpdate")
local ToolUpdateEvent = RemoteEvents:WaitForChild("ToolUpdate")
local ResourceCollectedEvent = RemoteEvents:WaitForChild("ResourceCollected")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PlayerHUD = {}
PlayerHUD.__index = PlayerHUD

-- Constants
local HUD_UPDATE_RATE = 0.1
local ANIMATION_TIME = 0.3
local NOTIFICATION_DURATION = 3.0

-- Status effect colors matching StaminaConfig
local STATUS_COLORS = {
    energized = Color3.fromRGB(100, 255, 100),
    good = Color3.fromRGB(150, 255, 150),
    tired = Color3.fromRGB(255, 255, 100),
    exhausted = Color3.fromRGB(255, 150, 100),
    depleted = Color3.fromRGB(255, 100, 100)
}

function PlayerHUD.new()
    local self = setmetatable({}, PlayerHUD)
    
    -- State management
    self.currentStamina = 100
    self.maxStamina = 100
    self.staminaPercent = 1.0
    self.statusEffect = "good"
    self.equippedTools = {}
    self.notifications = {}
    
    -- Update tracking
    self.lastUpdate = 0
    
    -- Create main HUD
    self:createHUDInterface()
    
    -- Connect events
    self:connectEvents()
    
    -- Start update cycle
    self:startUpdateCycle()
    
    return self
end

function PlayerHUD:createHUDInterface()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlayerHUD"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui
    self.screenGui = screenGui
    
    -- Main HUD frame
    local hudFrame = Instance.new("Frame")
    hudFrame.Name = "HUDFrame"
    hudFrame.Size = UDim2.new(0, 300, 0, 120)
    hudFrame.Position = UDim2.new(0, 20, 1, -140)
    hudFrame.BackgroundTransparency = 1
    hudFrame.Parent = screenGui
    self.hudFrame = hudFrame
    
    -- Create stamina display
    self:createStaminaDisplay()
    
    -- Create tool durability display
    self:createToolDisplay()
    
    -- Create status effect indicator
    self:createStatusDisplay()
    
    -- Create notification area
    self:createNotificationArea()
end

function PlayerHUD:createStaminaDisplay()
    -- Stamina frame
    local staminaFrame = Instance.new("Frame")
    staminaFrame.Name = "StaminaFrame"
    staminaFrame.Size = UDim2.new(1, 0, 0, 35)
    staminaFrame.Position = UDim2.new(0, 0, 0, 0)
    staminaFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    staminaFrame.BackgroundTransparency = 0.2
    staminaFrame.BorderSizePixel = 0
    staminaFrame.Parent = self.hudFrame
    self.staminaFrame = staminaFrame
    
    -- Add corner rounding
    local staminaCorner = Instance.new("UICorner")
    staminaCorner.CornerRadius = UDim.new(0, 6)
    staminaCorner.Parent = staminaFrame
    
    -- Stamina icon
    local staminaIcon = Instance.new("TextLabel")
    staminaIcon.Name = "StaminaIcon"
    staminaIcon.Size = UDim2.new(0, 30, 1, 0)
    staminaIcon.Position = UDim2.new(0, 0, 0, 0)
    staminaIcon.BackgroundTransparency = 1
    staminaIcon.Text = "⚡"
    staminaIcon.TextColor3 = Color3.fromRGB(255, 255, 100)
    staminaIcon.TextSize = 18
    staminaIcon.Font = Enum.Font.GothamBold
    staminaIcon.Parent = staminaFrame
    self.staminaIcon = staminaIcon
    
    -- Stamina bar background
    local staminaBarBG = Instance.new("Frame")
    staminaBarBG.Name = "StaminaBarBG"
    staminaBarBG.Size = UDim2.new(1, -90, 0, 12)
    staminaBarBG.Position = UDim2.new(0, 35, 0.5, -6)
    staminaBarBG.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    staminaBarBG.BorderSizePixel = 0
    staminaBarBG.Parent = staminaFrame
    
    local staminaBarCorner = Instance.new("UICorner")
    staminaBarCorner.CornerRadius = UDim.new(0, 6)
    staminaBarCorner.Parent = staminaBarBG
    
    -- Stamina bar fill
    local staminaBar = Instance.new("Frame")
    staminaBar.Name = "StaminaBar"
    staminaBar.Size = UDim2.new(1, 0, 1, 0)
    staminaBar.Position = UDim2.new(0, 0, 0, 0)
    staminaBar.BackgroundColor3 = STATUS_COLORS.good
    staminaBar.BorderSizePixel = 0
    staminaBar.Parent = staminaBarBG
    self.staminaBar = staminaBar
    
    local staminaFillCorner = Instance.new("UICorner")
    staminaFillCorner.CornerRadius = UDim.new(0, 6)
    staminaFillCorner.Parent = staminaBar
    
    -- Stamina text
    local staminaText = Instance.new("TextLabel")
    staminaText.Name = "StaminaText"
    staminaText.Size = UDim2.new(0, 50, 1, 0)
    staminaText.Position = UDim2.new(1, -55, 0, 0)
    staminaText.BackgroundTransparency = 1
    staminaText.Text = "100/100"
    staminaText.TextColor3 = Color3.fromRGB(255, 255, 255)
    staminaText.TextSize = 12
    staminaText.Font = Enum.Font.Gotham
    staminaText.Parent = staminaFrame
    self.staminaText = staminaText
end

function PlayerHUD:createToolDisplay()
    -- Tool frame
    local toolFrame = Instance.new("Frame")
    toolFrame.Name = "ToolFrame"
    toolFrame.Size = UDim2.new(1, 0, 0, 35)
    toolFrame.Position = UDim2.new(0, 0, 0, 40)
    toolFrame.BackgroundTransparency = 1
    toolFrame.Parent = self.hudFrame
    self.toolFrame = toolFrame
    
    -- Tool slots container
    local toolContainer = Instance.new("Frame")
    toolContainer.Name = "ToolContainer"
    toolContainer.Size = UDim2.new(1, 0, 1, 0)
    toolContainer.BackgroundTransparency = 1
    toolContainer.Parent = toolFrame
    self.toolContainer = toolContainer
    
    -- Tool layout
    local toolLayout = Instance.new("UIListLayout")
    toolLayout.FillDirection = Enum.FillDirection.Horizontal
    toolLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    toolLayout.Padding = UDim.new(0, 5)
    toolLayout.Parent = toolContainer
end

function PlayerHUD:createStatusDisplay()
    -- Status effect frame
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(0, 120, 0, 30)
    statusFrame.Position = UDim2.new(1, -125, 0, 0)
    statusFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    statusFrame.BackgroundTransparency = 0.2
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = self.hudFrame
    self.statusFrame = statusFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusFrame
    
    -- Status icon
    local statusIcon = Instance.new("TextLabel")
    statusIcon.Name = "StatusIcon"
    statusIcon.Size = UDim2.new(0, 25, 1, 0)
    statusIcon.Position = UDim2.new(0, 5, 0, 0)
    statusIcon.BackgroundTransparency = 1
    statusIcon.Text = "👍"
    statusIcon.TextSize = 16
    statusIcon.Font = Enum.Font.GothamBold
    statusIcon.Parent = statusFrame
    self.statusIcon = statusIcon
    
    -- Status text
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, -35, 1, 0)
    statusText.Position = UDim2.new(0, 30, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Good"
    statusText.TextColor3 = STATUS_COLORS.good
    statusText.TextSize = 11
    statusText.Font = Enum.Font.GothamBold
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = statusFrame
    self.statusText = statusText
end

function PlayerHUD:createNotificationArea()
    -- Notification container
    local notificationContainer = Instance.new("Frame")
    notificationContainer.Name = "NotificationContainer"
    notificationContainer.Size = UDim2.new(0, 250, 0, 200)
    notificationContainer.Position = UDim2.new(1, -270, 0, 50)
    notificationContainer.BackgroundTransparency = 1
    notificationContainer.Parent = self.screenGui
    self.notificationContainer = notificationContainer
    
    -- Notification layout
    local notificationLayout = Instance.new("UIListLayout")
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notificationLayout.Padding = UDim.new(0, 5)
    notificationLayout.Parent = notificationContainer
end

function PlayerHUD:connectEvents()
    -- Stamina updates
    if StaminaUpdateEvent then
        StaminaUpdateEvent.OnClientEvent:Connect(function(staminaData)
            self:updateStamina(staminaData)
        end)
    end
    
    -- Tool updates
    if ToolUpdateEvent then
        ToolUpdateEvent.OnClientEvent:Connect(function(toolData)
            self:updateTools(toolData)
        end)
    end
    
    -- Resource collection notifications
    if ResourceCollectedEvent then
        ResourceCollectedEvent.OnClientEvent:Connect(function(resourceType, amount, quality)
            self:showResourceNotification(resourceType, amount, quality)
        end)
    end
end

function PlayerHUD:startUpdateCycle()
    -- Start heartbeat connection for smooth updates
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - self.lastUpdate > HUD_UPDATE_RATE then
            self:updateDisplay()
            self:updateNotifications(currentTime)
            self.lastUpdate = currentTime
        end
    end)
end

function PlayerHUD:updateStamina(staminaData)
    self.currentStamina = staminaData.current or self.currentStamina
    self.maxStamina = staminaData.max or self.maxStamina
    self.staminaPercent = self.currentStamina / self.maxStamina
    self.statusEffect = staminaData.statusEffect or "good"
end

function PlayerHUD:updateTools(toolData)
    self.equippedTools = toolData or {}
    self:updateToolDisplay()
end

function PlayerHUD:updateDisplay()
    -- Update stamina bar
    local targetSize = UDim2.new(self.staminaPercent, 0, 1, 0)
    local staminaColor = STATUS_COLORS[self.statusEffect] or STATUS_COLORS.good
    
    -- Smooth bar animation
    local barTween = TweenService:Create(self.staminaBar,
        TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Size = targetSize, BackgroundColor3 = staminaColor}
    )
    barTween:Play()
    
    -- Update stamina text
    self.staminaText.Text = math.floor(self.currentStamina) .. "/" .. self.maxStamina
    
    -- Update status display
    self:updateStatusDisplay()
end

function PlayerHUD:updateStatusDisplay()
    local statusData = StaminaConfig:GetStatusEffect(self.staminaPercent)
    
    if statusData then
        self.statusIcon.Text = statusData.icon or "👍"
        self.statusText.Text = statusData.displayName or "Good"
        self.statusText.TextColor3 = statusData.color or STATUS_COLORS.good
    end
end

function PlayerHUD:updateToolDisplay()
    -- Clear existing tool displays
    for _, child in pairs(self.toolContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Create new tool durability displays
    for toolType, toolData in pairs(self.equippedTools) do
        self:createToolDurabilitySlot(toolType, toolData)
    end
end

function PlayerHUD:createToolDurabilitySlot(toolType, toolData)
    -- Tool slot frame
    local toolSlot = Instance.new("Frame")
    toolSlot.Name = "Tool_" .. toolType
    toolSlot.Size = UDim2.new(0, 80, 1, 0)
    toolSlot.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    toolSlot.BackgroundTransparency = 0.2
    toolSlot.BorderSizePixel = 0
    toolSlot.Parent = self.toolContainer
    
    local toolCorner = Instance.new("UICorner")
    toolCorner.CornerRadius = UDim.new(0, 4)
    toolCorner.Parent = toolSlot
    
    -- Tool icon
    local toolIcon = Instance.new("ImageLabel")
    toolIcon.Name = "ToolIcon"
    toolIcon.Size = UDim2.new(0, 20, 0, 20)
    toolIcon.Position = UDim2.new(0, 3, 0, 3)
    toolIcon.BackgroundTransparency = 1
    toolIcon.Image = self:getToolIcon(toolType)
    toolIcon.Parent = toolSlot
    
    -- Tool name (abbreviated)
    local toolName = Instance.new("TextLabel")
    toolName.Name = "ToolName"
    toolName.Size = UDim2.new(1, -28, 0, 12)
    toolName.Position = UDim2.new(0, 25, 0, 2)
    toolName.BackgroundTransparency = 1
    toolName.Text = self:getToolDisplayName(toolType)
    toolName.TextColor3 = Color3.fromRGB(255, 255, 255)
    toolName.TextSize = 8
    toolName.Font = Enum.Font.Gotham
    toolName.TextXAlignment = Enum.TextXAlignment.Left
    toolName.TextScaled = true
    toolName.Parent = toolSlot
    
    -- Durability bar background
    local durabilityBG = Instance.new("Frame")
    durabilityBG.Name = "DurabilityBG"
    durabilityBG.Size = UDim2.new(1, -28, 0, 8)
    durabilityBG.Position = UDim2.new(0, 25, 0, 15)
    durabilityBG.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    durabilityBG.BorderSizePixel = 0
    durabilityBG.Parent = toolSlot
    
    local durabilityCorner = Instance.new("UICorner")
    durabilityCorner.CornerRadius = UDim.new(0, 4)
    durabilityCorner.Parent = durabilityBG
    
    -- Durability bar fill
    local durabilityBar = Instance.new("Frame")
    durabilityBar.Name = "DurabilityBar"
    durabilityBar.Size = UDim2.new(0.8, 0, 1, 0) -- Default 80%
    durabilityBar.Position = UDim2.new(0, 0, 0, 0)
    durabilityBar.BackgroundColor3 = self:getDurabilityColor(0.8)
    durabilityBar.BorderSizePixel = 0
    durabilityBar.Parent = durabilityBG
    
    local durabilityFillCorner = Instance.new("UICorner")
    durabilityFillCorner.CornerRadius = UDim.new(0, 4)
    durabilityFillCorner.Parent = durabilityBar
    
    -- Durability text
    local durabilityText = Instance.new("TextLabel")
    durabilityText.Name = "DurabilityText"
    durabilityText.Size = UDim2.new(1, -3, 0, 8)
    durabilityText.Position = UDim2.new(0, 3, 0, 25)
    durabilityText.BackgroundTransparency = 1
    durabilityText.Text = string.format("%d/%d", toolData.durability or 50, toolData.maxDurability or 50)
    durabilityText.TextColor3 = Color3.fromRGB(200, 200, 200)
    durabilityText.TextSize = 7
    durabilityText.Font = Enum.Font.Gotham
    durabilityText.TextXAlignment = Enum.TextXAlignment.Left
    durabilityText.Parent = toolSlot
    
    -- Update durability display
    if toolData.durability and toolData.maxDurability then
        local durabilityRatio = toolData.durability / toolData.maxDurability
        durabilityBar.Size = UDim2.new(durabilityRatio, 0, 1, 0)
        durabilityBar.BackgroundColor3 = self:getDurabilityColor(durabilityRatio)
        durabilityText.Text = string.format("%d/%d", toolData.durability, toolData.maxDurability)
    end
end

function PlayerHUD:showResourceNotification(resourceType, amount, quality)
    local notification = {
        text = "+" .. amount .. " " .. resourceType,
        color = quality and self:getQualityColor(quality) or Color3.fromRGB(255, 255, 255),
        time = tick(),
        duration = NOTIFICATION_DURATION
    }
    
    table.insert(self.notifications, notification)
    self:createNotificationFrame(notification)
end

function PlayerHUD:createNotificationFrame(notification)
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Name = "Notification_" .. tostring(tick())
    notificationFrame.Size = UDim2.new(0, 200, 0, 30)
    notificationFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    notificationFrame.BackgroundTransparency = 0.1
    notificationFrame.BorderSizePixel = 0
    notificationFrame.Parent = self.notificationContainer
    
    local notificationCorner = Instance.new("UICorner")
    notificationCorner.CornerRadius = UDim.new(0, 6)
    notificationCorner.Parent = notificationFrame
    
    -- Notification text
    local notificationText = Instance.new("TextLabel")
    notificationText.Name = "NotificationText"
    notificationText.Size = UDim2.new(1, -10, 1, 0)
    notificationText.Position = UDim2.new(0, 5, 0, 0)
    notificationText.BackgroundTransparency = 1
    notificationText.Text = notification.text
    notificationText.TextColor3 = notification.color
    notificationText.TextSize = 12
    notificationText.Font = Enum.Font.GothamBold
    notificationText.TextXAlignment = Enum.TextXAlignment.Left
    notificationText.Parent = notificationFrame
    
    -- Slide in animation
    notificationFrame.Position = UDim2.new(1, 0, 1, 0)
    local slideInTween = TweenService:Create(notificationFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 1, 0)}
    )
    slideInTween:Play()
    
    -- Store reference for cleanup
    notification.frame = notificationFrame
end

function PlayerHUD:updateNotifications(currentTime)
    -- Remove expired notifications
    for i = #self.notifications, 1, -1 do
        local notification = self.notifications[i]
        if currentTime - notification.time > notification.duration then
            if notification.frame then
                -- Fade out animation
                local fadeOutTween = TweenService:Create(notification.frame,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 1, Position = UDim2.new(1, 50, notification.frame.Position.Y.Scale, 0)}
                )
                fadeOutTween:Play()
                
                fadeOutTween.Completed:Connect(function()
                    notification.frame:Destroy()
                end)
            end
            table.remove(self.notifications, i)
        end
    end
end

-- Utility functions
function PlayerHUD:getToolIcon(toolType)
    -- Placeholder icon mapping
    local iconMap = {
        KelpTool = "rbxasset://textures/face.png",
        RockHammer = "rbxasset://textures/face.png",
        PearlNet = "rbxasset://textures/face.png"
    }
    return iconMap[toolType] or "rbxasset://textures/face.png"
end

function PlayerHUD:getToolDisplayName(toolType)
    local nameMap = {
        KelpTool = "Kelp Tool",
        RockHammer = "Hammer",
        PearlNet = "Net"
    }
    return nameMap[toolType] or toolType
end

function PlayerHUD:getDurabilityColor(ratio)
    if ratio > 0.7 then
        return Color3.fromRGB(100, 200, 100) -- Green
    elseif ratio > 0.3 then
        return Color3.fromRGB(255, 200, 100) -- Yellow
    else
        return Color3.fromRGB(200, 100, 100) -- Red
    end
end

function PlayerHUD:getQualityColor(quality)
    local qualityColors = {
        Basic = Color3.fromRGB(200, 200, 200),
        Good = Color3.fromRGB(100, 255, 100),
        Excellent = Color3.fromRGB(100, 150, 255),
        Perfect = Color3.fromRGB(255, 200, 100)
    }
    return qualityColors[quality] or Color3.fromRGB(255, 255, 255)
end

-- Export the class
return PlayerHUD