--[[
BuildingSystem.lua

Purpose: Basic building placement system for Week 4 structure creation
Dependencies: CraftingData, PlayerDataManager, StaminaSystem
Last Modified: Phase 0 - Week 4
Performance Notes: Efficient placement validation, collision detection, ownership tracking

Public Methods:
- Initialize(): Set up building system and events
- PlaceBuilding(player, buildingType, position, rotation): Place structure
- RemoveBuilding(player, buildingId): Remove owned structure
- ValidatePlacement(buildingType, position, rotation): Check placement validity
- GetPlayerBuildings(player): Return all buildings owned by player
]]--

local BuildingSystem = {}

-- Import dependencies
local CraftingData = require(game.ReplicatedStorage.SharedModules.CraftingData)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Building system state tracking
local placedBuildings = {} -- [buildingId] = buildingData
local playerBuildings = {} -- [playerId] = {buildingId1, buildingId2, ...}
local nextBuildingId = 1

-- Events
local buildingEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local BuildingRequestEvent, BuildingUpdateEvent

-- Building system configuration
local BUILDING_CONFIG = {
    -- Placement restrictions
    maxBuildingsPerPlayer = 50,     -- Total building limit per player
    maxBuildingsPerArea = 20,       -- Buildings in 100x100 stud area
    placementRange = 25,            -- Max distance from player to place
    
    -- Collision detection
    collisionPadding = 2,           -- Extra space around buildings
    terrainChecking = true,         -- Validate terrain collision
    resourceNodeChecking = true,    -- Avoid placing on resource nodes
    
    -- Ownership and permissions
    protectionRadius = 50,          -- Area around buildings protected from others
    ownershipTransfer = false,      -- Buildings can't be transferred yet
    
    -- Building durability (future expansion)
    enableDurability = false,       -- Buildings don't degrade yet
    weatherEffects = false,         -- No weather damage yet
    
    -- Construction mechanics
    instantPlacement = true,        -- No construction time for basic system
    resourceConsumption = true,     -- Consume materials immediately
    
    -- Visual feedback
    placementGhosts = true,         -- Show placement preview
    validationIndicators = true,    -- Show valid/invalid placement
    
    -- Performance limits
    maxPlacementsPerMinute = 10,    -- Rate limiting per player
    validationCacheTime = 5,        -- Cache validation results (seconds)
    updateFrequency = 0.1           -- Building state update frequency
}

-- Building data template
local BUILDING_TEMPLATE = {
    buildingId = "",
    buildingType = "",
    displayName = "",
    ownerId = 0,
    ownerName = "",
    
    -- Placement information
    position = Vector3.new(0, 0, 0),
    rotation = Vector3.new(0, 0, 0),
    size = Vector3.new(4, 4, 4),
    
    -- Timestamps
    placedTime = 0,
    lastModified = 0,
    
    -- Status
    isComplete = true,      -- For future construction system
    health = 100,           -- For future durability system
    
    -- Visual properties
    model = nil,            -- Reference to workspace model
    
    -- Metadata
    customName = nil,       -- Player-assigned name
    permissions = {},       -- Who can interact with building
    
    -- Statistics
    timesInteracted = 0,
    lastInteraction = 0
}

function BuildingSystem:Initialize()
    print("🏗️ Initializing BuildingSystem...")
    
    -- Create or get building events
    if not buildingEvents then
        buildingEvents = Instance.new("Folder")
        buildingEvents.Name = "RemoteEvents"
        buildingEvents.Parent = ReplicatedStorage
    end
    
    -- Create building events
    BuildingRequestEvent = buildingEvents:FindFirstChild("BuildingRequest") or Instance.new("RemoteEvent")
    BuildingRequestEvent.Name = "BuildingRequest"
    BuildingRequestEvent.Parent = buildingEvents
    
    BuildingUpdateEvent = buildingEvents:FindFirstChild("BuildingUpdate") or Instance.new("RemoteEvent")
    BuildingUpdateEvent.Name = "BuildingUpdate"
    BuildingUpdateEvent.Parent = buildingEvents
    
    -- Connect event handlers
    BuildingRequestEvent.OnServerEvent:Connect(function(player, action, ...)
        self:HandleBuildingRequest(player, action, ...)
    end)
    
    -- Initialize building storage folder
    self:CreateBuildingFolder()
    
    -- Initialize player building tracking on join
    game.Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerBuildings(player)
    end)
    
    -- Cleanup on player leave
    game.Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerBuildings(player)
    end)
    
    -- Start building system monitoring
    self:StartBuildingMonitoring()
    
    print("✅ BuildingSystem initialized")
