# AquaticMetropolis: Phase C Development Plan
## Phased Beta Strategy Implementation

**Strategy Overview:** Option C - Progressive beta releases with milestone gates, prioritizing validation over feature completeness.

**Total Timeline:** 28 weeks (7 months)  
**Development Risk:** 15% (vs 85% for full scope)  
**Projected Success Rate:** 70% (completion + sustainable retention)

---

# Phase Structure Overview

## Phase 0: MVP Beta Foundation (Weeks 1-8)
**Target:** Core mechanics validation with invited beta testers
**Audience:** 50-100 invited players  
**Success Gate:** >60% Day 3 retention, >15 minute sessions

## Phase 1: Enhanced Beta (Weeks 9-12) 
**Target:** Social systems validation with soft launch
**Audience:** 200-500 players via soft launch
**Success Gate:** >45% Day 7 retention, >30 minute sessions  

## Phase 2: Public Launch (Weeks 13-18)
**Target:** Sustainable player base with content depth
**Audience:** General Roblox audience
**Success Gate:** 1000+ monthly active users

## Phase 3-4: Live Service Evolution (Weeks 19-28)
**Target:** Community-driven growth and retention
**Audience:** Growing community with regular engagement
**Success Gate:** 25% Day 90 retention, active community features

---

# Phase 0: MVP Beta Foundation (Weeks 1-8)

## Technical Architecture Setup

### Week 1: Project Foundation & Core Architecture

#### Roblox Place Structure
```
Workspace/
├── Terrain/                 # Underwater environment base
├── ResourceNodes/           # Spawned resource locations  
├── PlayerBuildings/         # Individual player constructions
└── EnvironmentalAssets/     # Decorative fish and kelp

ReplicatedStorage/
├── SharedModules/
│   ├── ResourceData.lua     # Resource definitions and spawn rules
│   ├── GameConstants.lua    # Configuration values and balancing
│   ├── PlayerData.lua       # Data structure definitions
│   └── Utilities.lua        # Helper functions
├── RemoteEvents/
│   ├── ResourceEvents.lua   # Harvesting, respawning
│   ├── CraftingEvents.lua   # Item creation and tool usage
│   └── BuildingEvents.lua   # Placement and removal
└── Assets/
    ├── ResourceModels/      # Kelp, rock, pearl models
    ├── CraftableItems/      # Tools and buildable objects
    └── UI/                  # Interface elements

ServerScriptService/
├── Core/
│   ├── GameManager.lua      # Main game state controller
│   ├── ResourceSpawner.lua  # Resource node management
│   ├── PlayerManager.lua    # Player data and sessions
│   └── CraftingSystem.lua   # Recipe processing
├── Systems/
│   ├── DataStoreManager.lua # Persistent storage handling
│   └── PerformanceMonitor.lua # Budget enforcement
└── Analytics/
    └── EventTracker.lua     # Player behavior metrics

StarterGui/
├── MainInterface/
│   ├── InventoryFrame.lua   # 5-slot inventory display
│   ├── CraftingFrame.lua    # Recipe interface
│   └── ResourceCounter.lua  # Current resources display
└── Controllers/
    ├── InputController.lua  # Click-to-harvest handling
    └── UIController.lua     # Interface state management
```

#### MVP Resource System Implementation
```lua
-- ResourceData.lua - Core MVP resources only
local ResourceData = {
    Kelp = {
        displayName = "Glowing Kelp",
        model = "rbxasset://cylinders/kelp", -- Placeholder: green cylinder
        spawnChance = 0.3, -- 30% of valid positions
        respawnTime = 60, -- 1 minute
        harvestValue = 1,
        harvestSound = "rbxassetid://131961136", -- Default Roblox sound
        description = "Bioluminescent seaweed, essential for basic tools"
    },
    
    Rock = {
        displayName = "Smooth Rock",
        model = "rbxasset://blocks/rock", -- Placeholder: gray block
        spawnChance = 0.2,
        respawnTime = 120, -- 2 minutes  
        harvestValue = 2,
        harvestSound = "rbxassetid://131961136",
        description = "Dense stone perfect for construction"
    },
    
    Pearl = {
        displayName = "Deep Pearl",
        model = "rbxasset://spheres/pearl", -- Placeholder: white sphere
        spawnChance = 0.1, -- Rare
        respawnTime = 300, -- 5 minutes
        harvestValue = 5,
        harvestSound = "rbxassetid://131961136", 
        requiresTool = nil, -- Can be gathered by hand initially
        description = "Precious ocean gem, highly valuable for advanced crafts"
    }
}

return ResourceData
```

