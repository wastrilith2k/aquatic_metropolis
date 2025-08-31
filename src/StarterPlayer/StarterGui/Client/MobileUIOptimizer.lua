--[[
MobileUIOptimizer.lua

Purpose: Week 7 mobile UI optimization system for touch interface enhancement
Dependencies: GuiService, UserInputService, TweenService
Last Modified: Phase 0 - Week 7

This system provides:
- Touch target sizing for accessibility compliance
- Gesture recognition for intuitive navigation
- Mobile-specific UI layouts for smaller screens
- Virtual joystick implementation for precise movement
- Responsive design scaling for various screen sizes
- Device capability detection and optimization
]]--

local MobileUIOptimizer = {}
MobileUIOptimizer.__index = MobileUIOptimizer

-- Services
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local MOBILE_CONFIG = {
    touchTargetSize = {
        minimum = UDim2.new(0, 44, 0, 44), -- iOS/Android accessibility minimum
        recommended = UDim2.new(0, 56, 0, 56), -- Material Design recommended
        toolbar = UDim2.new(0, 64, 0, 64) -- Toolbar buttons
    },
    
    deviceBreakpoints = {
        phone = {maxWidth = 600, maxHeight = 960},
        tablet = {maxWidth = 1200, maxHeight = 1600}
    },
    
    gestureThresholds = {
        swipeDistance = 50,
        pinchScale = 0.1,
        holdTime = 0.5,
        tapTimeout = 0.3
    },
    
    performance = {
        maxTweenDuration = 0.3,
        animationFramerate = 60,
        uiUpdateInterval = 0.016 -- 60 FPS
    }
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function MobileUIOptimizer.new()
    local self = setmetatable({}, MobileUIOptimizer)
    
    self.deviceInfo = self:detectDeviceCapabilities()
    self.currentLayout = "desktop" -- desktop, tablet, phone
    self.touchTargets = {}
    self.activeGestures = {}
    self.virtualJoystick = nil
    self.responsiveElements = {}
    
    self.gestureHandlers = {
        swipe = {},
        pinch = {},
        tap = {},
        hold = {}
    }
    
    self.performanceMetrics = {
        layoutSwitches = 0,
        gestureEvents = 0,
        touchTargetHits = 0,
        averageResponseTime = 0
    }
    
    self:initialize()
    
    return self
end

function MobileUIOptimizer:detectDeviceCapabilities()
    local touchEnabled = UserInputService.TouchEnabled
    local accelerometerEnabled = UserInputService.AccelerometerEnabled
    local gyroscopeEnabled = UserInputService.GyroscopeEnabled
    
    local screenSize = playerGui.AbsoluteSize
    local deviceType = "desktop"
    
    if touchEnabled then
        if screenSize.X <= MOBILE_CONFIG.deviceBreakpoints.phone.maxWidth then
            deviceType = "phone"
        elseif screenSize.X <= MOBILE_CONFIG.deviceBreakpoints.tablet.maxWidth then
            deviceType = "tablet"
        else
            deviceType = "desktop"
        end
    end
    
    return {
        deviceType = deviceType,
        screenSize = screenSize,
        touchEnabled = touchEnabled,
        accelerometerEnabled = accelerometerEnabled,
        gyroscopeEnabled = gyroscopeEnabled,
        safeArea = GuiService:GetGuiInset(),
        pixelDensity = self:calculatePixelDensity()
    }
end

function MobileUIOptimizer:calculatePixelDensity()
    local screenSize = playerGui.AbsoluteSize
    local baseSize = Vector2.new(1920, 1080) -- Reference resolution
    
    local scaleX = screenSize.X / baseSize.X
    local scaleY = screenSize.Y / baseSize.Y
    
    return math.min(scaleX, scaleY)
end

function MobileUIOptimizer:initialize()
    print("📱 Initializing Mobile UI Optimizer...")
    print("   Device Type:", self.deviceInfo.deviceType)
    print("   Screen Size:", self.deviceInfo.screenSize.X .. "x" .. self.deviceInfo.screenSize.Y)
    print("   Touch Enabled:", self.deviceInfo.touchEnabled)
    
    -- Apply initial layout based on device
    self:applyResponsiveLayout(self.deviceInfo.deviceType)
    
    -- Set up gesture recognition
    if self.deviceInfo.touchEnabled then
        self:setupGestureRecognition()
        self:createVirtualJoystick()
    end
    
    -- Monitor screen orientation changes
    self:setupOrientationMonitoring()
    
    -- Optimize existing UI elements
    self:optimizeExistingElements()
    
    print("✅ Mobile UI Optimizer initialized")
end

function MobileUIOptimizer:applyResponsiveLayout(deviceType)
    if self.currentLayout == deviceType then return end
    
    local startTime = tick()
    self.currentLayout = deviceType
    
    print("📐 Switching to", deviceType, "layout...")
    
    -- Apply layout-specific optimizations
    if deviceType == "phone" then
        self:applyPhoneLayout()
    elseif deviceType == "tablet" then
        self:applyTabletLayout()
    else
        self:applyDesktopLayout()
    end
    
    -- Update performance metrics
    self.performanceMetrics.layoutSwitches = self.performanceMetrics.layoutSwitches + 1
    local responseTime = tick() - startTime
    self:updateAverageResponseTime(responseTime)
    
    -- Notify other systems
    local event = playerGui:FindFirstChild("MobileLayoutChanged")
    if event then
        event:Fire(deviceType)
    end
end

function MobileUIOptimizer:applyPhoneLayout()
    -- Compact layout for small screens
    local inventoryFrame = playerGui:FindFirstChild("InventoryInterface")
    if inventoryFrame then
        local mainFrame = inventoryFrame:FindFirstChild("MainFrame")
        if mainFrame then
            mainFrame.Size = UDim2.new(0.95, 0, 0.8, 0)
            mainFrame.Position = UDim2.new(0.025, 0, 0.1, 0)
            
            -- Stack items vertically for phone
            local gridLayout = mainFrame:FindFirstChildOfClass("UIGridLayout")
            if gridLayout then
                gridLayout.CellSize = UDim2.new(0.45, 0, 0, 80)
                gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
            end
        end
    end
    
    -- Adjust HUD for small screens
    self:optimizeHUDForPhone()
    
    -- Create mobile-specific controls
    self:createMobileControls()
end

function MobileUIOptimizer:applyTabletLayout()
    -- Balanced layout for medium screens
    local inventoryFrame = playerGui:FindFirstChild("InventoryInterface")
    if inventoryFrame then
        local mainFrame = inventoryFrame:FindFirstChild("MainFrame")
        if mainFrame then
            mainFrame.Size = UDim2.new(0.7, 0, 0.8, 0)
            mainFrame.Position = UDim2.new(0.15, 0, 0.1, 0)
            
            -- Grid layout for tablet
            local gridLayout = mainFrame:FindFirstChildOfClass("UIGridLayout")
            if gridLayout then
                gridLayout.CellSize = UDim2.new(0.3, 0, 0, 100)
                gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
            end
        end
    end
    
    self:optimizeHUDForTablet()
end

function MobileUIOptimizer:applyDesktopLayout()
    -- Full layout for large screens
    local inventoryFrame = playerGui:FindFirstChild("InventoryInterface")
    if inventoryFrame then
        local mainFrame = inventoryFrame:FindFirstChild("MainFrame")
        if mainFrame then
            mainFrame.Size = UDim2.new(0.5, 0, 0.7, 0)
            mainFrame.Position = UDim2.new(0.25, 0, 0.15, 0)
            
            -- Standard grid for desktop
            local gridLayout = mainFrame:FindFirstChildOfClass("UIGridLayout")
            if gridLayout then
                gridLayout.CellSize = UDim2.new(0.2, 0, 0, 120)
                gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
            end
        end
    end
    
    -- Hide mobile controls on desktop
    self:hideMobileControls()
end

function MobileUIOptimizer:optimizeHUDForPhone()
    local hudFrame = playerGui:FindFirstChild("PlayerHUD")
    if not hudFrame then return end
    
    -- Compact HUD layout
    local staminaBar = hudFrame:FindFirstChild("StaminaBar")
    if staminaBar then
        staminaBar.Size = UDim2.new(0.3, 0, 0, 8)
        staminaBar.Position = UDim2.new(0.05, 0, 0.05, 0)
    end
    
    local toolInfo = hudFrame:FindFirstChild("ToolInfo")
    if toolInfo then
        toolInfo.Size = UDim2.new(0.4, 0, 0, 60)
        toolInfo.Position = UDim2.new(0.55, 0, 0.02, 0)
    end
    
    -- Stack elements vertically to save horizontal space
    self:applyVerticalHUDLayout(hudFrame)
end

function MobileUIOptimizer:optimizeHUDForTablet()
    local hudFrame = playerGui:FindFirstChild("PlayerHUD")
    if not hudFrame then return end
    
    -- Balanced HUD layout
    local staminaBar = hudFrame:FindFirstChild("StaminaBar")
    if staminaBar then
        staminaBar.Size = UDim2.new(0.25, 0, 0, 12)
        staminaBar.Position = UDim2.new(0.1, 0, 0.05, 0)
    end
    
    local toolInfo = hudFrame:FindFirstChild("ToolInfo")
    if toolInfo then
        toolInfo.Size = UDim2.new(0.3, 0, 0, 80)
        toolInfo.Position = UDim2.new(0.6, 0, 0.03, 0)
    end
end

function MobileUIOptimizer:setupGestureRecognition()
    print("✋ Setting up gesture recognition...")
    
    -- Track touch inputs for gesture detection
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.Touch then
            self:handleTouchBegan(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.Touch then
            self:handleTouchChanged(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.Touch then
            self:handleTouchEnded(input)
        end
    end)
end

function MobileUIOptimizer:handleTouchBegan(input)
    local touchId = tostring(input.KeyCode)
    local position = input.Position
    
    self.activeGestures[touchId] = {
        startPosition = position,
        currentPosition = position,
        startTime = tick(),
        moved = false,
        distance = 0
    }
    
    -- Check for touch target hits
    self:checkTouchTargets(position)
end

function MobileUIOptimizer:handleTouchChanged(input)
    local touchId = tostring(input.KeyCode)
    local gesture = self.activeGestures[touchId]
    
    if not gesture then return end
    
    gesture.currentPosition = input.Position
    gesture.distance = (input.Position - gesture.startPosition).Magnitude
    
    if gesture.distance > MOBILE_CONFIG.gestureThresholds.swipeDistance then
        gesture.moved = true
        self:processSwipeGesture(touchId, gesture)
    end
    
    -- Handle multi-touch pinch
    self:processPinchGesture()
end

function MobileUIOptimizer:handleTouchEnded(input)
    local touchId = tostring(input.KeyCode)
    local gesture = self.activeGestures[touchId]
    
    if not gesture then return end
    
    local duration = tick() - gesture.startTime
    
    -- Process tap or hold
    if not gesture.moved then
        if duration < MOBILE_CONFIG.gestureThresholds.tapTimeout then
            self:processTapGesture(gesture.startPosition)
        elseif duration >= MOBILE_CONFIG.gestureThresholds.holdTime then
            self:processHoldGesture(gesture.startPosition)
        end
    end
    
    self.activeGestures[touchId] = nil
    self.performanceMetrics.gestureEvents = self.performanceMetrics.gestureEvents + 1
end

function MobileUIOptimizer:createVirtualJoystick()
    if not self.deviceInfo.touchEnabled then return end
    if self.deviceInfo.deviceType == "desktop" then return end
    
    print("🕹️ Creating virtual joystick...")
    
    local joystickGui = Instance.new("ScreenGui")
    joystickGui.Name = "VirtualJoystick"
    joystickGui.ResetOnSpawn = false
    joystickGui.Parent = playerGui
    
    -- Joystick base
    local base = Instance.new("Frame")
    base.Name = "JoystickBase"
    base.Size = UDim2.new(0, 120, 0, 120)
    base.Position = UDim2.new(0, 50, 1, -170)
    base.BackgroundTransparency = 0.3
    base.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    base.BorderSizePixel = 0
    base.Parent = joystickGui
    
    local baseCorner = Instance.new("UICorner")
    baseCorner.CornerRadius = UDim.new(0.5, 0)
    baseCorner.Parent = base
    
    -- Joystick knob
    local knob = Instance.new("Frame")
    knob.Name = "JoystickKnob"
    knob.Size = UDim2.new(0, 50, 0, 50)
    knob.Position = UDim2.new(0.5, -25, 0.5, -25)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BackgroundTransparency = 0.1
    knob.BorderSizePixel = 0
    knob.Parent = base
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = knob
    
    self.virtualJoystick = {
        gui = joystickGui,
        base = base,
        knob = knob,
        isActive = false,
        centerPosition = UDim2.new(0.5, 0, 0.5, 0),
        maxRadius = 35
    }
    
    self:setupJoystickEvents()
end

function MobileUIOptimizer:setupJoystickEvents()
    if not self.virtualJoystick then return end
    
    local joystick = self.virtualJoystick
    
    joystick.base.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystick.isActive = true
            self:updateJoystickPosition(input.Position)
        end
    end)
    
    joystick.base.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and joystick.isActive then
            self:updateJoystickPosition(input.Position)
        end
    end)
    
    joystick.base.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystick.isActive = false
            self:resetJoystickPosition()
        end
    end)
