--[[
CraftingInterface.lua

Purpose: Crafting interface with progress indicators for Week 4
Dependencies: CraftingSystem (via RemoteEvents), inventory data
Last Modified: Phase 0 - Week 4
Performance Notes: Real-time progress updates with efficient UI management

Features:
- Recipe browser with filtering and search
- Real-time crafting progress indicators
- Batch crafting controls
- Material requirements display
- Quality prediction and bonuses
- Concurrent crafting queue management
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Module dependencies
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Remote event references
local GetCraftingDataEvent = RemoteEvents:WaitForChild("GetCraftingData")
local StartCraftingEvent = RemoteEvents:WaitForChild("StartCrafting")
local CancelCraftingEvent = RemoteEvents:WaitForChild("CancelCrafting")
local CraftingProgressEvent = RemoteEvents:WaitForChild("CraftingProgress")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CraftingInterface = {}
CraftingInterface.__index = CraftingInterface

-- Constants
local RECIPE_SLOT_SIZE = 80
local RECIPE_PADDING = 8
local ANIMATION_TIME = 0.3
local PROGRESS_UPDATE_RATE = 0.1

-- Quality colors for visual feedback
local QUALITY_COLORS = {
    Basic = Color3.fromRGB(180, 180, 180),
    Good = Color3.fromRGB(100, 255, 100),
    Excellent = Color3.fromRGB(100, 150, 255),
    Perfect = Color3.fromRGB(255, 200, 100)
}

-- Category colors
local CATEGORY_COLORS = {
    Tools = Color3.fromRGB(150, 100, 50),
    Buildings = Color3.fromRGB(100, 150, 150),
    Resources = Color3.fromRGB(50, 150, 50),
    Upgrades = Color3.fromRGB(150, 150, 100)
}

function CraftingInterface.new()
    local self = setmetatable({}, CraftingInterface)
    
    -- State management
    self.isVisible = false
    self.craftingData = {}
    self.activeCrafts = {}
    self.selectedRecipe = nil
    self.selectedCategory = "All"
    self.searchFilter = ""
    
    -- Progress tracking
    self.progressConnection = nil
    
    -- Create main UI
    self:createCraftingGUI()
    
    -- Connect events
    self:connectEvents()
    
    -- Initial data load
    self:refreshCraftingData()
    
    return self
end

function CraftingInterface:createCraftingGUI()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CraftingGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    self.screenGui = screenGui
    
    -- Main crafting frame
    local craftingFrame = Instance.new("Frame")
    craftingFrame.Name = "CraftingFrame"
    craftingFrame.Size = UDim2.new(0, 800, 0, 600)
    craftingFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
    craftingFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 55)
    craftingFrame.BorderSizePixel = 2
    craftingFrame.BorderColor3 = Color3.fromRGB(100, 150, 200)
    craftingFrame.Visible = false
    craftingFrame.Parent = screenGui
    self.craftingFrame = craftingFrame
    
    -- Title bar
    local titleBar = Instance.new("TextLabel")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
    titleBar.Text = "Crafting Station"
    titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleBar.TextSize = 22
    titleBar.Font = Enum.Font.GothamBold
    titleBar.Parent = craftingFrame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 24
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    closeButton.MouseButton1Click:Connect(function()
        self:toggleInterface()
    end)
    
    -- Main content area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -70)
    contentFrame.Position = UDim2.new(0, 10, 0, 60)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = craftingFrame
    self.contentFrame = contentFrame
    
    -- Create left panel (recipe browser)
    self:createRecipeBrowser()
    
    -- Create right panel (crafting details)
    self:createCraftingPanel()
    
    -- Create bottom panel (crafting queue)
    self:createCraftingQueue()
end