end

function BuildingSystem:HandleBuildingRequest(player, action, ...)
    local args = {...}
    
    if action == "PlaceBuilding" then
        local buildingType = args[1]
        local position = args[2]
        local rotation = args[3] or Vector3.new(0, 0, 0)
        self:PlaceBuilding(player, buildingType, position, rotation)
        
    elseif action == "RemoveBuilding" then
        local buildingId = args[1]
        self:RemoveBuilding(player, buildingId)
        
    elseif action == "ValidatePlacement" then
        local buildingType = args[1]
        local position = args[2]
        local rotation = args[3] or Vector3.new(0, 0, 0)
        local isValid, reason = self:ValidatePlacement(buildingType, position, rotation, player)
        
        BuildingUpdateEvent:FireClient(player, "PlacementValidation", {
            valid = isValid,
            reason = reason,
            position = position
        })
        
    elseif action == "GetPlayerBuildings" then
        local buildings = self:GetPlayerBuildings(player)
        BuildingUpdateEvent:FireClient(player, "PlayerBuildingsUpdate", buildings)
        
    elseif action == "GetBuildingInfo" then
        local buildingId = args[1]
        local buildingInfo = self:GetBuildingInfo(buildingId)
        BuildingUpdateEvent:FireClient(player, "BuildingInfoUpdate", {
            buildingId = buildingId,
            info = buildingInfo
        })
        
    elseif action == "InteractWithBuilding" then
        local buildingId = args[1]
        self:InteractWithBuilding(player, buildingId)
    end
end

function BuildingSystem:PlaceBuilding(player, buildingType, position, rotation)
    -- Validate building type
    local recipe = CraftingData:GetRecipe(buildingType)
    if not recipe or not recipe.buildable then
        BuildingUpdateEvent:FireClient(player, "PlacementError", "Invalid building type")
        return false
    end
    
    -- Validate placement
    local isValid, reason = self:ValidatePlacement(buildingType, position, rotation, player)
    if not isValid then
        BuildingUpdateEvent:FireClient(player, "PlacementError", reason)
        return false
    end
    
    -- Check player building limits
    local playerId = player.UserId
    local playerBuildingCount = #(playerBuildings[playerId] or {})
    if playerBuildingCount >= BUILDING_CONFIG.maxBuildingsPerPlayer then
        BuildingUpdateEvent:FireClient(player, "PlacementError", "Building limit reached")
        return false
    end
    
    -- Check if player has the building item in inventory
    if not self:PlayerHasBuildingItem(player, buildingType) then
        BuildingUpdateEvent:FireClient(player, "PlacementError", "You don't have this building item")
        return false
    end
    
    -- Consume stamina
    local StaminaSystem = require(script.Parent.StaminaSystem)
    local staminaConsumed = StaminaSystem:ConsumeActivityStamina(player, "build")
    if not staminaConsumed then
        BuildingUpdateEvent:FireClient(player, "PlacementError", "Not enough stamina")
        return false
    end
    
    -- Create building data
    local buildingId = "building_" .. tick() .. "_" .. nextBuildingId
    nextBuildingId = nextBuildingId + 1
    
    local buildingData = {}
    for key, value in pairs(BUILDING_TEMPLATE) do
        buildingData[key] = value
    end
    
    buildingData.buildingId = buildingId
    buildingData.buildingType = buildingType
    buildingData.displayName = recipe.displayName
    buildingData.ownerId = playerId
    buildingData.ownerName = player.Name
    buildingData.position = position
    buildingData.rotation = rotation
    buildingData.size = recipe.size or Vector3.new(4, 4, 4)
    buildingData.placedTime = tick()
    buildingData.lastModified = tick()
    
    -- Create visual model
    local model = self:CreateBuildingModel(buildingData, recipe)
    if not model then
        BuildingUpdateEvent:FireClient(player, "PlacementError", "Failed to create building model")
        return false
    end
    
    buildingData.model = model
    
    -- Remove building item from player inventory
    self:ConsumeBuildingItem(player, buildingType)
    
    -- Store building data
    placedBuildings[buildingId] = buildingData
    
    -- Track player's buildings
    if not playerBuildings[playerId] then
        playerBuildings[playerId] = {}
    end
    table.insert(playerBuildings[playerId], buildingId)
    
    -- Save updated player data
    self:SavePlayerBuildingData(player)
    
    -- Notify client of successful placement
    BuildingUpdateEvent:FireClient(player, "BuildingPlaced", {
        buildingId = buildingId,
        buildingType = buildingType,
        position = position,
        rotation = rotation
    })
    
    -- Notify nearby players
    self:NotifyNearbyPlayers(position, "BuildingPlaced", {
        buildingId = buildingId,
        ownerName = player.Name,
        buildingType = buildingType
    })
    
    print("🏠 Player", player.Name, "placed building:", buildingType, "at", position)
    return true, buildingData