#### MVP Crafting Recipes
```lua  
-- CraftingData.lua - Essential MVP recipes only
local CraftingData = {
    -- Tools (Progression enablers)
    KelpTool = {
        displayName = "Kelp Harvester",
        ingredients = {Kelp = 3},
        craftTime = 2, -- seconds
        durability = 50, -- uses before breaking
        effect = {harvestSpeed = 1.5}, -- 50% faster kelp gathering
        description = "Woven kelp tool for faster harvesting",
        category = "tools"
    },
    
    RockHammer = {
        displayName = "Stone Hammer", 
        ingredients = {Rock = 2},
        craftTime = 3,
        durability = 40,
        effect = {harvestSpeed = 1.3, rockBonus = true}, -- Better rock harvesting
        description = "Simple hammer for efficient rock breaking",
        category = "tools"
    },
    
    PearlNet = {
        displayName = "Pearl Diving Net",
        ingredients = {Kelp = 2, Rock = 1},
        craftTime = 4,
        durability = 30,
        effect = {pearlChance = 2.0}, -- Double pearl find rate
        description = "Specialized net for deep pearl diving",
        category = "tools"
    },
    
    -- Buildables (Expression enablers)
    BasicWall = {
        displayName = "Stone Wall",
        ingredients = {Rock = 3},
        craftTime = 2,
        buildable = true,
        size = Vector3.new(4, 4, 1),
        description = "Sturdy wall for underwater construction",
        category = "building"
    },
    
    KelpCarpet = {
        displayName = "Kelp Floor Mat",
        ingredients = {Kelp = 5},
        craftTime = 3,
        buildable = true,
        size = Vector3.new(4, 0.2, 4),
        description = "Soft flooring woven from kelp",
        category = "building"
    }
}

return CraftingData
```

**Week 1 Deliverables:**
- Complete Roblox place structure setup
- Resource data definitions implemented
- Basic crafting recipe framework
- Core module architecture established

### Week 2: Resource Spawning & World Generation