end

function MobileUIOptimizer:updateJoystickPosition(touchPosition)
    if not self.virtualJoystick then return end
    
    local joystick = self.virtualJoystick
    local base = joystick.base
    local knob = joystick.knob
    
    -- Calculate relative position
    local baseCenter = base.AbsolutePosition + base.AbsoluteSize / 2
    local direction = touchPosition - baseCenter
    local distance = direction.Magnitude
    
    -- Constrain to circle
    if distance > joystick.maxRadius then
        direction = direction.Unit * joystick.maxRadius
        distance = joystick.maxRadius
    end
    
    -- Update knob position
    local newPosition = UDim2.new(0.5, direction.X - 25, 0.5, direction.Y - 25)
    knob.Position = newPosition
    
    -- Calculate movement vector (-1 to 1)
    local moveVector = direction / joystick.maxRadius
    
    -- Send movement to game systems
    self:handleVirtualJoystickInput(moveVector)
end

function MobileUIOptimizer:resetJoystickPosition()
    if not self.virtualJoystick then return end
    
    local knob = self.virtualJoystick.knob
    local tween = TweenService:Create(
        knob,
        TweenInfo.new(0.2, Enum.EasingStyle.Back),
        {Position = UDim2.new(0.5, -25, 0.5, -25)}
    )
    tween:Play()
    
    -- Stop movement
    self:handleVirtualJoystickInput(Vector2.new(0, 0))
