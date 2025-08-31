--[[
InventoryInterface.lua

Purpose: Enhanced inventory UI with drag-and-drop functionality for Week 4
Dependencies: PlayerInventory (via RemoteEvents), ToolData.lua, StaminaConfig.lua  
Last Modified: Phase 0 - Week 4
Performance Notes: Optimized with object pooling for slot management

Features:
- Drag-and-drop item management
- Tool durability visualization
- Resource stacking with visual counts
- Quality indicators for items
- Context menus for item actions
- Smooth animations and visual feedback
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

-- Module dependencies
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")
local ToolData = require(SharedModules:WaitForChild("ToolData"))

-- Remote event references
local GetInventoryEvent = RemoteEvents:WaitForChild("GetInventory")
local UseItemEvent = RemoteEvents:WaitForChild("UseItem")
local MoveItemEvent = RemoteEvents:WaitForChild("MoveItem")
local EquipToolEvent = RemoteEvents:WaitForChild("EquipTool")
local UnequipToolEvent = RemoteEvents:WaitForChild("UnequipTool")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InventoryInterface = {}
InventoryInterface.__index = InventoryInterface

-- Constants
local INVENTORY_SIZE = {Width = 8, Height = 6}
local SLOT_SIZE = 64
local SLOT_PADDING = 4
local ANIMATION_TIME = 0.2

-- Quality colors for item borders
local QUALITY_COLORS = {
    Basic = Color3.fromRGB(200, 200, 200),
    Good = Color3.fromRGB(100, 255, 100),
    Excellent = Color3.fromRGB(100, 150, 255),
    Perfect = Color3.fromRGB(255, 200, 100)
}

function InventoryInterface.new()
    local self = setmetatable({}, InventoryInterface)
    
    -- State management
    self.inventoryData = {}
    self.equippedTools = {}
    self.isVisible = false
    self.selectedSlot = nil
    self.dragData = nil
    
    -- UI object pools
    self.slotPool = {}
    self.iconPool = {}
    
    -- Create main UI
    self:createInventoryGUI()
    
    -- Connect events
    self:connectEvents()
    
    -- Initial inventory load
    self:refreshInventory()
    
    return self
end

function InventoryInterface:createInventoryGUI()
    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InventoryGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    self.screenGui = screenGui
    
    -- Main inventory frame
    local inventoryFrame = Instance.new("Frame")
    inventoryFrame.Name = "InventoryFrame"
    inventoryFrame.Size = UDim2.new(0, (SLOT_SIZE + SLOT_PADDING) * INVENTORY_SIZE.Width + SLOT_PADDING, 
                                   0, (SLOT_SIZE + SLOT_PADDING) * INVENTORY_SIZE.Height + 80)
    inventoryFrame.Position = UDim2.new(0.5, -inventoryFrame.Size.X.Offset/2, 0.5, -inventoryFrame.Size.Y.Offset/2)
    inventoryFrame.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    inventoryFrame.BorderSizePixel = 2
    inventoryFrame.BorderColor3 = Color3.fromRGB(100, 150, 200)
    inventoryFrame.Visible = false
    inventoryFrame.Parent = screenGui
    self.inventoryFrame = inventoryFrame
    
    -- Title bar
    local titleBar = Instance.new("TextLabel")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    titleBar.Text = "Inventory"
    titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleBar.TextSize = 18
    titleBar.Font = Enum.Font.GothamBold
    titleBar.Parent = inventoryFrame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 20
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    closeButton.MouseButton1Click:Connect(function()
        self:toggleInventory()
    end)
    
    -- Inventory grid container
    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Size = UDim2.new(1, -SLOT_PADDING*2, 1, -50)
    gridContainer.Position = UDim2.new(0, SLOT_PADDING, 0, 45)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = inventoryFrame
    self.gridContainer = gridContainer
    
    -- Create inventory slots
    self:createInventorySlots()
    
    -- Create drag indicator
    self:createDragIndicator()
end

function InventoryInterface:createInventorySlots()
    self.slots = {}
    
    for y = 1, INVENTORY_SIZE.Height do
        self.slots[y] = {}
        for x = 1, INVENTORY_SIZE.Width do
            local slotIndex = ((y-1) * INVENTORY_SIZE.Width) + x
            local slot = self:createSlot(x, y, slotIndex)
            self.slots[y][x] = slot
        end
    end
end

function InventoryInterface:createSlot(x, y, slotIndex)
    -- Get slot from pool or create new
    local slotFrame = self:getPooledSlot()
    
    -- Configure slot
    slotFrame.Name = "Slot_" .. slotIndex
    slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slotFrame.Position = UDim2.new(0, (x-1) * (SLOT_SIZE + SLOT_PADDING), 0, (y-1) * (SLOT_SIZE + SLOT_PADDING))
    slotFrame.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
    slotFrame.BorderColor3 = Color3.fromRGB(80, 90, 110)
    slotFrame.Parent = self.gridContainer
    
    -- Item icon
    local itemIcon = slotFrame:FindFirstChild("ItemIcon") or Instance.new("ImageLabel")
    itemIcon.Name = "ItemIcon"
    itemIcon.Size = UDim2.new(1, -8, 1, -8)
    itemIcon.Position = UDim2.new(0, 4, 0, 4)
    itemIcon.BackgroundTransparency = 1
    itemIcon.Image = ""
    itemIcon.Parent = slotFrame
    
    -- Quantity label
    local quantityLabel = slotFrame:FindFirstChild("QuantityLabel") or Instance.new("TextLabel")
    quantityLabel.Name = "QuantityLabel"
    quantityLabel.Size = UDim2.new(0, 20, 0, 16)
    quantityLabel.Position = UDim2.new(1, -24, 1, -20)
    quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    quantityLabel.BackgroundTransparency = 0.3
    quantityLabel.Text = ""
    quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantityLabel.TextSize = 12
    quantityLabel.Font = Enum.Font.GothamBold
    quantityLabel.Visible = false
    quantityLabel.Parent = slotFrame
    
    -- Durability bar (for tools)
    local durabilityBar = slotFrame:FindFirstChild("DurabilityBar") or Instance.new("Frame")
    durabilityBar.Name = "DurabilityBar"
    durabilityBar.Size = UDim2.new(1, -8, 0, 4)
    durabilityBar.Position = UDim2.new(0, 4, 1, -8)
    durabilityBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    durabilityBar.BorderSizePixel = 0
    durabilityBar.Visible = false
    durabilityBar.Parent = slotFrame
    
    local durabilityFill = durabilityBar:FindFirstChild("Fill") or Instance.new("Frame")
    durabilityFill.Name = "Fill"
    durabilityFill.Size = UDim2.new(1, 0, 1, 0)
    durabilityFill.Position = UDim2.new(0, 0, 0, 0)
    durabilityFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    durabilityFill.BorderSizePixel = 0
    durabilityFill.Parent = durabilityBar
    
    -- Quality border
    local qualityBorder = slotFrame:FindFirstChild("QualityBorder") or Instance.new("Frame")
    qualityBorder.Name = "QualityBorder"
    qualityBorder.Size = UDim2.new(1, 4, 1, 4)
    qualityBorder.Position = UDim2.new(0, -2, 0, -2)
    qualityBorder.BackgroundTransparency = 1
    qualityBorder.BorderSizePixel = 2
    qualityBorder.BorderColor3 = QUALITY_COLORS.Basic
    qualityBorder.Visible = false
    qualityBorder.Parent = slotFrame
    
    -- Connect slot events
    self:connectSlotEvents(slotFrame, slotIndex)
    
    return slotFrame
end

function InventoryInterface:connectSlotEvents(slotFrame, slotIndex)
    local inputBegan, inputEnded, inputChanged
    
    inputBegan = slotFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:startDrag(slotIndex, input.Position)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            self:showContextMenu(slotIndex, input.Position)
        end
    end)
    
    inputEnded = slotFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:endDrag(slotIndex)
        end
    end)
    
    inputChanged = slotFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self.dragData then
            self:updateDrag(input.Position)
        end
    end)