#### Simple Grid-Based World Generation
```lua
-- WorldGenerator.lua - MVP simplified approach
local WorldGenerator = {}
local ResourceData = require(ReplicatedStorage.SharedModules.ResourceData)

-- MVP Configuration
local WORLD_CONFIG = {
    size = Vector3.new(200, 40, 200), -- 200x200 stud area, 40 studs deep
    seaLevel = -5, -- 5 studs underwater
    gridSize = 15, -- 15 stud spacing between potential spawn points
    maxResourcesPerType = 50, -- Prevent spam
    spawnHeight = -8 -- Resource spawn depth
}

function WorldGenerator:CreateBasicTerrain()
    -- Create simple underwater terrain using Roblox Terrain API
    local terrain = workspace.Terrain
    
    -- Fill area with water
    local waterRegion = Region3.new(
        Vector3.new(-WORLD_CONFIG.size.X/2, WORLD_CONFIG.seaLevel - WORLD_CONFIG.size.Y, -WORLD_CONFIG.size.Z/2),
        Vector3.new(WORLD_CONFIG.size.X/2, WORLD_CONFIG.seaLevel, WORLD_CONFIG.size.Z/2)
    )
    
    terrain:ReadVoxels(waterRegion, 4)
    terrain:WriteVoxels(waterRegion, 4, {Enum.Material.Water})
    
    -- Create basic seafloor
    local seafloorRegion = Region3.new(
        Vector3.new(-WORLD_CONFIG.size.X/2, -WORLD_CONFIG.size.Y, -WORLD_CONFIG.size.Z/2),
        Vector3.new(WORLD_CONFIG.size.X/2, WORLD_CONFIG.seaLevel - 10, WORLD_CONFIG.size.Z/2)
    )
    
    terrain:WriteVoxels(seafloorRegion, 4, {Enum.Material.Sand})
    
    print("Basic underwater terrain generated")
end

function WorldGenerator:SpawnInitialResources()
    -- Simple grid-based spawning (no complex algorithms)
    local spawnedCounts = {Kelp = 0, Rock = 0, Pearl = 0}
    
    for x = -WORLD_CONFIG.size.X/2, WORLD_CONFIG.size.X/2, WORLD_CONFIG.gridSize do
        for z = -WORLD_CONFIG.size.Z/2, WORLD_CONFIG.size.Z/2, WORLD_CONFIG.gridSize do
            -- Add some randomness to avoid perfect grid
            local offsetX = math.random(-5, 5)
            local offsetZ = math.random(-5, 5)
            local spawnPos = Vector3.new(x + offsetX, WORLD_CONFIG.spawnHeight, z + offsetZ)
            
            -- Check each resource type for spawning
            for resourceType, resourceData in pairs(ResourceData) do
                if math.random() < resourceData.spawnChance and 
                   spawnedCounts[resourceType] < WORLD_CONFIG.maxResourcesPerType then
                    
                    self:SpawnResourceNode(resourceType, spawnPos)
                    spawnedCounts[resourceType] = spawnedCounts[resourceType] + 1
                end
            end
        end
    end
    
    print("Spawned resources:", spawnedCounts)
end

function WorldGenerator:SpawnResourceNode(resourceType, position)
    local resourceData = ResourceData[resourceType]
    
    -- Create basic primitive as placeholder model
    local resourceNode = Instance.new("Part")
    resourceNode.Name = resourceType .. "Node"
    resourceNode.Position = position
    resourceNode.Anchored = true
    resourceNode.CanCollide = false
    
    -- Set appearance based on resource type
    if resourceType == "Kelp" then
        resourceNode.Shape = Enum.PartType.Cylinder
        resourceNode.Size = Vector3.new(0.5, 6, 0.5)
        resourceNode.Color = Color3.fromRGB(50, 150, 50)
        resourceNode.Material = Enum.Material.Grass
    elseif resourceType == "Rock" then
        resourceNode.Shape = Enum.PartType.Block
        resourceNode.Size = Vector3.new(2, 1.5, 2)
        resourceNode.Color = Color3.fromRGB(100, 100, 100)
        resourceNode.Material = Enum.Material.Rock
    elseif resourceType == "Pearl" then
        resourceNode.Shape = Enum.PartType.Ball
        resourceNode.Size = Vector3.new(1, 1, 1)
        resourceNode.Color = Color3.fromRGB(255, 255, 240)
        resourceNode.Material = Enum.Material.Neon
    end
    
    -- Add resource component data
    resourceNode:SetAttribute("ResourceType", resourceType)
    resourceNode:SetAttribute("SpawnTime", tick())
    resourceNode:SetAttribute("Harvestable", true)
    
    -- Add to workspace
    resourceNode.Parent = workspace.ResourceNodes
    
    return resourceNode
end

return WorldGenerator
```

#### Basic Underwater Environment Setup
```lua
-- EnvironmentManager.lua - MVP atmosphere
local EnvironmentManager = {}

function EnvironmentManager:SetupUnderwaterEnvironment()
    local lighting = game:GetService("Lighting")
    
    -- Underwater lighting settings
    lighting.Brightness = 1.5
    lighting.Ambient = Color3.fromRGB(100, 150, 200) -- Blue-green tint
    lighting.OutdoorAmbient = Color3.fromRGB(80, 120, 160)
    lighting.TimeOfDay = "14:00:00" -- Consistent midday lighting
    lighting.GeographicLatitude = 0
    
    -- Add atmospheric effects
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density = 0.4 -- Slightly hazy for underwater feel
    atmosphere.Offset = 0.2
    atmosphere.Color = Color3.fromRGB(150, 200, 255)
    atmosphere.Decay = Color3.fromRGB(100, 150, 200)
    atmosphere.Glare = 0.5
    atmosphere.Haze = 0.3
    atmosphere.Parent = lighting
    
    print("Underwater environment configured")
end

function EnvironmentManager:SpawnAmbientFish()
    -- Simple fish movement for atmosphere (non-interactive)
    local fishCount = 20
    
    for i = 1, fishCount do
        local fish = Instance.new("Part")
        fish.Name = "AmbientFish_" .. i
        fish.Size = Vector3.new(1, 0.5, 2)
        fish.Color = Color3.fromRGB(
            math.random(100, 255),
            math.random(100, 255), 
            math.random(100, 255)
        )
        fish.Material = Enum.Material.Neon
        fish.Shape = Enum.PartType.Block
        fish.CanCollide = false
        fish.Anchored = true
        
        -- Random position in world
        fish.Position = Vector3.new(
            math.random(-90, 90),
            math.random(-15, -5),
            math.random(-90, 90)
        )
        
        fish.Parent = workspace.EnvironmentalAssets
        
        -- Simple back-and-forth movement
        spawn(function()
            local startPos = fish.Position
            local direction = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
            local speed = math.random(2, 5)
            
            while fish.Parent do
                fish.Position = fish.Position + (direction * speed * 0.1)
                
                -- Reverse direction occasionally
                if math.random() < 0.01 then
                    direction = -direction
                end
                
                wait(0.1)
            end
        end)
    end
end

return EnvironmentManager
```