end

function BuildingSystem:ValidatePlacement(buildingType, position, rotation, player)
    local recipe = CraftingData:GetRecipe(buildingType)
    if not recipe or not recipe.buildable then
        return false, "Invalid building type"
    end
    
    local size = recipe.size or Vector3.new(4, 4, 4)
    
    -- Check placement range from player
    if player then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local playerPosition = character.HumanoidRootPart.Position
            local distance = (position - playerPosition).Magnitude
            if distance > BUILDING_CONFIG.placementRange then
                return false, "Too far from player"
            end
        end
    end
    
    -- Check terrain collision
    if BUILDING_CONFIG.terrainChecking then
        local isValidTerrain = self:CheckTerrainCollision(position, size, rotation)
        if not isValidTerrain then
            return false, "Invalid terrain placement"
        end
    end
    
    -- Check collision with other buildings
    local collisionFree = self:CheckBuildingCollision(position, size, rotation)
    if not collisionFree then
        return false, "Collision with existing building"
    end
    
    -- Check collision with resource nodes
    if BUILDING_CONFIG.resourceNodeChecking then
        local resourceFree = self:CheckResourceNodeCollision(position, size, rotation)
        if not resourceFree then
            return false, "Too close to resource nodes"
        end
    end
    
    -- Check area building density
    local buildingCount = self:GetBuildingsInArea(position, 50) -- 50 stud radius
    if #buildingCount >= BUILDING_CONFIG.maxBuildingsPerArea then
        return false, "Area has too many buildings"
    end
    
    return true, "Placement valid"
end

function BuildingSystem:CheckTerrainCollision(position, size, rotation)
    -- Simple terrain collision check using raycasting
    local raycast = workspace:Raycast(
        position + Vector3.new(0, size.Y/2, 0),
        Vector3.new(0, -size.Y - 5, 0)
    )
    
    if not raycast then
        return false -- No terrain found below
    end
    
    -- Check if terrain is approximately flat
    local surfaceNormal = raycast.Normal
    local angle = math.acos(surfaceNormal:Dot(Vector3.new(0, 1, 0)))
    
    if math.deg(angle) > 30 then -- Max 30 degree slope
        return false
    end
    
    return true
end

function BuildingSystem:CheckBuildingCollision(position, size, rotation)
    local padding = BUILDING_CONFIG.collisionPadding
    
    for _, building in pairs(placedBuildings) do
        local distance = (position - building.position).Magnitude
        local combinedSize = (size.Magnitude + building.size.Magnitude) / 2 + padding
        
        if distance < combinedSize then
            return false -- Collision detected
        end
    end
    
    return true
end

function BuildingSystem:CheckResourceNodeCollision(position, size, rotation)
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then return true end
    
    local minDistance = size.Magnitude / 2 + 5 -- 5 stud buffer
    
    for _, typeFolder in ipairs(resourceFolder:GetChildren()) do
        if typeFolder:IsA("Folder") then
            for _, resource in ipairs(typeFolder:GetChildren()) do
                if resource:IsA("Part") then
                    local distance = (position - resource.Position).Magnitude
                    if distance < minDistance then
                        return false
                    end
                end
            end
        end
    end
    
    return true
end

function BuildingSystem:GetBuildingsInArea(centerPosition, radius)
    local buildingsInArea = {}
    
    for buildingId, building in pairs(placedBuildings) do
        local distance = (centerPosition - building.position).Magnitude
        if distance <= radius then
            table.insert(buildingsInArea, buildingId)
        end
    end
    
    return buildingsInArea
end