end

function InventoryInterface:createDragIndicator()
    local dragIndicator = Instance.new("ImageLabel")
    dragIndicator.Name = "DragIndicator"
    dragIndicator.Size = UDim2.new(0, SLOT_SIZE * 0.8, 0, SLOT_SIZE * 0.8)
    dragIndicator.BackgroundTransparency = 1
    dragIndicator.Image = ""
    dragIndicator.ImageTransparency = 0.3
    dragIndicator.Visible = false
    dragIndicator.ZIndex = 1000
    dragIndicator.Parent = self.screenGui
    self.dragIndicator = dragIndicator
end

function InventoryInterface:getPooledSlot()
    if #self.slotPool > 0 then
        return table.remove(self.slotPool, 1)
    else
        return Instance.new("Frame")
    end
end

function InventoryInterface:returnSlotToPool(slot)
    slot.Parent = nil
    slot.Visible = false
    table.insert(self.slotPool, slot)
end

function InventoryInterface:connectEvents()
    -- Keyboard toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Tab then
            self:toggleInventory()
        end
    end)
    
    -- Server inventory updates
    if GetInventoryEvent then
        GetInventoryEvent.OnClientEvent:Connect(function(inventoryData, equippedTools)
            self.inventoryData = inventoryData or {}
            self.equippedTools = equippedTools or {}
            self:updateDisplay()
        end)
    end