**Week 2 Deliverables:**
- 200x200 stud underwater world with proper atmosphere
- Grid-based resource spawning system
- Basic environmental assets (ambient fish)
- Simple terrain generation using Roblox Terrain API

### Week 3: Core Player Systems

#### Player Data Management
```lua
-- PlayerDataManager.lua - MVP data structure
local PlayerDataManager = {}
local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("AquaticMetropolis_PlayerData_v1")

-- MVP Player Data Structure
local DEFAULT_PLAYER_DATA = {
    inventory = {
        Kelp = 0,
        Rock = 0, 
        Pearl = 0
    },
    tools = {}, -- Array of owned tools with durability
    crafted = {}, -- Tracking for achievements/progression
    playtime = 0,
    resourcesGathered = {
        total = 0,
        Kelp = 0,
        Rock = 0,
        Pearl = 0
    },
    buildingsPlaced = 0,
    joinDate = tick(),
    lastSave = tick()
}

function PlayerDataManager:LoadPlayerData(player)
    local success, playerData = pcall(function()
        return PlayerDataStore:GetAsync(player.UserId)
    end)
    
    if success and playerData then
        -- Merge with defaults in case of new fields
        for key, value in pairs(DEFAULT_PLAYER_DATA) do
            if playerData[key] == nil then
                playerData[key] = value
            end
        end
        print("Loaded data for", player.Name)
        return playerData
    else
        print("Using default data for", player.Name)
        return DEFAULT_PLAYER_DATA
    end
end

function PlayerDataManager:SavePlayerData(player, playerData)
    playerData.lastSave = tick()
    
    local success = pcall(function()
        PlayerDataStore:SetAsync(player.UserId, playerData)
    end)
    
    if not success then
        warn("Failed to save data for", player.Name)
        return false
    end
    
    return true
end

-- Auto-save system
function PlayerDataManager:StartAutoSave(player, playerData)
    spawn(function()
        while player.Parent do
            wait(30) -- Save every 30 seconds
            self:SavePlayerData(player, playerData)
        end
    end)
end

return PlayerDataManager
```

#### Resource Harvesting System
```lua
-- ResourceHarvester.lua - Core harvesting mechanics
local ResourceHarvester = {}
local ResourceData = require(ReplicatedStorage.SharedModules.ResourceData)
local SoundService = game:GetService("SoundService")

-- Player resource harvesting
function ResourceHarvester:HarvestResource(player, resourceNode)
    -- Validate resource node
    if not resourceNode:GetAttribute("Harvestable") then
        return false, "Resource not available"
    end
    
    local resourceType = resourceNode:GetAttribute("ResourceType")
    local resourceData = ResourceData[resourceType]
    
    if not resourceData then
        return false, "Invalid resource"
    end
    
    -- Get player data
    local playerData = self:GetPlayerData(player)
    
    -- Check tool requirements (future expansion)
    if resourceData.requiresTool then
        local hasTool = self:PlayerHasTool(player, resourceData.requiresTool)
        if not hasTool then
            return false, "Requires " .. resourceData.requiresTool
        end
    end
    
    -- Add resource to inventory
    playerData.inventory[resourceType] = playerData.inventory[resourceType] + resourceData.harvestValue
    playerData.resourcesGathered[resourceType] = playerData.resourcesGathered[resourceType] + resourceData.harvestValue
    playerData.resourcesGathered.total = playerData.resourcesGathered.total + resourceData.harvestValue
    
    -- Handle resource node respawn
    self:StartResourceRespawn(resourceNode, resourceData.respawnTime)
    
    -- Play harvest sound
    self:PlayHarvestSound(player, resourceData.harvestSound)
    
    -- Update UI
    self:UpdatePlayerUI(player, playerData)
    
    return true, "Harvested " .. resourceData.displayName
end

function ResourceHarvester:StartResourceRespawn(resourceNode, respawnTime)
    -- Mark as unharvestabl
    resourceNode:SetAttribute("Harvestable", false)
    
    -- Hide node
    resourceNode.Transparency = 0.8
    resourceNode.CanTouch = false
    
    -- Start respawn timer
    delay(respawnTime, function()
        if resourceNode.Parent then
            resourceNode.Transparency = 0
            resourceNode.CanTouch = true
            resourceNode:SetAttribute("Harvestable", true)
            resourceNode:SetAttribute("SpawnTime", tick())
        end
    end)
end

function ResourceHarvester:PlayHarvestSound(player, soundId)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.5
    sound.Parent = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    
    if sound.Parent then
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end
end

return ResourceHarvester
```