function BuildingSystem:CreateBuildingModel(buildingData, recipe)
    -- Get or create PlayerBuildings folder
    local buildingsFolder = workspace:FindFirstChild("PlayerBuildings")
    if not buildingsFolder then
        buildingsFolder = Instance.new("Folder")
        buildingsFolder.Name = "PlayerBuildings"
        buildingsFolder.Parent = workspace
    end
    
    -- Create the building model
    local model = Instance.new("Part")
    model.Name = buildingData.buildingId
    model.Size = buildingData.size
    model.Position = buildingData.position
    model.Rotation = buildingData.rotation
    model.Anchored = true
    model.CanCollide = true
    
    -- Apply visual properties from recipe
    if recipe.visual then
        local visual = recipe.visual
        model.Shape = Enum.PartType[visual.shape] or Enum.PartType.Block
        model.Color = visual.color or Color3.fromRGB(150, 150, 150)
        model.Material = visual.material or Enum.Material.Concrete
    else
        -- Default appearance
        model.Color = Color3.fromRGB(120, 120, 120)
        model.Material = Enum.Material.Concrete
    end
    
    -- Add building identification attributes
    model:SetAttribute("BuildingId", buildingData.buildingId)
    model:SetAttribute("BuildingType", buildingData.buildingType)
    model:SetAttribute("OwnerId", buildingData.ownerId)
    model:SetAttribute("OwnerName", buildingData.ownerName)
    model:SetAttribute("PlacedTime", buildingData.placedTime)
    
    -- Add interaction detection
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 15
    clickDetector.Parent = model
    
    clickDetector.MouseClick:Connect(function(player)
        self:InteractWithBuilding(player, buildingData.buildingId)
    end)
    
    -- Add name tag (optional)
    if buildingData.customName or buildingData.displayName then
        local nameTag = self:CreateBuildingNameTag(buildingData.customName or buildingData.displayName)
        nameTag.Parent = model
    end
    
    model.Parent = buildingsFolder
    return model
end

function BuildingSystem:CreateBuildingNameTag(name)
    local gui = Instance.new("BillboardGui")
    gui.Name = "NameTag"
    gui.Size = UDim2.new(0, 200, 0, 50)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    return gui
end

function BuildingSystem:RemoveBuilding(player, buildingId)
    local building = placedBuildings[buildingId]
    if not building then
        BuildingUpdateEvent:FireClient(player, "RemovalError", "Building not found")
        return false
    end
    
    -- Check ownership
    if building.ownerId ~= player.UserId then
        BuildingUpdateEvent:FireClient(player, "RemovalError", "You don't own this building")
        return false
    end
    
    -- Consume stamina
    local StaminaSystem = require(script.Parent.StaminaSystem)
    local staminaConsumed = StaminaSystem:ConsumeActivityStamina(player, "build_remove")
    if not staminaConsumed then
        BuildingUpdateEvent:FireClient(player, "RemovalError", "Not enough stamina")
        return false
    end
    
    -- Return building item to inventory (optional)
    self:ReturnBuildingItem(player, building.buildingType)
    
    -- Remove visual model
    if building.model and building.model.Parent then
        building.model:Destroy()
    end
    
    -- Remove from tracking
    placedBuildings[buildingId] = nil
    
    local playerId = player.UserId
    if playerBuildings[playerId] then
        for i, id in ipairs(playerBuildings[playerId]) do
            if id == buildingId then
                table.remove(playerBuildings[playerId], i)
                break
            end
        end
    end
    
    -- Save updated player data
    self:SavePlayerBuildingData(player)
    
    -- Notify client
    BuildingUpdateEvent:FireClient(player, "BuildingRemoved", {
        buildingId = buildingId
    })
    
    print("🏚️ Player", player.Name, "removed building:", buildingId)
    return true
end

function BuildingSystem:InteractWithBuilding(player, buildingId)
    local building = placedBuildings[buildingId]
    if not building then return end
    
    -- Update interaction statistics
    building.timesInteracted = building.timesInteracted + 1
    building.lastInteraction = tick()
    
    -- Send building information to player
    BuildingUpdateEvent:FireClient(player, "BuildingInteraction", {
        buildingId = buildingId,
        buildingType = building.buildingType,
        displayName = building.displayName,
        ownerName = building.ownerName,
        placedTime = building.placedTime,
        isOwner = (building.ownerId == player.UserId)
    })
end

function BuildingSystem:PlayerHasBuildingItem(player, buildingType)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.inventory then return false end
    
    local itemCount = playerData.inventory[buildingType] or 0
    return itemCount > 0
end

function BuildingSystem:ConsumeBuildingItem(player, buildingType)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return false end
    
    playerData.inventory[buildingType] = (playerData.inventory[buildingType] or 0) - 1
    if playerData.inventory[buildingType] <= 0 then
        playerData.inventory[buildingType] = nil
    end
    
    PlayerDataManager:SavePlayerData(player, playerData)
    return true
end

