--[[
ResourceSpawner.lua

Purpose: Server authoritative resource management for MVP
Dependencies: ResourceData, WorldGenerator
Last Modified: Phase 0 - Week 1
Performance Notes: Handles up to 60 resource nodes efficiently

Public Methods:
- SpawnInitialResources(): Create starting resource nodes
- HarvestResource(player, resourceId): Process resource harvesting
- RespawnResource(resourceId): Handle resource respawning
- CleanupInactiveNodes(): Performance maintenance
]]--

local ResourceSpawner = {}
local ResourceData = require(game.ReplicatedStorage.SharedModules.ResourceData)
local RunService = game:GetService("RunService")

-- Track all resource nodes server-side (authoritative)
local activeResourceNodes = {}
local nextResourceId = 1
local WORLD_BOUNDS = nil -- Will be set from WorldGenerator

-- Performance configuration
local MAX_RESOURCE_NODES = 60
local INTERACTION_RANGE = 10 -- studs
local SPAWN_GRID_SIZE = 15 -- from WorldGenerator

function ResourceSpawner:Initialize()
    -- Get world bounds from WorldGenerator
    local WorldGenerator = require(script.Parent.WorldGenerator)
    WORLD_BOUNDS = WorldGenerator:GetWorldBounds()
    
    -- Create resource folders
    self:CreateResourceFolders()
    
    print("✅ ResourceSpawner initialized")
end

function ResourceSpawner:CreateResourceFolders()
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then
        resourceFolder = Instance.new("Folder")
        resourceFolder.Name = "ResourceNodes"
        resourceFolder.Parent = workspace
    end
    
    -- Create subfolders for each resource type
    local resourceTypes = ResourceData:GetAllResources()
    for resourceType, _ in pairs(resourceTypes) do
        local typeFolder = resourceFolder:FindFirstChild(resourceType)
        if not typeFolder then
            typeFolder = Instance.new("Folder")
            typeFolder.Name = resourceType
            typeFolder.Parent = resourceFolder
        end
    end
end

function ResourceSpawner:SpawnInitialResources()
    print("🌊 Spawning initial resources...")
    
    local spawnCount = {Kelp = 0, Rock = 0, Pearl = 0}
    local totalSpawned = 0
    local maxAttempts = (200 / SPAWN_GRID_SIZE) ^ 2 -- Grid positions available
    local attempts = 0
    
    -- Grid-based spawning with randomization (simplified from procedural generation)
    for x = WORLD_BOUNDS.x.min, WORLD_BOUNDS.x.max, SPAWN_GRID_SIZE do
        for z = WORLD_BOUNDS.z.min, WORLD_BOUNDS.z.max, SPAWN_GRID_SIZE do
            attempts = attempts + 1
            
            if totalSpawned >= MAX_RESOURCE_NODES or attempts > maxAttempts then
                break
            end
            
            -- Random offset to avoid perfect grid appearance
            local spawnPos = Vector3.new(
                x + math.random(-5, 5),
                WORLD_BOUNDS.y.floor + math.random(1, 3), -- Slightly above seafloor
                z + math.random(-5, 5)
            )
            
            -- Validate spawn position (not too close to edges)
            if self:IsValidSpawnPosition(spawnPos) then
                -- Try spawning each resource type based on spawn chance
                local resourceSpawned = false
                local resourceTypes = ResourceData:GetSpawnableResources()
                
                for resourceType, resourceInfo in pairs(resourceTypes) do
                    if math.random() < resourceInfo.spawnChance and not resourceSpawned then
                        local success = self:SpawnResourceNode(resourceType, spawnPos)
                        if success then
                            spawnCount[resourceType] = spawnCount[resourceType] + 1
                            totalSpawned = totalSpawned + 1
                            resourceSpawned = true
                        end
                    end
                end
            end
        end
        
        if totalSpawned >= MAX_RESOURCE_NODES then
            break
        end
    end
    
    print("✅ Resources spawned:")
    for resourceType, count in pairs(spawnCount) do
        print("   " .. resourceType .. ":", count)
    end
    print("📊 Total resource nodes:", totalSpawned)