#### MVP Inventory System
```lua
-- InventoryManager.lua - Simple 5-slot inventory
local InventoryManager = {}
local MAX_INVENTORY_SLOTS = 5

function InventoryManager:CanAddItem(playerData, itemType, quantity)
    local currentTotal = 0
    
    -- Count current items
    for _, count in pairs(playerData.inventory) do
        currentTotal = currentTotal + count
    end
    
    -- Check if adding would exceed limit
    if currentTotal + quantity > MAX_INVENTORY_SLOTS then
        return false, "Inventory full (" .. MAX_INVENTORY_SLOTS .. " items max)"
    end
    
    return true
end

function InventoryManager:AddItem(playerData, itemType, quantity)
    local canAdd, message = self:CanAddItem(playerData, itemType, quantity)
    
    if not canAdd then
        return false, message
    end
    
    playerData.inventory[itemType] = (playerData.inventory[itemType] or 0) + quantity
    return true, "Added " .. quantity .. " " .. itemType
end

function InventoryManager:RemoveItem(playerData, itemType, quantity)
    local currentAmount = playerData.inventory[itemType] or 0
    
    if currentAmount < quantity then
        return false, "Insufficient " .. itemType
    end
    
    playerData.inventory[itemType] = currentAmount - quantity
    return true, "Removed " .. quantity .. " " .. itemType
end

function InventoryManager:GetInventoryUI(playerData)
    -- Return simple inventory display data
    local inventoryDisplay = {}
    
    for itemType, count in pairs(playerData.inventory) do
        if count > 0 then
            table.insert(inventoryDisplay, {
                type = itemType,
                count = count,
                displayName = ResourceData[itemType] and ResourceData[itemType].displayName or itemType
            })
        end
    end
    
    return inventoryDisplay
end

return InventoryManager
```

**Week 3 Deliverables:**
- Player data persistence system with DataStore integration
- Resource harvesting mechanics with server-side validation
- 5-slot inventory system with overflow protection  
- Basic sound effects for harvesting actions

### Week 4: Basic UI & Crafting System