end

function MobileUIOptimizer:handleVirtualJoystickInput(moveVector)
    -- Send movement input to character controller
    local remoteEvent = game.ReplicatedStorage:FindFirstChild("MobileMovement")
    if remoteEvent then
        remoteEvent:FireServer(moveVector)
    end
end

function MobileUIOptimizer:createMobileControls()
    if self.deviceInfo.deviceType == "desktop" then return end
    
    print("📲 Creating mobile-specific controls...")
    
    local controlsGui = Instance.new("ScreenGui")
    controlsGui.Name = "MobileControls"
    controlsGui.ResetOnSpawn = false
    controlsGui.Parent = playerGui
    
    -- Action buttons
    self:createActionButton(controlsGui, "InventoryButton", "📦", UDim2.new(1, -120, 0, 50), function()
        -- Toggle inventory
        local inventoryEvent = game.ReplicatedStorage:FindFirstChild("ToggleInventory")
        if inventoryEvent then
            inventoryEvent:FireServer()
        end
    end)
    
    self:createActionButton(controlsGui, "CraftingButton", "🔨", UDim2.new(1, -120, 0, 120), function()
        -- Toggle crafting
        local craftingEvent = game.ReplicatedStorage:FindFirstChild("ToggleCrafting")
        if craftingEvent then
            craftingEvent:FireServer()
        end
    end)
    
    self:createActionButton(controlsGui, "InteractButton", "👆", UDim2.new(1, -70, 1, -120), function()
        -- Interact with nearest resource
        local interactEvent = game.ReplicatedStorage:FindFirstChild("MobileInteract")
        if interactEvent then
            interactEvent:FireServer()
        end
    end)