end

function ResourceSpawner:IsValidSpawnPosition(position)
    -- Check bounds
    if position.X < WORLD_BOUNDS.x.min + 10 or position.X > WORLD_BOUNDS.x.max - 10 or
       position.Z < WORLD_BOUNDS.z.min + 10 or position.Z > WORLD_BOUNDS.z.max - 10 then
        return false
    end
    
    -- Check not too close to other resources
    for _, resourceNode in pairs(activeResourceNodes) do
        local distance = (position - resourceNode.position).Magnitude
        if distance < 8 then -- Minimum 8 studs apart
            return false
        end
    end
    
    return true
end

function ResourceSpawner:SpawnResourceNode(resourceType, position)
    local resourceInfo = ResourceData:GetResourceData(resourceType)
    if not resourceInfo then
        warn("Invalid resource type:", resourceType)
        return false
    end
    
    local resourceId = "resource_" .. nextResourceId
    nextResourceId = nextResourceId + 1
    
    -- Create visual model using procedural generation
    local model = self:CreateResourceModel(resourceType, position, resourceInfo)
    if not model then
        return false
    end
    
    model.Name = resourceId
    model.Parent = workspace.ResourceNodes[resourceType]
    
    -- Track in server state (authoritative)
    activeResourceNodes[resourceId] = {
        id = resourceId,
        type = resourceType,
        position = position,
        model = model,
        harvestable = true,
        spawnTime = tick(),
        lastHarvest = nil,
        respawnTime = resourceInfo.respawnTime
    }
    
    -- Add click detector for harvesting
    self:AddClickDetector(model, resourceId)
    
    return true
end

function ResourceSpawner:CreateResourceModel(resourceType, position, resourceInfo)
    local visual = resourceInfo.visual
    if not visual then
        warn("No visual data for resource:", resourceType)
        return nil
    end
    
    -- Create the base part
    local model = Instance.new("Part")
    model.Name = resourceType .. "_Node"
    model.Size = visual.size
    model.Position = position
    model.Anchored = true
    model.CanCollide = false
    model.Shape = Enum.PartType[visual.shape] or Enum.PartType.Block
    model.Color = visual.color
    model.Material = visual.material
    
    -- Add glow effect if specified
    if visual.glow then
        local pointLight = Instance.new("PointLight")
        pointLight.Color = visual.color
        pointLight.Brightness = 0.5
        pointLight.Range = 8
        pointLight.Parent = model
    end
    
    -- Add floating animation for visual appeal
    if resourceType == "Kelp" then
        self:AddKelpSwayAnimation(model)
    elseif resourceType == "Pearl" then
        self:AddPearlGlowAnimation(model)
    end
    
    -- Set attributes for identification
    model:SetAttribute("ResourceType", resourceType)
    model:SetAttribute("SpawnTime", tick())
    model:SetAttribute("Harvestable", true)
    
    return model
end

function ResourceSpawner:AddClickDetector(model, resourceId)
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = INTERACTION_RANGE
    clickDetector.CursorIcon = "rbxasset://textures/ArrowCursor.png"
    clickDetector.Parent = model
    
    clickDetector.MouseClick:Connect(function(player)
        self:OnResourceClicked(player, resourceId)
    end)
    
    -- Add hover effect
    clickDetector.MouseHoverEnter:Connect(function(player)
        self:OnResourceHoverEnter(model, resourceId)
    end)
    
    clickDetector.MouseHoverLeave:Connect(function(player)
        self:OnResourceHoverLeave(model, resourceId)
    end)
end