#### MVP User Interface
```lua
-- UIController.lua - Main interface management
local UIController = {}
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function UIController:CreateMainInterface()
    -- Main screen GUI
    local mainScreen = Instance.new("ScreenGui")
    mainScreen.Name = "AquaticMetropolisUI"
    mainScreen.ResetOnSpawn = false
    mainScreen.Parent = playerGui
    
    -- Inventory frame
    local inventoryFrame = self:CreateInventoryFrame(mainScreen)
    
    -- Resource counter frame
    local resourceFrame = self:CreateResourceFrame(mainScreen)
    
    -- Crafting frame (initially hidden)
    local craftingFrame = self:CreateCraftingFrame(mainScreen)
    
    -- Toggle buttons
    self:CreateToggleButtons(mainScreen, inventoryFrame, craftingFrame)
    
    return mainScreen
end

function UIController:CreateInventoryFrame(parent)
    local frame = Instance.new("Frame")
    frame.Name = "InventoryFrame"
    frame.Size = UDim2.new(0, 300, 0, 200)
    frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(100, 200, 255)
    frame.Parent = parent
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Inventory (5 slots)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    -- Inventory slots
    for i = 1, 5 do
        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. i
        slot.Size = UDim2.new(0, 50, 0, 50)
        slot.Position = UDim2.new(0, 10 + ((i-1) * 55), 0, 40)
        slot.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
        slot.BorderColor3 = Color3.fromRGB(100, 150, 200)
        slot.Parent = frame
        
        -- Item icon (will be updated dynamically)
        local icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(1, 0, 0.7, 0)
        icon.Position = UDim2.new(0, 0, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = ""
        icon.TextColor3 = Color3.fromRGB(255, 255, 255)
        icon.TextScaled = true
        icon.Font = Enum.Font.Gotham
        icon.Parent = slot
        
        -- Item count
        local count = Instance.new("TextLabel") 
        count.Name = "Count"
        count.Size = UDim2.new(1, 0, 0.3, 0)
        count.Position = UDim2.new(0, 0, 0.7, 0)
        count.BackgroundTransparency = 1
        count.Text = ""
        count.TextColor3 = Color3.fromRGB(200, 200, 200)
        count.TextScaled = true
        count.Font = Enum.Font.Gotham
        count.Parent = slot
    end
    
    return frame
end

function UIController:CreateResourceFrame(parent)
    local frame = Instance.new("Frame")
    frame.Name = "ResourceFrame"
    frame.Size = UDim2.new(0, 200, 0, 100)
    frame.Position = UDim2.new(1, -220, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(100, 200, 255)
    frame.Parent = parent
    
    -- Resource counters
    local resources = {"Kelp", "Rock", "Pearl"}
    for i, resourceType in ipairs(resources) do
        local counter = Instance.new("TextLabel")
        counter.Name = resourceType .. "Counter"
        counter.Size = UDim2.new(1, 0, 0, 25)
        counter.Position = UDim2.new(0, 0, 0, (i-1) * 25)
        counter.BackgroundTransparency = 1
        counter.Text = resourceType .. ": 0"
        counter.TextColor3 = Color3.fromRGB(255, 255, 255)
        counter.TextScaled = true
        counter.Font = Enum.Font.Gotham
        counter.TextXAlignment = Enum.TextXAlignment.Left
        counter.Parent = frame
    end
    
    return frame
end

function UIController:UpdateInventoryDisplay(inventoryData)
    local inventoryFrame = playerGui:FindFirstChild("AquaticMetropolisUI"):FindFirstChild("InventoryFrame")
    if not inventoryFrame then return end
    
    -- Clear all slots first
    for i = 1, 5 do
        local slot = inventoryFrame:FindFirstChild("Slot" .. i)
        if slot then
            slot.Icon.Text = ""
            slot.Count.Text = ""
            slot.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
        end
    end
    
    -- Fill slots with inventory items
    local slotIndex = 1
    for itemType, count in pairs(inventoryData) do
        if count > 0 and slotIndex <= 5 then
            local slot = inventoryFrame:FindFirstChild("Slot" .. slotIndex)
            if slot then
                -- Set icon based on item type
                if itemType == "Kelp" then
                    slot.Icon.Text = "🌿"
                    slot.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                elseif itemType == "Rock" then
                    slot.Icon.Text = "🪨"
                    slot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                elseif itemType == "Pearl" then
                    slot.Icon.Text = "⚪"
                    slot.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
                end
                
                slot.Count.Text = tostring(count)
                slotIndex = slotIndex + 1
            end
        end
    end
end

return UIController
```