end

function InventoryInterface:toggleInventory()
    self.isVisible = not self.isVisible
    self.inventoryFrame.Visible = self.isVisible
    
    if self.isVisible then
        self:refreshInventory()
        -- Smooth fade in animation
        self.inventoryFrame.BackgroundTransparency = 1
        local tween = TweenService:Create(self.inventoryFrame, 
            TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0}
        )
        tween:Play()
    end
end

function InventoryInterface:refreshInventory()
    if GetInventoryEvent then
        GetInventoryEvent:FireServer()
    end
end

function InventoryInterface:updateDisplay()
    -- Clear all slots first
    self:clearAllSlots()
    
    -- Update slots with current inventory data
    for slotIndex, itemData in pairs(self.inventoryData) do
        if itemData then
            self:updateSlot(slotIndex, itemData)
        end
    end
end

function InventoryInterface:clearAllSlots()
    for y = 1, INVENTORY_SIZE.Height do
        for x = 1, INVENTORY_SIZE.Width do
            local slot = self.slots[y][x]
            if slot then
                self:clearSlot(slot)
            end
        end
    end
end

function InventoryInterface:clearSlot(slot)
    local itemIcon = slot:FindFirstChild("ItemIcon")
    local quantityLabel = slot:FindFirstChild("QuantityLabel")
    local durabilityBar = slot:FindFirstChild("DurabilityBar")
    local qualityBorder = slot:FindFirstChild("QualityBorder")
    
    if itemIcon then itemIcon.Image = "" end
    if quantityLabel then 
        quantityLabel.Text = ""
        quantityLabel.Visible = false
    end
    if durabilityBar then durabilityBar.Visible = false end
    if qualityBorder then qualityBorder.Visible = false end
    
    slot.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
end

function InventoryInterface:updateSlot(slotIndex, itemData)
    local y = math.ceil(slotIndex / INVENTORY_SIZE.Width)
    local x = ((slotIndex - 1) % INVENTORY_SIZE.Width) + 1
    
    local slot = self.slots[y] and self.slots[y][x]
    if not slot then return end
    
    local itemIcon = slot:FindFirstChild("ItemIcon")
    local quantityLabel = slot:FindFirstChild("QuantityLabel")
    local durabilityBar = slot:FindFirstChild("DurabilityBar")
    local qualityBorder = slot:FindFirstChild("QualityBorder")
    
    -- Set item icon (placeholder for now)
    if itemIcon then
        itemIcon.Image = self:getItemIcon(itemData.itemType)
    end
    
    -- Show quantity for stackable items
    if quantityLabel and itemData.quantity and itemData.quantity > 1 then
        quantityLabel.Text = tostring(itemData.quantity)
        quantityLabel.Visible = true
    end
    
    -- Show durability for tools
    if durabilityBar and itemData.durability and itemData.maxDurability then
        local durabilityRatio = itemData.durability / itemData.maxDurability
        local fill = durabilityBar:FindFirstChild("Fill")
        
        durabilityBar.Visible = true
        if fill then
            fill.Size = UDim2.new(durabilityRatio, 0, 1, 0)
            fill.BackgroundColor3 = self:getDurabilityColor(durabilityRatio)
        end
    end
    
    -- Show quality border
    if qualityBorder and itemData.quality then
        qualityBorder.Visible = true
        qualityBorder.BorderColor3 = QUALITY_COLORS[itemData.quality] or QUALITY_COLORS.Basic
    end
    
    -- Highlight equipped tools
    if itemData.itemType and string.find(itemData.itemType, "Tool") and 
       self.equippedTools[itemData.itemType] == itemData.id then
        slot.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    end