function BuildingSystem:ReturnBuildingItem(player, buildingType)
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return false end
    
    playerData.inventory = playerData.inventory or {}
    playerData.inventory[buildingType] = (playerData.inventory[buildingType] or 0) + 1
    
    PlayerDataManager:SavePlayerData(player, playerData)
    return true
end

function BuildingSystem:GetPlayerBuildings(player)
    local playerId = player.UserId
    local buildings = {}
    
    if playerBuildings[playerId] then
        for _, buildingId in ipairs(playerBuildings[playerId]) do
            local building = placedBuildings[buildingId]
            if building then
                table.insert(buildings, {
                    buildingId = buildingId,
                    buildingType = building.buildingType,
                    displayName = building.displayName,
                    position = building.position,
                    placedTime = building.placedTime,
                    health = building.health
                })
            end
        end
    end
    
    return buildings
end

function BuildingSystem:GetBuildingInfo(buildingId)
    return placedBuildings[buildingId]
end

function BuildingSystem:NotifyNearbyPlayers(position, eventType, data)
    local notifyRadius = 50 -- studs
    
    for _, player in pairs(game.Players:GetPlayers()) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local distance = (position - character.HumanoidRootPart.Position).Magnitude
            if distance <= notifyRadius then
                BuildingUpdateEvent:FireClient(player, eventType, data)
            end
        end
    end
end

function BuildingSystem:CreateBuildingFolder()
    local buildingsFolder = workspace:FindFirstChild("PlayerBuildings")
    if not buildingsFolder then
        buildingsFolder = Instance.new("Folder")
        buildingsFolder.Name = "PlayerBuildings"
        buildingsFolder.Parent = workspace
    end
end

function BuildingSystem:InitializePlayerBuildings(player)
    local playerId = player.UserId
    playerBuildings[playerId] = {}
    
    -- Load existing buildings from player data
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if playerData and playerData.buildings then
        for _, buildingData in ipairs(playerData.buildings) do
            if buildingData.buildingId then
                -- Restore building to world
                local recipe = CraftingData:GetRecipe(buildingData.buildingType)
                if recipe then
                    local model = self:CreateBuildingModel(buildingData, recipe)
                    buildingData.model = model
                    
                    placedBuildings[buildingData.buildingId] = buildingData
                    table.insert(playerBuildings[playerId], buildingData.buildingId)
                end
            end
        end
    end
end

function BuildingSystem:CleanupPlayerBuildings(player)
    local playerId = player.UserId
    
    -- Save building data before cleanup
    self:SavePlayerBuildingData(player)
    
    -- Remove from active tracking
    playerBuildings[playerId] = nil
end

function BuildingSystem:SavePlayerBuildingData(player)
    local playerId = player.UserId
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData then return end
    
    playerData.buildings = {}
    
    if playerBuildings[playerId] then
        for _, buildingId in ipairs(playerBuildings[playerId]) do
            local building = placedBuildings[buildingId]
            if building then
                -- Create save data (exclude model reference)
                local saveData = {}
                for key, value in pairs(building) do
                    if key ~= "model" then
                        saveData[key] = value
                    end
                end
                table.insert(playerData.buildings, saveData)
            end
        end
    end
    
    PlayerDataManager:SavePlayerData(player, playerData)
end

function BuildingSystem:StartBuildingMonitoring()
    spawn(function()
        while true do
            wait(30) -- Check every 30 seconds
            
            -- Clean up any destroyed building models
            for buildingId, building in pairs(placedBuildings) do
                if building.model and not building.model.Parent then
                    -- Model was destroyed, clean up data
                    placedBuildings[buildingId] = nil
                    
                    -- Remove from player tracking
                    for playerId, buildings in pairs(playerBuildings) do
                        for i, id in ipairs(buildings) do
                            if id == buildingId then
                                table.remove(buildings, i)
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
end

function BuildingSystem:GetSystemStats()
    local totalBuildings = 0
    local buildingsByType = {}
    local buildingsByPlayer = {}
    
    for _, building in pairs(placedBuildings) do
        totalBuildings = totalBuildings + 1
        
        buildingsByType[building.buildingType] = (buildingsByType[building.buildingType] or 0) + 1
        buildingsByPlayer[building.ownerId] = (buildingsByPlayer[building.ownerId] or 0) + 1
    end
    
    return {
        totalBuildings = totalBuildings,
        buildingsByType = buildingsByType,
        activeBuilders = 0, -- Count of players with buildings
        averageBuildingsPerPlayer = totalBuildings / math.max(1, game.Players.NumPlayers)
    }
end

return BuildingSystem