function CraftingInterface:createRecipeBrowser()
    -- Recipe browser frame
    local browserFrame = Instance.new("Frame")
    browserFrame.Name = "RecipeBrowser"
    browserFrame.Size = UDim2.new(0.4, -10, 0.7, 0)
    browserFrame.Position = UDim2.new(0, 0, 0, 0)
    browserFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
    browserFrame.BorderSizePixel = 1
    browserFrame.BorderColor3 = Color3.fromRGB(80, 90, 110)
    browserFrame.Parent = self.contentFrame
    self.browserFrame = browserFrame
    
    -- Search bar
    local searchFrame = Instance.new("Frame")
    searchFrame.Name = "SearchFrame"
    searchFrame.Size = UDim2.new(1, -10, 0, 35)
    searchFrame.Position = UDim2.new(0, 5, 0, 5)
    searchFrame.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    searchFrame.Parent = browserFrame
    
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -10, 1, -10)
    searchBox.Position = UDim2.new(0, 5, 0, 5)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText = "Search recipes..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    searchBox.Parent = searchFrame
    self.searchBox = searchBox
    
    searchBox.FocusLost:Connect(function()
        self.searchFilter = searchBox.Text:lower()
        self:updateRecipeDisplay()
    end)
    
    -- Category tabs
    local categoryFrame = Instance.new("Frame")
    categoryFrame.Name = "CategoryFrame"
    categoryFrame.Size = UDim2.new(1, -10, 0, 40)
    categoryFrame.Position = UDim2.new(0, 5, 0, 45)
    categoryFrame.BackgroundTransparency = 1
    categoryFrame.Parent = browserFrame
    
    self:createCategoryTabs(categoryFrame)
    
    -- Recipe scroll frame
    local recipeScroll = Instance.new("ScrollingFrame")
    recipeScroll.Name = "RecipeScroll"
    recipeScroll.Size = UDim2.new(1, -10, 1, -95)
    recipeScroll.Position = UDim2.new(0, 5, 0, 90)
    recipeScroll.BackgroundTransparency = 1
    recipeScroll.ScrollBarThickness = 8
    recipeScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 150, 200)
    recipeScroll.Parent = browserFrame
    self.recipeScroll = recipeScroll
    
    -- Recipe grid layout
    local recipeLayout = Instance.new("UIGridLayout")
    recipeLayout.CellSize = UDim2.new(0, RECIPE_SLOT_SIZE, 0, RECIPE_SLOT_SIZE + 30)
    recipeLayout.CellPadding = UDim2.new(0, RECIPE_PADDING, 0, RECIPE_PADDING)
    recipeLayout.Parent = recipeScroll
    
    recipeLayout.Changed:Connect(function()
        recipeScroll.CanvasSize = UDim2.new(0, 0, 0, recipeLayout.AbsoluteContentSize.Y)
    end)
end

function CraftingInterface:createCategoryTabs(parent)
    local categories = {"All", "Tools", "Buildings", "Resources", "Upgrades"}
    local tabWidth = (parent.AbsoluteSize.X - 20) / #categories
    
    for i, category in ipairs(categories) do
        local tab = Instance.new("TextButton")
        tab.Name = category .. "Tab"
        tab.Size = UDim2.new(0, tabWidth - 5, 1, 0)
        tab.Position = UDim2.new(0, (i-1) * tabWidth, 0, 0)
        tab.BackgroundColor3 = CATEGORY_COLORS[category] or Color3.fromRGB(80, 80, 80)
        tab.Text = category
        tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        tab.TextSize = 12
        tab.Font = Enum.Font.GothamBold
        tab.Parent = parent
        
        tab.MouseButton1Click:Connect(function()
            self:selectCategory(category)
        end)
        
        if category == self.selectedCategory then
            tab.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
        end
    end
end