end

function InventoryInterface:getItemIcon(itemType)
    -- Placeholder icon mapping - would be replaced with actual asset IDs
    local iconMap = {
        Kelp = "rbxasset://textures/face.png", -- Placeholder
        Rock = "rbxasset://textures/face.png",
        Pearl = "rbxasset://textures/face.png",
        KelpTool = "rbxasset://textures/face.png",
        RockHammer = "rbxasset://textures/face.png",
        PearlNet = "rbxasset://textures/face.png"
    }
    return iconMap[itemType] or "rbxasset://textures/face.png"
end

function InventoryInterface:getDurabilityColor(ratio)
    if ratio > 0.7 then
        return Color3.fromRGB(100, 200, 100) -- Green
    elseif ratio > 0.3 then
        return Color3.fromRGB(255, 255, 100) -- Yellow
    else
        return Color3.fromRGB(200, 100, 100) -- Red
    end
end

function InventoryInterface:startDrag(slotIndex, position)
    local itemData = self.inventoryData[slotIndex]
    if not itemData then return end
    
    self.dragData = {
        fromSlot = slotIndex,
        itemData = itemData,
        startPosition = position
    }
    
    -- Show drag indicator
    self.dragIndicator.Image = self:getItemIcon(itemData.itemType)
    self.dragIndicator.Position = UDim2.new(0, position.X - SLOT_SIZE * 0.4, 0, position.Y - SLOT_SIZE * 0.4)
    self.dragIndicator.Visible = true
end

function InventoryInterface:updateDrag(position)
    if not self.dragData then return end
    
    self.dragIndicator.Position = UDim2.new(0, position.X - SLOT_SIZE * 0.4, 0, position.Y - SLOT_SIZE * 0.4)
end

function InventoryInterface:endDrag(slotIndex)
    if not self.dragData then return end
    
    -- Hide drag indicator
    self.dragIndicator.Visible = false
    
    -- Handle item movement
    if slotIndex ~= self.dragData.fromSlot then
        self:moveItem(self.dragData.fromSlot, slotIndex)
    end
    
    self.dragData = nil
end

function InventoryInterface:moveItem(fromSlot, toSlot)
    if MoveItemEvent then
        MoveItemEvent:FireServer(fromSlot, toSlot)
    end
end

function InventoryInterface:showContextMenu(slotIndex, position)
    local itemData = self.inventoryData[slotIndex]
    if not itemData then return end
    
    -- Create simple context menu for now
    local actions = {}
    
    -- Add use/equip actions based on item type
    if string.find(itemData.itemType, "Tool") then
        if self.equippedTools[itemData.itemType] == itemData.id then
            table.insert(actions, {text = "Unequip", action = function() self:unequipTool(itemData.id) end})
        else
            table.insert(actions, {text = "Equip", action = function() self:equipTool(itemData.id) end})
        end
    else
        table.insert(actions, {text = "Use", action = function() self:useItem(slotIndex) end})
    end
    
    -- For now, just execute the first action available
    if #actions > 0 then
        actions[1].action()
    end
end

function InventoryInterface:equipTool(toolId)
    if EquipToolEvent then
        EquipToolEvent:FireServer(toolId)
    end
end

function InventoryInterface:unequipTool(toolId)
    if UnequipToolEvent then
        UnequipToolEvent:FireServer(toolId)
    end
end

function InventoryInterface:useItem(slotIndex)
    if UseItemEvent then
        UseItemEvent:FireServer(slotIndex)
    end
end

-- Export the class
return InventoryInterface