function ResourceSpawner:OnResourceClicked(player, resourceId)
    local success, result = self:HarvestResource(player, resourceId)
    
    if success then
        -- Update player inventory through PlayerDataManager
        local PlayerDataManager = require(script.Parent.PlayerDataManager)
        PlayerDataManager:UpdatePlayerData(player, function(playerData)
            local resourceType = result.resourceType
            local amount = result.amount
            
            -- Add to inventory
            playerData.inventory[resourceType] = (playerData.inventory[resourceType] or 0) + amount
            
            -- Track gathering statistics
            playerData.resourcesGathered[resourceType] = (playerData.resourcesGathered[resourceType] or 0) + amount
            playerData.resourcesGathered.total = playerData.resourcesGathered.total + amount
        end)
        
        -- Play harvest sound and effects
        self:PlayHarvestEffects(player, result)
        
        -- Send success message to client
        local harvestEvent = game.ReplicatedStorage:FindFirstChild("HarvestSuccess")
        if harvestEvent then
            harvestEvent:FireClient(player, result)
        end
        
        print("✅", player.Name, "harvested", result.amount, result.displayName)
    else
        -- Send failure message
        local harvestEvent = game.ReplicatedStorage:FindFirstChild("HarvestFailure")  
        if harvestEvent then
            harvestEvent:FireClient(player, result)
        end
        
        print("❌", player.Name, "harvest failed:", result)
    end
end

function ResourceSpawner:HarvestResource(player, resourceId)
    local resourceNode = activeResourceNodes[resourceId]
    
    -- Validate resource exists and is harvestable
    if not resourceNode then
        return false, "Resource not found"
    end
    
    if not resourceNode.harvestable then
        return false, "Resource not ready"
    end
    
    -- Distance check (anti-cheat)
    local playerCharacter = player.Character
    if not playerCharacter or not playerCharacter:FindFirstChild("HumanoidRootPart") then
        return false, "Invalid player position"
    end
    
    local playerPos = playerCharacter.HumanoidRootPart.Position
    local distance = (playerPos - resourceNode.position).Magnitude
    
    if distance > INTERACTION_RANGE then
        return false, "Too far from resource (max " .. INTERACTION_RANGE .. " studs)"
    end
    
    -- Check tool requirements (for future phases)
    local resourceInfo = ResourceData:GetResourceData(resourceNode.type)
    if resourceInfo.requiresTool then
        -- Tool requirement check will be implemented in later phases
        return false, "Requires " .. resourceInfo.requiresTool
    end
    
    -- Process harvest
    resourceNode.harvestable = false
    resourceNode.lastHarvest = tick()
    
    -- Visual feedback - make resource semi-transparent and non-interactive
    if resourceNode.model then
        resourceNode.model.Transparency = 0.7
        resourceNode.model.CanTouch = false
        local clickDetector = resourceNode.model:FindFirstChild("ClickDetector")
        if clickDetector then
            clickDetector.MaxActivationDistance = 0 -- Disable clicking
        end
    end
    
    -- Start respawn timer
    self:StartRespawnTimer(resourceId)
    
    -- Return harvest results
    return true, {
        resourceType = resourceNode.type,
        amount = resourceInfo.harvestValue,
        displayName = resourceInfo.displayName,
        resourceId = resourceId
    }
end

function ResourceSpawner:StartRespawnTimer(resourceId)
    local resourceNode = activeResourceNodes[resourceId]
    if not resourceNode then return end
    
    -- Use delay for respawn timer
    delay(resourceNode.respawnTime, function()
        self:RespawnResource(resourceId)
    end)
end

function ResourceSpawner:RespawnResource(resourceId)
    local resourceNode = activeResourceNodes[resourceId]
    if not resourceNode or not resourceNode.model or not resourceNode.model.Parent then
        return
    end
    
    -- Restore resource to harvestable state
    resourceNode.harvestable = true
    resourceNode.model.Transparency = 0
    resourceNode.model.CanTouch = true
    
    -- Re-enable click detector
    local clickDetector = resourceNode.model:FindFirstChild("ClickDetector")
    if clickDetector then
        clickDetector.MaxActivationDistance = INTERACTION_RANGE
    end
    
    -- Update spawn time
    resourceNode.model:SetAttribute("SpawnTime", tick())
    
    print("♻️ Resource respawned:", resourceNode.type, resourceId)