function CraftingInterface:createCraftingPanel()
    -- Crafting details frame
    local detailsFrame = Instance.new("Frame")
    detailsFrame.Name = "CraftingDetails"
    detailsFrame.Size = UDim2.new(0.6, -10, 0.7, 0)
    detailsFrame.Position = UDim2.new(0.4, 0, 0, 0)
    detailsFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
    detailsFrame.BorderSizePixel = 1
    detailsFrame.BorderColor3 = Color3.fromRGB(80, 90, 110)
    detailsFrame.Parent = self.contentFrame
    self.detailsFrame = detailsFrame
    
    -- Recipe title
    local recipeTitle = Instance.new("TextLabel")
    recipeTitle.Name = "RecipeTitle"
    recipeTitle.Size = UDim2.new(1, -20, 0, 40)
    recipeTitle.Position = UDim2.new(0, 10, 0, 10)
    recipeTitle.BackgroundTransparency = 1
    recipeTitle.Text = "Select a recipe"
    recipeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    recipeTitle.TextSize = 18
    recipeTitle.Font = Enum.Font.GothamBold
    recipeTitle.TextXAlignment = Enum.TextXAlignment.Left
    recipeTitle.Parent = detailsFrame
    self.recipeTitle = recipeTitle
    
    -- Materials required section
    local materialsLabel = Instance.new("TextLabel")
    materialsLabel.Name = "MaterialsLabel"
    materialsLabel.Size = UDim2.new(1, -20, 0, 25)
    materialsLabel.Position = UDim2.new(0, 10, 0, 60)
    materialsLabel.BackgroundTransparency = 1
    materialsLabel.Text = "Materials Required:"
    materialsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    materialsLabel.TextSize = 14
    materialsLabel.Font = Enum.Font.GothamBold
    materialsLabel.TextXAlignment = Enum.TextXAlignment.Left
    materialsLabel.Parent = detailsFrame
    
    -- Materials scroll frame
    local materialsScroll = Instance.new("ScrollingFrame")
    materialsScroll.Name = "MaterialsScroll"
    materialsScroll.Size = UDim2.new(1, -20, 0, 120)
    materialsScroll.Position = UDim2.new(0, 10, 0, 85)
    materialsScroll.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    materialsScroll.ScrollBarThickness = 6
    materialsScroll.Parent = detailsFrame
    self.materialsScroll = materialsScroll
    
    -- Materials layout
    local materialsLayout = Instance.new("UIListLayout")
    materialsLayout.Padding = UDim.new(0, 5)
    materialsLayout.Parent = materialsScroll
    
    materialsLayout.Changed:Connect(function()
        materialsScroll.CanvasSize = UDim2.new(0, 0, 0, materialsLayout.AbsoluteContentSize.Y)
    end)
    
    -- Crafting controls
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "CraftingControls"
    controlsFrame.Size = UDim2.new(1, -20, 0, 80)
    controlsFrame.Position = UDim2.new(0, 10, 0, 220)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = detailsFrame
    
    -- Batch size control
    local batchLabel = Instance.new("TextLabel")
    batchLabel.Name = "BatchLabel"
    batchLabel.Size = UDim2.new(0, 100, 0, 25)
    batchLabel.Position = UDim2.new(0, 0, 0, 0)
    batchLabel.BackgroundTransparency = 1
    batchLabel.Text = "Batch Size:"
    batchLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    batchLabel.TextSize = 12
    batchLabel.Font = Enum.Font.Gotham
    batchLabel.TextXAlignment = Enum.TextXAlignment.Left
    batchLabel.Parent = controlsFrame
    
    local batchInput = Instance.new("TextBox")
    batchInput.Name = "BatchInput"
    batchInput.Size = UDim2.new(0, 60, 0, 25)
    batchInput.Position = UDim2.new(0, 105, 0, 0)
    batchInput.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    batchInput.Text = "1"
    batchInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    batchInput.TextSize = 12
    batchInput.Font = Enum.Font.Gotham
    batchInput.Parent = controlsFrame
    self.batchInput = batchInput
    
    -- Start crafting button
    local startButton = Instance.new("TextButton")
    startButton.Name = "StartCraftingButton"
    startButton.Size = UDim2.new(0.5, -10, 0, 35)
    startButton.Position = UDim2.new(0, 0, 0, 40)
    startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    startButton.Text = "Start Crafting"
    startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    startButton.TextSize = 14
    startButton.Font = Enum.Font.GothamBold
    startButton.Parent = controlsFrame
    self.startButton = startButton
    
    startButton.MouseButton1Click:Connect(function()
        self:startCrafting()
    end)
    
    -- Quality preview
    local qualityLabel = Instance.new("TextLabel")
    qualityLabel.Name = "QualityLabel"
    qualityLabel.Size = UDim2.new(0.5, -10, 0, 35)
    qualityLabel.Position = UDim2.new(0.5, 0, 0, 40)
    qualityLabel.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    qualityLabel.Text = "Quality: Good"
    qualityLabel.TextColor3 = QUALITY_COLORS.Good
    qualityLabel.TextSize = 12
    qualityLabel.Font = Enum.Font.GothamBold
    qualityLabel.Parent = controlsFrame
    self.qualityLabel = qualityLabel