end

function MobileUIOptimizer:createActionButton(parent, name, text, position, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = MOBILE_CONFIG.touchTargetSize.recommended
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    button.Text = text
    button.TextSize = 24
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = button
    
    -- Add touch target
    self:registerTouchTarget(button, callback)
    
    -- Add pressed animation
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local tween = TweenService:Create(
                button,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad),
                {BackgroundTransparency = 0.1, Size = button.Size * 1.05}
            )
            tween:Play()
        end
    end)
    
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local tween = TweenService:Create(
                button,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad),
                {BackgroundTransparency = 0.2, Size = MOBILE_CONFIG.touchTargetSize.recommended}
            )
            tween:Play()
        end
    end)
end

function MobileUIOptimizer:registerTouchTarget(element, callback)
    local targetData = {
        element = element,
        callback = callback,
        minSize = MOBILE_CONFIG.touchTargetSize.minimum,
        hitCount = 0
    }
    
    table.insert(self.touchTargets, targetData)
    
    -- Ensure minimum touch target size
    if element.Size.X.Offset < targetData.minSize.X.Offset or 
       element.Size.Y.Offset < targetData.minSize.Y.Offset then
        
        element.Size = UDim2.new(
            math.max(element.Size.X.Scale, targetData.minSize.X.Scale),
            math.max(element.Size.X.Offset, targetData.minSize.X.Offset),
            math.max(element.Size.Y.Scale, targetData.minSize.Y.Scale),
            math.max(element.Size.Y.Offset, targetData.minSize.Y.Offset)
        )
    end
