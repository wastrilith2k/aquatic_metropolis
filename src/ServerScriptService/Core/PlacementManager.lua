--[[
PlacementManager.lua

Purpose: Procedural asset placement system for Week 2 world generation
Dependencies: PlacementConfig (ReplicatedStorage), TerrainGenerator
Last Modified: Phase 0 - Week 2
Performance Notes: Batch processing, streaming-ready, collision detection

Public Methods:
- PlaceResourcesInRegion(): Place resources using procedural rules
- ValidatePlacement(): Check if placement position is valid
- GeneratePlacementGrid(): Create grid-based placement points
- CleanupExistingResources(): Clean old resources before regeneration
]]--

local PlacementManager = {}

-- Import dependencies
local PlacementConfig = require(game.ReplicatedStorage.SharedModules.PlacementConfig)
local TerrainGenerator = require(script.Parent.TerrainGenerator)

-- Cache for performance
local placementCache = {}
local lastPlacementTime = 0
local placementQueue = {}

-- Simple noise function for placement variation
local function simpleNoise(x, z, frequency)
    return (math.sin(x * frequency) * math.cos(z * frequency) + 1) / 2
end

function PlacementManager:PlaceResourcesInRegion(regionCenter, regionSize, resourceTypes)
    print("🎯 Placing resources in region using procedural placement...")
    
    local startTime = tick()
    local resourceCounts = {Kelp = 0, Rock = 0, Pearl = 0}
    
    -- Clear existing resources in region first
    self:CleanupExistingResources(regionCenter, regionSize)
    
    -- Generate placement grid for the region
    local placementPoints = self:GeneratePlacementGrid(regionCenter, regionSize)
    
    print(string.format("🔍 Generated %d potential placement points", #placementPoints))
    
    -- Process placements in batches for performance
    local placedResources = {}
    local batchSize = PlacementConfig.Performance.processingBatchSize
    
    for i = 1, #placementPoints, batchSize do
        local batchEndIndex = math.min(i + batchSize - 1, #placementPoints)
        
        -- Process batch
        for j = i, batchEndIndex do
            local point = placementPoints[j]
            
            -- Determine what resource to place here (if any)
            local resourceType = self:DetermineResourceAtPoint(point, resourceTypes)
            
            if resourceType then
                local validPosition = self:ValidatePlacement(point, resourceType, placedResources)
                
                if validPosition then
                    local resource = self:CreateResourceAt(validPosition, resourceType)
                    if resource then
                        table.insert(placedResources, resource)
                        resourceCounts[resourceType] = resourceCounts[resourceType] + 1
                        
                        -- Check performance limits
                        if #placedResources >= PlacementConfig.Performance.maxResourcesPerRegion then
                            print("⚠️ Reached maximum resources per region, stopping placement")
                            break
                        end
                    end
                end
            end
        end
        
        -- Yield between batches for performance
        if batchEndIndex < #placementPoints then
            wait(PlacementConfig.Performance.batchDelay)
        end
    end
    
    local endTime = tick()
    print(string.format("✅ Procedural placement complete (%.2fs): Kelp=%d, Rock=%d, Pearl=%d", 
        endTime - startTime, resourceCounts.Kelp, resourceCounts.Rock, resourceCounts.Pearl))
    
    return placedResources
end

function PlacementManager:GeneratePlacementGrid(regionCenter, regionSize)
    local placementPoints = {}
    local gridSize = PlacementConfig.Grid.baseSize
    local variation = PlacementConfig.Grid.variation
    
    -- Create grid points with variation
    local halfSize = regionSize / 2
    local startX = regionCenter.X - halfSize
    local endX = regionCenter.X + halfSize
    local startZ = regionCenter.Z - halfSize
    local endZ = regionCenter.Z + halfSize
    
    for x = startX, endX, gridSize do
        for z = startZ, endZ, gridSize do
            -- Add variation to avoid perfect grid appearance
            local variedX = x + math.random(-variation, variation)
            local variedZ = z + math.random(-variation, variation)
            
            -- Height will be determined later based on terrain
            local point = Vector3.new(variedX, regionCenter.Y, variedZ)
            table.insert(placementPoints, point)
        end
    end
    
    -- Shuffle the points for more natural placement order
    for i = #placementPoints, 2, -1 do
        local j = math.random(i)
        placementPoints[i], placementPoints[j] = placementPoints[j], placementPoints[i]
    end
    
    return placementPoints
end

function PlacementManager:DetermineResourceAtPoint(point, availableResourceTypes)
    -- Use noise functions to determine resource distribution
    local primaryNoise = simpleNoise(point.X, point.Z, PlacementConfig.Noise.primary.frequency)
    local secondaryNoise = simpleNoise(point.X, point.Z, PlacementConfig.Noise.secondary.frequency)
    
    -- Combine noise values for final density
    local densityModifier = PlacementConfig.Noise.primary.offset + 
                           primaryNoise * PlacementConfig.Noise.primary.amplitude
    
    -- Check each resource type
    for _, resourceType in ipairs(availableResourceTypes) do
        local config = PlacementConfig.Resources[resourceType]
        if config then
            -- Apply biome density modifier
            local biomeModifier = PlacementConfig.Validation.getBiomeDensityModifier(point, resourceType)
            local finalDensity = config.baseDensity * densityModifier * biomeModifier
            
            -- Apply clustering if above threshold
            if secondaryNoise > PlacementConfig.Noise.secondary.threshold then
                finalDensity = finalDensity * (1 + config.clustering)
            end
            
            -- Random check against final density
            if math.random() < finalDensity then
                return resourceType
            end
        end
    end
    
    return nil -- No resource at this point
end

function PlacementManager:ValidatePlacement(point, resourceType, existingResources)
    local config = PlacementConfig.Resources[resourceType]
    if not config then return nil end
    
    -- Cast ray downward to find surface
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {workspace.EnvironmentalAssets}
    
    local rayOrigin = Vector3.new(point.X, point.Y + 10, point.Z)
    local rayDirection = Vector3.new(0, -30, 0)
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if not rayResult then
        return nil -- No surface found
    end
    
    local surfacePosition = rayResult.Position
    local surfaceMaterial = rayResult.Material
    
    -- Check if material is suitable
    if not PlacementConfig.Validation.isMaterialSuitable(surfaceMaterial, resourceType) then
        return nil
    end
    
    -- Check surface angle (slope)
    local surfaceNormal = rayResult.Normal
    local surfaceAngle = math.deg(math.acos(surfaceNormal:Dot(Vector3.new(0, 1, 0))))
    
    if surfaceAngle > config.surfaceAngleLimit then
        return nil -- Too steep
    end
    
    -- Check depth requirements
    local depth = math.abs(surfacePosition.Y) -- Assuming Y=0 is surface level
    if depth < config.minDepth or depth > config.maxDepth then
        return nil -- Wrong depth
    end
    
    -- Check collision with existing resources
    for _, existing in ipairs(existingResources) do
        local distance = (surfacePosition - existing.Position).Magnitude
        if distance < config.collisionRadius then
            return nil -- Too close to existing resource
        end
    end
    
    -- Calculate final position with height offset
    local heightOffset = math.random(config.heightRange.min * 10, config.heightRange.max * 10) / 10
    local finalPosition = surfacePosition + Vector3.new(0, heightOffset, 0)
    
    return finalPosition
end

function PlacementManager:CreateResourceAt(position, resourceType)
    -- Create resource folder if it doesn't exist
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then
        resourceFolder = Instance.new("Folder")
        resourceFolder.Name = "ResourceNodes"
        resourceFolder.Parent = workspace
    end
    
    local typeFolder = resourceFolder:FindFirstChild(resourceType)
    if not typeFolder then
        typeFolder = Instance.new("Folder")
        typeFolder.Name = resourceType
        typeFolder.Parent = resourceFolder
    end
    
    -- Create the resource node
    local resource = Instance.new("Part")
    resource.Name = resourceType .. "_" .. tick()
    resource.Anchored = true
    resource.CanCollide = false
    
    -- Set properties based on resource type
    if resourceType == "Kelp" then
        resource.Size = Vector3.new(1, math.random(30, 60)/10, 1) -- 3-6 studs tall, varied
        resource.Material = Enum.Material.Neon
        resource.Color = Color3.fromRGB(50, math.random(150, 255), 50) -- Varied green
        resource.Shape = Enum.PartType.Cylinder
        
    elseif resourceType == "Rock" then
        resource.Size = Vector3.new(
            math.random(15, 25)/10, 
            math.random(10, 20)/10, 
            math.random(15, 25)/10
        ) -- Varied rock sizes
        resource.Material = Enum.Material.Rock
        resource.Color = Color3.fromRGB(
            math.random(100, 150), 
            math.random(100, 150), 
            math.random(100, 150)
        ) -- Varied gray
        resource.Shape = Enum.PartType.Block
        
    elseif resourceType == "Pearl" then
        resource.Size = Vector3.new(0.8, 0.8, 0.8)
        resource.Material = Enum.Material.Neon
        resource.Color = Color3.fromRGB(255, 255, math.random(200, 255)) -- Slightly varied white
        resource.Shape = Enum.PartType.Ball
        
        -- Add glow effect for pearls
        local pointLight = Instance.new("PointLight")
        pointLight.Color = Color3.fromRGB(255, 255, 200)
        pointLight.Brightness = 0.5
        pointLight.Range = 8
        pointLight.Parent = resource
    end
    
    resource.Position = position
    resource.Parent = typeFolder
    
    -- Add resource attributes for game system
    resource:SetAttribute("ResourceType", resourceType)
    resource:SetAttribute("Harvestable", true)
    resource:SetAttribute("SpawnTime", tick())
    resource:SetAttribute("ProcedurallyPlaced", true)
    
    -- Add enhanced animation for resource nodes (Week 2 feature)
    self:AddResourceAnimation(resource, resourceType)
    
    return resource
end

function PlacementManager:AddResourceAnimation(resource, resourceType)
    -- Create subtle animations based on resource type
    spawn(function()
        local startTime = tick()
        
        if resourceType == "Kelp" then
            -- Kelp swaying animation
            local originalCFrame = resource.CFrame
            
            while resource.Parent do
                local time = tick() - startTime
                local swayX = math.sin(time * 1.2) * 0.3 -- Gentle sway
                local swayZ = math.cos(time * 0.8) * 0.2
                
                resource.CFrame = originalCFrame * CFrame.Angles(math.rad(swayX * 15), 0, math.rad(swayZ * 10))
                wait(0.1)
            end
            
        elseif resourceType == "Pearl" then
            -- Pearl floating/bobbing animation
            local originalPosition = resource.Position
            
            while resource.Parent do
                local time = tick() - startTime
                local bobHeight = math.sin(time * 2) * 0.2 -- Gentle up/down
                
                resource.Position = originalPosition + Vector3.new(0, bobHeight, 0)
                
                -- Also animate the glow
                local pointLight = resource:FindFirstChild("PointLight")
                if pointLight then
                    pointLight.Brightness = 0.5 + math.sin(time * 3) * 0.2
                end
                
                wait(0.1)
            end
            
        elseif resourceType == "Rock" then
            -- Very subtle rotation for rocks
            local originalCFrame = resource.CFrame
            
            while resource.Parent do
                local time = tick() - startTime
                local rotateY = time * 0.1 -- Very slow rotation
                
                resource.CFrame = originalCFrame * CFrame.Angles(0, math.rad(rotateY), 0)
                wait(0.2) -- Slower update for rocks
            end
        end
    end)
end

function PlacementManager:CleanupExistingResources(regionCenter, regionSize)
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then return end
    
    local cleanupCount = 0
    local halfSize = regionSize / 2
    
    for _, typeFolder in ipairs(resourceFolder:GetChildren()) do
        if typeFolder:IsA("Folder") then
            for _, resource in ipairs(typeFolder:GetChildren()) do
                if resource:IsA("Part") then
                    local distance = (resource.Position - regionCenter).Magnitude
                    if distance <= halfSize then
                        resource:Destroy()
                        cleanupCount = cleanupCount + 1
                    end
                end
            end
        end
    end
    
    if cleanupCount > 0 then
        print(string.format("🧹 Cleaned up %d existing resources in region", cleanupCount))
    end
end

-- Global resource management functions
function PlacementManager:GetTotalResourceCount()
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then return 0 end
    
    local totalCount = 0
    for _, typeFolder in ipairs(resourceFolder:GetChildren()) do
        if typeFolder:IsA("Folder") then
            totalCount = totalCount + #typeFolder:GetChildren()
        end
    end
    
    return totalCount
end

function PlacementManager:PerformGlobalCleanup()
    local totalResources = self:GetTotalResourceCount()
    
    if totalResources > PlacementConfig.Performance.cleanupTriggerCount then
        print(string.format("🧹 Starting global resource cleanup (%d resources)", totalResources))
        
        -- Remove oldest resources until we hit target count
        local allResources = {}
        local resourceFolder = workspace:FindFirstChild("ResourceNodes")
        
        if resourceFolder then
            for _, typeFolder in ipairs(resourceFolder:GetChildren()) do
                if typeFolder:IsA("Folder") then
                    for _, resource in ipairs(typeFolder:GetChildren()) do
                        if resource:IsA("Part") then
                            table.insert(allResources, resource)
                        end
                    end
                end
            end
        end
        
        -- Sort by spawn time (oldest first)
        table.sort(allResources, function(a, b)
            return (a:GetAttribute("SpawnTime") or 0) < (b:GetAttribute("SpawnTime") or 0)
        end)
        
        -- Remove oldest resources
        local targetCount = PlacementConfig.Performance.cleanupTargetCount
        local removeCount = #allResources - targetCount
        
        for i = 1, removeCount do
            if allResources[i] then
                allResources[i]:Destroy()
            end
        end
        
        print(string.format("🧹 Global cleanup complete: removed %d resources", removeCount))
    end
end

-- Debug and monitoring functions
function PlacementManager:GetPlacementStats()
    local resourceFolder = workspace:FindFirstChild("ResourceNodes")
    if not resourceFolder then 
        return {Kelp = 0, Rock = 0, Pearl = 0, Total = 0}
    end
    
    local stats = {Kelp = 0, Rock = 0, Pearl = 0, Total = 0}
    
    for _, typeFolder in ipairs(resourceFolder:GetChildren()) do
        if typeFolder:IsA("Folder") then
            local count = #typeFolder:GetChildren()
            stats[typeFolder.Name] = count
            stats.Total = stats.Total + count
        end
    end
    
    return stats
end

function PlacementManager:PrintPlacementReport()
    local stats = self:GetPlacementStats()
    print(string.format("📊 Resource Placement Report: Kelp=%d, Rock=%d, Pearl=%d, Total=%d", 
        stats.Kelp, stats.Rock, stats.Pearl, stats.Total))
end

return PlacementManager