end

function CraftingInterface:createCraftingQueue()
    -- Crafting queue frame
    local queueFrame = Instance.new("Frame")
    queueFrame.Name = "CraftingQueue"
    queueFrame.Size = UDim2.new(1, 0, 0.3, -10)
    queueFrame.Position = UDim2.new(0, 0, 0.7, 10)
    queueFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
    queueFrame.BorderSizePixel = 1
    queueFrame.BorderColor3 = Color3.fromRGB(80, 90, 110)
    queueFrame.Parent = self.contentFrame
    self.queueFrame = queueFrame
    
    -- Queue title
    local queueTitle = Instance.new("TextLabel")
    queueTitle.Name = "QueueTitle"
    queueTitle.Size = UDim2.new(1, -20, 0, 30)
    queueTitle.Position = UDim2.new(0, 10, 0, 5)
    queueTitle.BackgroundTransparency = 1
    queueTitle.Text = "Crafting Queue"
    queueTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    queueTitle.TextSize = 16
    queueTitle.Font = Enum.Font.GothamBold
    queueTitle.TextXAlignment = Enum.TextXAlignment.Left
    queueTitle.Parent = queueFrame
    
    -- Queue scroll frame
    local queueScroll = Instance.new("ScrollingFrame")
    queueScroll.Name = "QueueScroll"
    queueScroll.Size = UDim2.new(1, -20, 1, -45)
    queueScroll.Position = UDim2.new(0, 10, 0, 35)
    queueScroll.BackgroundTransparency = 1
    queueScroll.ScrollBarThickness = 6
    queueScroll.ScrollingDirection = Enum.ScrollingDirection.X
    queueScroll.Parent = queueFrame
    self.queueScroll = queueScroll
    
    -- Queue layout
    local queueLayout = Instance.new("UIListLayout")
    queueLayout.FillDirection = Enum.FillDirection.Horizontal
    queueLayout.Padding = UDim.new(0, 10)
    queueLayout.Parent = queueScroll
    
    queueLayout.Changed:Connect(function()
        queueScroll.CanvasSize = UDim2.new(0, queueLayout.AbsoluteContentSize.X, 0, 0)
    end)
end

function CraftingInterface:connectEvents()
    -- Keyboard toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.C then
            self:toggleInterface()
        end
    end)
    
    -- Server events
    if GetCraftingDataEvent then
        GetCraftingDataEvent.OnClientEvent:Connect(function(craftingData)
            self.craftingData = craftingData or {}
            self:updateRecipeDisplay()
        end)
    end
    
    if CraftingProgressEvent then
        CraftingProgressEvent.OnClientEvent:Connect(function(activeCrafts)
            self.activeCrafts = activeCrafts or {}
            self:updateCraftingQueue()
        end)
    end
    
    -- Start progress updates when interface is visible
    self.progressConnection = RunService.Heartbeat:Connect(function()
        if self.isVisible then
            self:updateProgressIndicators()
        end
    end)
end

function CraftingInterface:toggleInterface()
    self.isVisible = not self.isVisible
    self.craftingFrame.Visible = self.isVisible
    
    if self.isVisible then
        self:refreshCraftingData()
        -- Smooth fade in animation
        self.craftingFrame.BackgroundTransparency = 1
        local tween = TweenService:Create(self.craftingFrame,
            TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0}
        )
        tween:Play()
    end