end

function MobileUIOptimizer:checkTouchTargets(position)
    for _, target in ipairs(self.touchTargets) do
        local element = target.element
        if self:isPositionInElement(position, element) then
            target.hitCount = target.hitCount + 1
            self.performanceMetrics.touchTargetHits = self.performanceMetrics.touchTargetHits + 1
            
            if target.callback then
                target.callback()
            end
            break
        end
    end
end

function MobileUIOptimizer:isPositionInElement(position, element)
    local elemPos = element.AbsolutePosition
    local elemSize = element.AbsoluteSize
    
    return position.X >= elemPos.X and position.X <= elemPos.X + elemSize.X and
           position.Y >= elemPos.Y and position.Y <= elemPos.Y + elemSize.Y
end

function MobileUIOptimizer:setupOrientationMonitoring()
    -- Monitor screen size changes for orientation detection
    playerGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local newDeviceInfo = self:detectDeviceCapabilities()
        
        if newDeviceInfo.deviceType ~= self.deviceInfo.deviceType then
            self.deviceInfo = newDeviceInfo
            self:applyResponsiveLayout(newDeviceInfo.deviceType)
        end
    end)
end

function MobileUIOptimizer:optimizeExistingElements()
    print("🔧 Optimizing existing UI elements...")
    
    -- Scan all GUI elements and apply mobile optimizations
    local function optimizeGui(gui)
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("GuiObject") then
                self:optimizeGuiElement(child)
            end
            if child:IsA("Folder") or child:IsA("ScreenGui") or child:IsA("Frame") then
                optimizeGui(child)
            end
        end
    end
    
    optimizeGui(playerGui)
end