#### MVP Crafting System
```lua
-- CraftingSystem.lua - Basic crafting implementation
local CraftingSystem = {}
local CraftingData = require(ReplicatedStorage.SharedModules.CraftingData)
local InventoryManager = require(ServerScriptService.Core.InventoryManager)

function CraftingSystem:CanCraft(playerData, recipeId)
    local recipe = CraftingData[recipeId]
    if not recipe then
        return false, "Recipe not found"
    end
    
    -- Check if player has required ingredients
    for ingredient, required in pairs(recipe.ingredients) do
        local playerAmount = playerData.inventory[ingredient] or 0
        if playerAmount < required then
            return false, "Need " .. required .. " " .. ingredient .. " (have " .. playerAmount .. ")"
        end
    end
    
    return true
end

function CraftingSystem:CraftItem(player, playerData, recipeId)
    local canCraft, message = self:CanCraft(playerData, recipeId)
    if not canCraft then
        return false, message
    end
    
    local recipe = CraftingData[recipeId]
    
    -- Remove ingredients from inventory
    for ingredient, required in pairs(recipe.ingredients) do
        local success = InventoryManager:RemoveItem(playerData, ingredient, required)
        if not success then
            return false, "Failed to remove " .. ingredient
        end
    end
    
    -- Add crafted item
    if recipe.buildable then
        -- Add to buildable items list
        table.insert(playerData.buildables, recipeId)
        playerData.crafted[recipeId] = (playerData.crafted[recipeId] or 0) + 1
    else
        -- Add tool to tools list
        local tool = {
            type = recipeId,
            durability = recipe.durability,
            crafted = tick()
        }
        table.insert(playerData.tools, tool)
        playerData.crafted[recipeId] = (playerData.crafted[recipeId] or 0) + 1
    end
    
    -- Track analytics
    self:TrackCrafting(player, recipeId)
    
    return true, "Crafted " .. recipe.displayName
end

function CraftingSystem:GetAvailableRecipes(playerData)
    local available = {}
    
    for recipeId, recipe in pairs(CraftingData) do
        local canCraft = self:CanCraft(playerData, recipeId)
        
        table.insert(available, {
            id = recipeId,
            recipe = recipe,
            canCraft = canCraft
        })
    end
    
    return available
end

return CraftingSystem
```

**Week 4 Deliverables:**
- Complete UI system with inventory and resource displays
- 5 essential crafting recipes implemented
- Crafting interface with visual feedback
- Basic tutorial system for new players

---

# Milestone Gate: Week 8 MVP Beta Decision

## Success Criteria Check
- **Core Loop Complete:** Resource gathering → Crafting → Building → Repeat
- **Performance Target:** >30 FPS with 10 concurrent players
- **Content Validation:** 15-20 minutes of engaging gameplay
- **Technical Stability:** <5% crash rate during testing

## Beta Testing Protocol (50-100 Invited Players)
```lua
-- BetaTesting.lua - Metrics collection for gate decision
local BetaTesting = {}

local BETA_METRICS = {
    sessionLength = {}, -- Track average session time
    dayThreeReturn = {}, -- Track 3-day retention
    coreLoopCompletion = {}, -- Track full gather→craft→build completion
    bugReports = {}, -- Critical issues log
    playerFeedback = {} -- Satisfaction scores
}

function BetaTesting:TrackBetaSession(player, sessionData)
    table.insert(BETA_METRICS.sessionLength, sessionData.duration)
    
    -- Gate decision metrics
    local avgSession = self:CalculateAverage(BETA_METRICS.sessionLength)
    local day3Retention = #BETA_METRICS.dayThreeReturn / #BETA_METRICS.sessionLength
    
    print("Current metrics - Avg Session:", avgSession, "minutes, D3 Retention:", day3Retention * 100, "%")
    
    -- Decision gate check
    if avgSession >= 15 and day3Retention >= 0.6 then
        print("✅ GATE PASSED: Proceed to Phase 1")
        return true
    elseif #BETA_METRICS.sessionLength >= 100 then -- Minimum sample size
        print("❌ GATE FAILED: Iterate MVP or pivot")
        return false
    end
    
    return nil -- Not enough data yet
end
```

**Decision Points:**
- **✅ PROCEED:** >15 min sessions, >60% D3 retention → Move to Phase 1
- **⚠️ ITERATE:** Close to targets → Extend MVP by 2 weeks, add 1-2 features
- **❌ PIVOT:** Poor metrics → Reassess core concept or reduce scope further

---

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Review MVP Analysis Option C strategy", "status": "completed", "activeForm": "Reviewing MVP Analysis Option C strategy"}, {"content": "Cross-reference with original development plan", "status": "completed", "activeForm": "Cross-referencing with original development plan"}, {"content": "Extract technical details from design document", "status": "completed", "activeForm": "Extracting technical details from design document"}, {"content": "Create Phase C development plan", "status": "completed", "activeForm": "Creating Phase C development plan"}, {"content": "Define milestone gates and success metrics", "status": "in_progress", "activeForm": "Defining milestone gates and success metrics"}]