end

-- Visual effects and animations
function ResourceSpawner:AddKelpSwayAnimation(model)
    spawn(function()
        local originalRotation = model.CFrame
        local swayAmount = 5 -- degrees
        local swaySpeed = 2 -- seconds per sway
        
        while model.Parent do
            -- Sway left
            for i = 0, swayAmount, 0.5 do
                if not model.Parent then break end
                model.CFrame = originalRotation * CFrame.Angles(0, 0, math.rad(i))
                wait(swaySpeed / (swayAmount * 2))
            end
            
            -- Sway right  
            for i = swayAmount, -swayAmount, -0.5 do
                if not model.Parent then break end
                model.CFrame = originalRotation * CFrame.Angles(0, 0, math.rad(i))
                wait(swaySpeed / (swayAmount * 4))
            end
            
            -- Return to center
            for i = -swayAmount, 0, 0.5 do
                if not model.Parent then break end
                model.CFrame = originalRotation * CFrame.Angles(0, 0, math.rad(i))
                wait(swaySpeed / (swayAmount * 2))
            end
        end
    end)
end

function ResourceSpawner:AddPearlGlowAnimation(model)
    spawn(function()
        local light = model:FindFirstChild("PointLight")
        if not light then return end
        
        local originalBrightness = light.Brightness
        
        while model.Parent do
            -- Pulse brighter
            for brightness = originalBrightness, originalBrightness * 1.5, 0.1 do
                if not model.Parent or not light.Parent then break end
                light.Brightness = brightness
                wait(0.1)
            end
            
            -- Pulse dimmer
            for brightness = originalBrightness * 1.5, originalBrightness, -0.1 do
                if not model.Parent or not light.Parent then break end
                light.Brightness = brightness
                wait(0.1)
            end
        end
    end)
end

function ResourceSpawner:OnResourceHoverEnter(model, resourceId)
    -- Highlight effect when player hovers
    local resourceNode = activeResourceNodes[resourceId]
    if resourceNode and resourceNode.harvestable then
        model.Color = Color3.new(1, 1, 1) -- White highlight
    end
end

function ResourceSpawner:OnResourceHoverLeave(model, resourceId)
    -- Remove highlight
    local resourceNode = activeResourceNodes[resourceId]
    if resourceNode then
        local resourceInfo = ResourceData:GetResourceData(resourceNode.type)
        if resourceInfo and resourceInfo.visual then
            model.Color = resourceInfo.visual.color
        end
    end
end

function ResourceSpawner:PlayHarvestEffects(player, harvestResult)
    -- Play harvest sound
    local soundId = ResourceData:GetResourceData(harvestResult.resourceType).harvestSound
    if soundId then
        local harvestSound = Instance.new("Sound")
        harvestSound.SoundId = soundId
        harvestSound.Volume = 0.5
        harvestSound.Parent = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        
        if harvestSound.Parent then
            harvestSound:Play()
            harvestSound.Ended:Connect(function()
                harvestSound:Destroy()
            end)
        end
    end
end

function ResourceSpawner:GetActiveNodeCount()
    local count = 0
    for _ in pairs(activeResourceNodes) do
        count = count + 1
    end
    return count
end

function ResourceSpawner:CleanupInactiveNodes()
    -- Remove nodes that have been destroyed
    local removedCount = 0
    for resourceId, resourceNode in pairs(activeResourceNodes) do
        if not resourceNode.model or not resourceNode.model.Parent then
            activeResourceNodes[resourceId] = nil
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        print("🧹 Cleaned up", removedCount, "inactive resource nodes")
    end
end

return ResourceSpawner