function MobileUIOptimizer:optimizeGuiElement(element)
    -- Apply mobile-friendly properties
    if element:IsA("TextButton") or element:IsA("ImageButton") then
        -- Ensure touch target compliance
        if element.Size.X.Offset < MOBILE_CONFIG.touchTargetSize.minimum.X.Offset then
            element.Size = UDim2.new(
                element.Size.X.Scale,
                MOBILE_CONFIG.touchTargetSize.minimum.X.Offset,
                element.Size.Y.Scale,
                math.max(element.Size.Y.Offset, MOBILE_CONFIG.touchTargetSize.minimum.Y.Offset)
            )
        end
        
        -- Add to touch targets
        self:registerTouchTarget(element)
    end
    
    if element:IsA("TextLabel") or element:IsA("TextButton") then
        -- Scale text for mobile readability
        if self.deviceInfo.deviceType == "phone" then
            element.TextSize = math.max(element.TextSize * 1.1, 14)
        end
    end
    
    -- Add responsive element for future layout changes
    table.insert(self.responsiveElements, element)
end

function MobileUIOptimizer:hideMobileControls()
    local mobileControls = playerGui:FindFirstChild("MobileControls")
    if mobileControls then
        mobileControls.Enabled = false
    end
    
    local virtualJoystick = playerGui:FindFirstChild("VirtualJoystick")
    if virtualJoystick then
        virtualJoystick.Enabled = false
    end
end

function MobileUIOptimizer:updateAverageResponseTime(newTime)
    local current = self.performanceMetrics.averageResponseTime
    local count = self.performanceMetrics.layoutSwitches
    
    self.performanceMetrics.averageResponseTime = ((current * (count - 1)) + newTime) / count
end

function MobileUIOptimizer:getPerformanceMetrics()
    return {
        deviceType = self.deviceInfo.deviceType,
        screenSize = self.deviceInfo.screenSize,
        currentLayout = self.currentLayout,
        layoutSwitches = self.performanceMetrics.layoutSwitches,
        gestureEvents = self.performanceMetrics.gestureEvents,
        touchTargetHits = self.performanceMetrics.touchTargetHits,
        averageResponseTime = self.performanceMetrics.averageResponseTime,
        activeTouchTargets = #self.touchTargets,
        responsiveElements = #self.responsiveElements
    }
end

function MobileUIOptimizer:processSwipeGesture(touchId, gesture)
    -- Implement swipe gesture logic
    local direction = (gesture.currentPosition - gesture.startPosition).Unit
    
    for _, handler in ipairs(self.gestureHandlers.swipe) do
        handler(direction, gesture.distance)
    end
end

function MobileUIOptimizer:processPinchGesture()
    -- Implement pinch gesture for zoom
    local touches = {}
    for id, gesture in pairs(self.activeGestures) do
        table.insert(touches, gesture)
    end
    
    if #touches == 2 then
        local distance = (touches[1].currentPosition - touches[2].currentPosition).Magnitude
        local initialDistance = (touches[1].startPosition - touches[2].startPosition).Magnitude
        
        if math.abs(distance - initialDistance) > MOBILE_CONFIG.gestureThresholds.pinchScale then
            local scale = distance / initialDistance
            
            for _, handler in ipairs(self.gestureHandlers.pinch) do
                handler(scale)
            end
        end
    end
end

function MobileUIOptimizer:processTapGesture(position)
    for _, handler in ipairs(self.gestureHandlers.tap) do
        handler(position)
    end
end

function MobileUIOptimizer:processHoldGesture(position)
    for _, handler in ipairs(self.gestureHandlers.hold) do
        handler(position)
    end
end

function MobileUIOptimizer:applyVerticalHUDLayout(hudFrame)
    -- Stack HUD elements vertically for phone screens
    local elements = {}
    
    for _, child in ipairs(hudFrame:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible then
            table.insert(elements, child)
        end
    end
    
    for i, element in ipairs(elements) do
        element.Position = UDim2.new(0.05, 0, 0.05 + (i - 1) * 0.08, 0)
        element.Size = UDim2.new(0.9, 0, 0, 50)
    end
end

return MobileUIOptimizer