end

function CraftingInterface:refreshCraftingData()
    if GetCraftingDataEvent then
        GetCraftingDataEvent:FireServer()
    end
end

function CraftingInterface:selectCategory(category)
    self.selectedCategory = category
    self:updateRecipeDisplay()
    
    -- Update tab appearance
    for _, tab in pairs(self.browserFrame.CategoryFrame:GetChildren()) do
        if tab:IsA("TextButton") then
            local tabCategory = string.gsub(tab.Name, "Tab", "")
            if tabCategory == category then
                tab.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
            else
                tab.BackgroundColor3 = CATEGORY_COLORS[tabCategory] or Color3.fromRGB(80, 80, 80)
            end
        end
    end
end

function CraftingInterface:updateRecipeDisplay()
    -- Clear existing recipe slots
    for _, child in pairs(self.recipeScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add filtered recipes
    for recipeId, recipeData in pairs(self.craftingData) do
        if self:passesFilters(recipeData) then
            self:createRecipeSlot(recipeId, recipeData)
        end
    end
end

function CraftingInterface:passesFilters(recipeData)
    -- Category filter
    if self.selectedCategory ~= "All" and recipeData.category ~= self.selectedCategory then
        return false
    end
    
    -- Search filter
    if self.searchFilter ~= "" then
        local searchIn = (recipeData.displayName or ""):lower() .. " " .. (recipeData.description or ""):lower()
        if not string.find(searchIn, self.searchFilter) then
            return false
        end
    end
    
    return true
end

function CraftingInterface:createRecipeSlot(recipeId, recipeData)
    local recipeSlot = Instance.new("Frame")
    recipeSlot.Name = "Recipe_" .. recipeId
    recipeSlot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    recipeSlot.BorderSizePixel = 1
    recipeSlot.BorderColor3 = Color3.fromRGB(80, 90, 110)
    recipeSlot.Parent = self.recipeScroll
    
    -- Recipe icon
    local recipeIcon = Instance.new("ImageLabel")
    recipeIcon.Name = "RecipeIcon"
    recipeIcon.Size = UDim2.new(1, -10, 1, -35)
    recipeIcon.Position = UDim2.new(0, 5, 0, 5)
    recipeIcon.BackgroundTransparency = 1
    recipeIcon.Image = self:getRecipeIcon(recipeData.result)
    recipeIcon.Parent = recipeSlot
    
    -- Recipe name
    local recipeName = Instance.new("TextLabel")
    recipeName.Name = "RecipeName"
    recipeName.Size = UDim2.new(1, -5, 0, 25)
    recipeName.Position = UDim2.new(0, 2.5, 1, -30)
    recipeName.BackgroundTransparency = 1
    recipeName.Text = recipeData.displayName or recipeId
    recipeName.TextColor3 = Color3.fromRGB(255, 255, 255)
    recipeName.TextSize = 10
    recipeName.Font = Enum.Font.Gotham
    recipeName.TextScaled = true
    recipeName.Parent = recipeSlot
    
    -- Click handler
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = recipeSlot
    
    clickButton.MouseButton1Click:Connect(function()
        self:selectRecipe(recipeId, recipeData)
    end)
    
    -- Hover effects
    clickButton.MouseEnter:Connect(function()
        recipeSlot.BackgroundColor3 = Color3.fromRGB(55, 65, 85)
    end)
    
    clickButton.MouseLeave:Connect(function()
        if self.selectedRecipe ~= recipeId then
            recipeSlot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        end
    end)
end

function CraftingInterface:selectRecipe(recipeId, recipeData)
    self.selectedRecipe = recipeId
    self:updateRecipeDetails(recipeData)
    
    -- Update visual selection
    for _, slot in pairs(self.recipeScroll:GetChildren()) do
        if slot:IsA("Frame") then
            if slot.Name == "Recipe_" .. recipeId then
                slot.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
            else
                slot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
            end
        end
    end
end

function CraftingInterface:updateRecipeDetails(recipeData)
    -- Update recipe title
    self.recipeTitle.Text = recipeData.displayName or "Unknown Recipe"
    
    -- Clear materials list
    for _, child in pairs(self.materialsScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add material requirements
    for material, amount in pairs(recipeData.materials or {}) do
        self:createMaterialSlot(material, amount)
    end
    
    -- Update quality prediction
    local predictedQuality = self:predictCraftingQuality(recipeData)
    self.qualityLabel.Text = "Quality: " .. predictedQuality
    self.qualityLabel.TextColor3 = QUALITY_COLORS[predictedQuality] or QUALITY_COLORS.Basic
end

function CraftingInterface:createMaterialSlot(material, amount)
    local materialSlot = Instance.new("Frame")
    materialSlot.Name = "Material_" .. material
    materialSlot.Size = UDim2.new(1, -10, 0, 30)
    materialSlot.BackgroundColor3 = Color3.fromRGB(55, 65, 85)
    materialSlot.BorderSizePixel = 1
    materialSlot.BorderColor3 = Color3.fromRGB(80, 90, 110)
    materialSlot.Parent = self.materialsScroll
    
    -- Material icon
    local materialIcon = Instance.new("ImageLabel")
    materialIcon.Name = "MaterialIcon"
    materialIcon.Size = UDim2.new(0, 24, 0, 24)
    materialIcon.Position = UDim2.new(0, 3, 0, 3)
    materialIcon.BackgroundTransparency = 1
    materialIcon.Image = self:getMaterialIcon(material)
    materialIcon.Parent = materialSlot
    
    -- Material name and amount
    local materialLabel = Instance.new("TextLabel")
    materialLabel.Name = "MaterialLabel"
    materialLabel.Size = UDim2.new(1, -60, 1, 0)
    materialLabel.Position = UDim2.new(0, 30, 0, 0)
    materialLabel.BackgroundTransparency = 1
    materialLabel.Text = material .. " x" .. amount
    materialLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    materialLabel.TextSize = 12
    materialLabel.Font = Enum.Font.Gotham
    materialLabel.TextXAlignment = Enum.TextXAlignment.Left
    materialLabel.Parent = materialSlot
    
    -- Availability indicator (would check player inventory)
    local availabilityIcon = Instance.new("TextLabel")
    availabilityIcon.Name = "AvailabilityIcon"
    availabilityIcon.Size = UDim2.new(0, 24, 0, 24)
    availabilityIcon.Position = UDim2.new(1, -27, 0, 3)
    availabilityIcon.BackgroundTransparency = 1
    availabilityIcon.Text = "✓" -- Or "✗" if not available
    availabilityIcon.TextColor3 = Color3.fromRGB(100, 255, 100) -- Or red if not available
    availabilityIcon.TextSize = 16
    availabilityIcon.Font = Enum.Font.GothamBold
    availabilityIcon.Parent = materialSlot
end

function CraftingInterface:startCrafting()
    if not self.selectedRecipe then return end
    
    local batchSize = tonumber(self.batchInput.Text) or 1
    batchSize = math.max(1, math.min(batchSize, 10)) -- Limit batch size
    
    if StartCraftingEvent then
        StartCraftingEvent:FireServer(self.selectedRecipe, batchSize)
    end
end

function CraftingInterface:updateCraftingQueue()
    -- Clear existing queue items
    for _, child in pairs(self.queueScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add active crafts to queue
    for craftId, craftData in pairs(self.activeCrafts) do
        self:createQueueItem(craftId, craftData)
    end
end

function CraftingInterface:createQueueItem(craftId, craftData)
    local queueItem = Instance.new("Frame")
    queueItem.Name = "QueueItem_" .. craftId
    queueItem.Size = UDim2.new(0, 120, 1, -10)
    queueItem.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    queueItem.BorderSizePixel = 1
    queueItem.BorderColor3 = Color3.fromRGB(80, 90, 110)
    queueItem.Parent = self.queueScroll
    
    -- Item icon
    local itemIcon = Instance.new("ImageLabel")
    itemIcon.Name = "ItemIcon"
    itemIcon.Size = UDim2.new(0, 40, 0, 40)
    itemIcon.Position = UDim2.new(0, 5, 0, 5)
    itemIcon.BackgroundTransparency = 1
    itemIcon.Image = self:getRecipeIcon(craftData.recipeId)
    itemIcon.Parent = queueItem
    
    -- Item name
    local itemName = Instance.new("TextLabel")
    itemName.Name = "ItemName"
    itemName.Size = UDim2.new(1, -55, 0, 20)
    itemName.Position = UDim2.new(0, 50, 0, 5)
    itemName.BackgroundTransparency = 1
    itemName.Text = craftData.displayName or craftData.recipeId
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.TextSize = 10
    itemName.Font = Enum.Font.Gotham
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.Parent = queueItem
    
    -- Progress bar
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(1, -55, 0, 8)
    progressBar.Position = UDim2.new(0, 50, 0, 25)
    progressBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = queueItem
    
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBar
    
    -- Time remaining
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "TimeLabel"
    timeLabel.Size = UDim2.new(1, -55, 0, 15)
    timeLabel.Position = UDim2.new(0, 50, 0, 35)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = "0:00"
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeLabel.TextSize = 9
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextXAlignment = Enum.TextXAlignment.Left
    timeLabel.Parent = queueItem
    
    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "CancelButton"
    cancelButton.Size = UDim2.new(0, 15, 0, 15)
    cancelButton.Position = UDim2.new(1, -20, 0, 5)
    cancelButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    cancelButton.Text = "×"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.TextSize = 10
    cancelButton.Font = Enum.Font.GothamBold
    cancelButton.Parent = queueItem
    
    cancelButton.MouseButton1Click:Connect(function()
        if CancelCraftingEvent then
            CancelCraftingEvent:FireServer(craftId)
        end
    end)
end

function CraftingInterface:updateProgressIndicators()
    -- Update progress bars for all active crafts
    local currentTime = tick()
    
    for _, queueItem in pairs(self.queueScroll:GetChildren()) do
        if queueItem:IsA("Frame") then
            local craftId = string.gsub(queueItem.Name, "QueueItem_", "")
            local craftData = self.activeCrafts[craftId]
            
            if craftData then
                local elapsed = currentTime - craftData.startTime
                local progress = math.min(elapsed / craftData.duration, 1)
                local timeRemaining = math.max(craftData.duration - elapsed, 0)
                
                -- Update progress bar
                local progressFill = queueItem:FindFirstChild("ProgressBar"):FindFirstChild("ProgressFill")
                if progressFill then
                    progressFill.Size = UDim2.new(progress, 0, 1, 0)
                end
                
                -- Update time label
                local timeLabel = queueItem:FindFirstChild("TimeLabel")
                if timeLabel then
                    local minutes = math.floor(timeRemaining / 60)
                    local seconds = math.floor(timeRemaining % 60)
                    timeLabel.Text = string.format("%d:%02d", minutes, seconds)
                end
            end
        end
    end
end

-- Utility functions
function CraftingInterface:getRecipeIcon(recipeId)
    -- Placeholder icon mapping
    local iconMap = {
        KelpTool = "rbxasset://textures/face.png",
        RockHammer = "rbxasset://textures/face.png",
        PearlNet = "rbxasset://textures/face.png"
    }
    return iconMap[recipeId] or "rbxasset://textures/face.png"
end

function CraftingInterface:getMaterialIcon(material)
    -- Placeholder material icon mapping
    local iconMap = {
        Kelp = "rbxasset://textures/face.png",
        Rock = "rbxasset://textures/face.png",
        Pearl = "rbxasset://textures/face.png"
    }
    return iconMap[material] or "rbxasset://textures/face.png"
end

function CraftingInterface:predictCraftingQuality(recipeData)
    -- Simple quality prediction based on materials and player skill
    -- In a real implementation, this would check player inventory and skill levels
    return "Good"
end

-- Export the class
return CraftingInterface