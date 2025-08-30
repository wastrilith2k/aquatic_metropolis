--[[
WorldGenerator.lua

Purpose: Enhanced underwater world generation for Week 2
Dependencies: TerrainGenerator, PlacementConfig (ReplicatedStorage)
Last Modified: Phase 0 - Week 2
Performance Notes: Enhanced terrain with streaming preparation, improved performance

Public Methods:
- CreateEnhancedTerrain(): Generate enhanced underwater terrain (Week 2)
- CreateBasicTerrain(): Legacy basic terrain (Week 1 compatibility)
- SetupEnvironment(): Enhanced underwater atmosphere
- SpawnAmbientFish(): Enhanced ambient fish with improved AI
- GetEnhancedBounds(): Returns new expanded world bounds
]]--

local WorldGenerator = {}
local TweenService = game:GetService("TweenService")

-- Import enhanced terrain generation system
local TerrainGenerator = require(script.Parent.TerrainGenerator)
local PlacementConfig = require(game.ReplicatedStorage.SharedModules.PlacementConfig)

-- Week 2 Enhanced World Configuration
local ENHANCED_WORLD_CONFIG = {
    bounds = TerrainGenerator:GetTerrainBounds(), -- Enhanced bounds from TerrainGenerator
    spawnGrid = PlacementConfig.Grid.baseSize, -- Use placement config
    maxResourceNodes = PlacementConfig.Performance.maxTotalResources, -- Enhanced capacity
    ambientAssets = 35, -- More ambient fish for larger world
    useEnhancedGeneration = true -- Flag to use Week 2 systems
}

-- Legacy MVP World Configuration (Week 1 compatibility)
local LEGACY_WORLD_CONFIG = {
    bounds = {
        x = {min = -100, max = 100}, -- 200 stud width
        z = {min = -100, max = 100}, -- 200 stud depth  
        y = {seaLevel = -5, floor = -25} -- 20 stud height range
    },
    spawnGrid = 15, -- 15 studs between potential resource spawns
    maxResourceNodes = 60, -- Total resource cap for MVP performance
    ambientAssets = 20 -- Decorative fish count
}

-- Week 2: Enhanced terrain generation using new systems
function WorldGenerator:CreateEnhancedTerrain()
    print("🌊 Creating enhanced underwater world (Week 2)...")
    
    -- Use new TerrainGenerator for enhanced terrain
    TerrainGenerator:GenerateEnhancedTerrain()
    
    -- Set up enhanced environment
    self:SetupEnhancedEnvironment()
    
    -- Spawn enhanced ambient life
    self:SpawnEnhancedAmbientFish()
    
    print("✅ Enhanced world generation complete")
    
    return ENHANCED_WORLD_CONFIG.bounds
end

-- Week 1: Legacy basic terrain (for compatibility)
function WorldGenerator:CreateBasicTerrain()
    print("🌊 Generating basic underwater terrain...")
    
    local terrain = workspace.Terrain
    
    -- Clear any existing terrain in our area
    local clearRegion = Region3.new(
        Vector3.new(-200, -50, -200),
        Vector3.new(200, 50, 200)
    )
    terrain:ReadVoxels(clearRegion, 4)
    
    -- Create water volume
    local waterRegion = Region3.new(
        Vector3.new(LEGACY_WORLD_CONFIG.bounds.x.min - 10, LEGACY_WORLD_CONFIG.bounds.y.seaLevel - 30, LEGACY_WORLD_CONFIG.bounds.z.min - 10),
        Vector3.new(LEGACY_WORLD_CONFIG.bounds.x.max + 10, LEGACY_WORLD_CONFIG.bounds.y.seaLevel + 20, LEGACY_WORLD_CONFIG.bounds.z.max + 10)
    )
    
    -- Fill with water
    terrain:FillRegion(waterRegion, 4, Enum.Material.Water)
    print("💧 Water volume created")
    
    -- Create sandy seafloor with slight height variation
    for x = LEGACY_WORLD_CONFIG.bounds.x.min, LEGACY_WORLD_CONFIG.bounds.x.max, 20 do
        for z = LEGACY_WORLD_CONFIG.bounds.z.min, LEGACY_WORLD_CONFIG.bounds.z.max, 20 do
            -- Simple height variation (no complex noise functions)
            local height = LEGACY_WORLD_CONFIG.bounds.y.floor + math.random(0, 3)
            
            local floorRegion = Region3.new(
                Vector3.new(x, height - 5, z),
                Vector3.new(x + 20, height, z + 20)
            )
            
            -- Use sand material for seafloor
            terrain:FillRegion(floorRegion, 4, Enum.Material.Sand)
        end
    end
    
    print("🏖️ Sandy seafloor created")
    
    -- Add some rocky outcroppings for visual interest
    self:AddRockyOutcroppings()
    
    print("✅ Basic terrain generation complete")
end

function WorldGenerator:AddRockyOutcroppings()
    local terrain = workspace.Terrain
    
    -- Add 5-8 random rocky areas
    local outcroppings = math.random(5, 8)
    
    for i = 1, outcroppings do
        local x = math.random(LEGACY_WORLD_CONFIG.bounds.x.min + 20, LEGACY_WORLD_CONFIG.bounds.x.max - 20)
        local z = math.random(LEGACY_WORLD_CONFIG.bounds.z.min + 20, LEGACY_WORLD_CONFIG.bounds.z.max - 20)
        local height = LEGACY_WORLD_CONFIG.bounds.y.floor + math.random(2, 6)
        
        local rockRegion = Region3.new(
            Vector3.new(x, LEGACY_WORLD_CONFIG.bounds.y.floor, z),
            Vector3.new(x + math.random(8, 15), height, z + math.random(8, 15))
        )
        
        terrain:FillRegion(rockRegion, 4, Enum.Material.Rock)
    end
    
    print("🪨 Rocky outcroppings added")
end

-- Week 2: Enhanced environment setup
function WorldGenerator:SetupEnhancedEnvironment()
    print("🎨 Setting up enhanced underwater environment (Week 2)...")
    
    -- Use TerrainGenerator's enhanced atmosphere system
    -- This is already called by TerrainGenerator:GenerateEnhancedTerrain()
    
    -- Add enhanced particle effects
    self:CreateEnhancedUnderwaterParticles()
    
    -- Add depth-based lighting effects
    self:SetupDepthBasedLighting()
    
    print("✅ Enhanced underwater environment configured")
end

-- Week 1: Legacy environment setup (for compatibility)
function WorldGenerator:SetupEnvironment()
    print("🎨 Setting up underwater environment...")
    
    local lighting = game:GetService("Lighting")
    
    -- Underwater lighting (from original design doc)
    lighting.Brightness = 1.5
    lighting.Ambient = Color3.fromRGB(100, 150, 200) -- Blue-green underwater tint
    lighting.OutdoorAmbient = Color3.fromRGB(80, 120, 160)
    lighting.TimeOfDay = "14:00:00" -- Consistent midday lighting
    lighting.GeographicLatitude = 0
    
    -- Remove any existing atmosphere
    local existingAtmosphere = lighting:FindFirstChildOfClass("Atmosphere")
    if existingAtmosphere then
        existingAtmosphere:Destroy()
    end
    
    -- Add underwater atmospheric effects
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density = 0.3 -- Slightly hazy for underwater feel
    atmosphere.Offset = 0.1
    atmosphere.Color = Color3.fromRGB(150, 200, 255)
    atmosphere.Decay = Color3.fromRGB(100, 150, 200)
    atmosphere.Glare = 0.5
    atmosphere.Haze = 0.3
    atmosphere.Parent = lighting
    
    -- Add subtle underwater particle effects
    self:CreateUnderwaterParticles()
    
    print("✅ Underwater environment configured")
end

function WorldGenerator:CreateUnderwaterParticles()
    -- Create attachment point for particles
    local particleAttachment = Instance.new("Attachment")
    particleAttachment.Name = "UnderwaterParticles"
    particleAttachment.Position = Vector3.new(0, -15, 0) -- Middle depth
    particleAttachment.Parent = workspace.Terrain
    
    -- Bubble particle effect
    local bubbleParticles = Instance.new("ParticleEmitter")
    bubbleParticles.Name = "Bubbles"
    bubbleParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    bubbleParticles.Lifetime = NumberRange.new(3.0, 6.0)
    bubbleParticles.Rate = 3 -- Low rate for performance
    bubbleParticles.SpreadAngle = Vector2.new(180, 180) -- All directions
    bubbleParticles.Speed = NumberRange.new(1, 3)
    bubbleParticles.Acceleration = Vector3.new(0, 2, 0) -- Bubbles rise
    bubbleParticles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1, 0.1)
    }
    bubbleParticles.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    }
    bubbleParticles.Parent = particleAttachment
    
    print("🫧 Underwater particles created")
end

function WorldGenerator:SpawnAmbientFish()
    print("🐟 Spawning ambient fish...")
    
    -- Create folder for environmental assets
    local environmentFolder = workspace:FindFirstChild("EnvironmentalAssets")
    if not environmentFolder then
        environmentFolder = Instance.new("Folder")
        environmentFolder.Name = "EnvironmentalAssets"
        environmentFolder.Parent = workspace
    end
    
    local fishFolder = Instance.new("Folder")
    fishFolder.Name = "AmbientFish"
    fishFolder.Parent = environmentFolder
    
    -- Spawn fish throughout the underwater area
    for i = 1, LEGACY_WORLD_CONFIG.ambientAssets do
        local fish = self:CreateAmbientFish(i, LEGACY_WORLD_CONFIG)
        fish.Parent = fishFolder
    end
    
    print("✅ Spawned", LEGACY_WORLD_CONFIG.ambientAssets, "ambient fish")
end

function WorldGenerator:CreateAmbientFish(fishId, worldConfig)
    worldConfig = worldConfig or LEGACY_WORLD_CONFIG -- Default to legacy config
    local fish = Instance.new("Part")
    fish.Name = "Fish_" .. fishId
    fish.Size = Vector3.new(math.random(8, 15)/10, math.random(4, 8)/10, math.random(15, 25)/10) -- Varied sizes
    fish.Material = Enum.Material.Neon
    fish.CanCollide = false
    fish.Anchored = true
    fish.Shape = Enum.PartType.Block
    
    -- Random underwater position within bounds
    fish.Position = Vector3.new(
        math.random(worldConfig.bounds.x.min + 10, worldConfig.bounds.x.max - 10),
        math.random(worldConfig.bounds.y.floor + 3, worldConfig.bounds.y.seaLevel - 2),
        math.random(worldConfig.bounds.z.min + 10, worldConfig.bounds.z.max - 10)
    )
    
    -- Random fish colors (ocean themed)
    local fishColors = {
        Color3.fromRGB(255, 165, 0),  -- Orange
        Color3.fromRGB(255, 255, 0),  -- Yellow  
        Color3.fromRGB(0, 191, 255),  -- Deep sky blue
        Color3.fromRGB(255, 20, 147), -- Deep pink
        Color3.fromRGB(50, 205, 50),  -- Lime green
        Color3.fromRGB(138, 43, 226), -- Blue violet
    }
    fish.Color = fishColors[math.random(#fishColors)]
    
    -- Set spawn time for cleanup system
    fish:SetAttribute("SpawnTime", tick())
    
    -- Start fish movement
    self:AnimateAmbientFish(fish, worldConfig)
    
    return fish
end

function WorldGenerator:AnimateAmbientFish(fish, worldConfig)
    worldConfig = worldConfig or LEGACY_WORLD_CONFIG -- Default to legacy config
    spawn(function()
        local speed = math.random(15, 40) / 10 -- 1.5 to 4.0 studs/second
        local direction = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100)).Unit
        local startPosition = fish.Position
        
        while fish.Parent do
            -- Move fish
            local newPosition = fish.Position + (direction * speed * 0.1)
            
            -- Keep within world bounds and depth limits
            if newPosition.X < worldConfig.bounds.x.min + 5 or 
               newPosition.X > worldConfig.bounds.x.max - 5 or
               newPosition.Z < worldConfig.bounds.z.min + 5 or
               newPosition.Z > worldConfig.bounds.z.max - 5 or
               newPosition.Y > worldConfig.bounds.y.seaLevel - 2 or
               newPosition.Y < worldConfig.bounds.y.floor + 2 then
                
                -- Turn around when hitting boundaries
                direction = (startPosition - fish.Position).Unit
            else
                fish.Position = newPosition
            end
            
            -- Rotate fish to face movement direction
            if direction.Magnitude > 0 then
                fish.CFrame = CFrame.lookAt(fish.Position, fish.Position + direction)
            end
            
            -- Random direction changes (more natural movement)
            if math.random() < 0.015 then -- 1.5% chance per frame
                direction = Vector3.new(
                    math.random(-100, 100), 
                    math.random(-20, 20),  -- Small vertical movement
                    math.random(-100, 100)
                ).Unit
            end
            
            wait(0.1) -- 10 FPS movement for performance
        end
    end)
end

function WorldGenerator:GetWorldBounds()
    return LEGACY_WORLD_CONFIG.bounds
end

function WorldGenerator:GetEnhancedBounds()
    return ENHANCED_WORLD_CONFIG.bounds
end

function WorldGenerator:GetSpawnGrid()
    return LEGACY_WORLD_CONFIG.spawnGrid
end

function WorldGenerator:CleanupAmbientAssets()
    -- Clean up old ambient assets if performance drops
    local environmentFolder = workspace:FindFirstChild("EnvironmentalAssets")
    if environmentFolder then
        local fishFolder = environmentFolder:FindFirstChild("AmbientFish") 
        if fishFolder then
            local fish = fishFolder:GetChildren()
            if #fish > LEGACY_WORLD_CONFIG.ambientAssets then
                -- Remove oldest fish
                table.sort(fish, function(a, b)
                    return (a:GetAttribute("SpawnTime") or 0) < (b:GetAttribute("SpawnTime") or 0)
                end)
                
                local removeCount = #fish - LEGACY_WORLD_CONFIG.ambientAssets
                for i = 1, removeCount do
                    if fish[i] then
                        fish[i]:Destroy()
                    end
                end
                
                print("🧹 Cleaned up", removeCount, "ambient fish for performance")
            end
        end
    end
end

-- Week 2: Enhanced particle system
function WorldGenerator:CreateEnhancedUnderwaterParticles()
    print("🫧 Creating enhanced underwater particles...")
    
    -- Create multiple particle attachment points for better coverage
    local bounds = ENHANCED_WORLD_CONFIG.bounds
    local attachmentPoints = {
        {position = Vector3.new(0, -15, 0), name = "Center"},
        {position = Vector3.new(bounds.x.max/2, -20, bounds.z.max/2), name = "NorthEast"},
        {position = Vector3.new(bounds.x.min/2, -18, bounds.z.min/2), name = "SouthWest"},
        {position = Vector3.new(bounds.x.max/2, -25, bounds.z.min/2), name = "NorthWest"},
        {position = Vector3.new(bounds.x.min/2, -22, bounds.z.max/2), name = "SouthEast"}
    }
    
    for _, point in ipairs(attachmentPoints) do
        local particleAttachment = Instance.new("Attachment")
        particleAttachment.Name = "UnderwaterParticles_" .. point.name
        particleAttachment.Position = point.position
        particleAttachment.Parent = workspace.Terrain
        
        -- Enhanced bubble particles
        local bubbles = self:CreateBubbleParticles()
        bubbles.Parent = particleAttachment
        
        -- Floating sediment particles
        local sediment = self:CreateSedimentParticles()
        sediment.Parent = particleAttachment
        
        -- Occasional marine snow
        if math.random() < 0.6 then -- 60% chance per attachment point
            local marineSnow = self:CreateMarineSnowParticles()
            marineSnow.Parent = particleAttachment
        end
    end
    
    print("🫧 Enhanced underwater particle system created")
end

function WorldGenerator:CreateBubbleParticles()
    local bubbleParticles = Instance.new("ParticleEmitter")
    bubbleParticles.Name = "EnhancedBubbles"
    bubbleParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    bubbleParticles.Lifetime = NumberRange.new(4.0, 8.0) -- Longer lifetime
    bubbleParticles.Rate = 2 -- Slightly lower rate but more emitters
    bubbleParticles.SpreadAngle = Vector2.new(45, 45) -- More focused upward
    bubbleParticles.Speed = NumberRange.new(0.5, 2.0) -- Slower, more realistic
    bubbleParticles.Acceleration = Vector3.new(0, 1.5, 0) -- Slower rise
    bubbleParticles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.3, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.4),
        NumberSequenceKeypoint.new(1, 0.05)
    }
    bubbleParticles.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.7, 0.8),
        NumberSequenceKeypoint.new(1, 1)
    }
    
    return bubbleParticles
end

function WorldGenerator:CreateSedimentParticles()
    local sedimentParticles = Instance.new("ParticleEmitter")
    sedimentParticles.Name = "Sediment"
    sedimentParticles.Texture = "rbxasset://textures/particles/smoke_main.dds"
    sedimentParticles.Lifetime = NumberRange.new(8.0, 12.0)
    sedimentParticles.Rate = 1 -- Very low rate for subtle effect
    sedimentParticles.SpreadAngle = Vector2.new(360, 180) -- All directions
    sedimentParticles.Speed = NumberRange.new(0.1, 0.5) -- Very slow drift
    sedimentParticles.Acceleration = Vector3.new(0, -0.2, 0) -- Slight downward drift
    sedimentParticles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.02),
        NumberSequenceKeypoint.new(1, 0.08)
    }
    sedimentParticles.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(1, 0.95)
    }
    sedimentParticles.Color = ColorSequence.new(Color3.fromRGB(139, 69, 19)) -- Brown sediment
    
    return sedimentParticles
end

function WorldGenerator:CreateMarineSnowParticles()
    local marineSnow = Instance.new("ParticleEmitter")
    marineSnow.Name = "MarineSnow"
    marineSnow.Texture = "rbxasset://textures/particles/fire_main.dds"
    marineSnow.Lifetime = NumberRange.new(15.0, 20.0) -- Very long drift
    marineSnow.Rate = 0.5 -- Very occasional
    marineSnow.SpreadAngle = Vector2.new(180, 90)
    marineSnow.Speed = NumberRange.new(0.05, 0.2) -- Extremely slow
    marineSnow.Acceleration = Vector3.new(0, -0.1, 0) -- Gentle fall
    marineSnow.Size = NumberSequence.new(0.01) -- Tiny particles
    marineSnow.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(1, 1)
    }
    marineSnow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)) -- White organic matter
    
    return marineSnow
end

function WorldGenerator:SetupDepthBasedLighting()
    print("💡 Setting up depth-based lighting effects...")
    
    -- Add light sources at different depths for more realistic underwater lighting
    local bounds = ENHANCED_WORLD_CONFIG.bounds
    local lightSources = {
        {
            position = Vector3.new(0, bounds.y.seaLevel - 8, 0),
            brightness = 2,
            color = Color3.fromRGB(200, 220, 255),
            range = 60,
            name = "SurfaceLight"
        },
        {
            position = Vector3.new(bounds.x.max/2, bounds.y.floor + 8, bounds.z.max/2),
            brightness = 1,
            color = Color3.fromRGB(150, 180, 200),
            range = 40,
            name = "MidDepthLight1"
        },
        {
            position = Vector3.new(bounds.x.min/2, bounds.y.floor + 6, bounds.z.min/2),
            brightness = 0.8,
            color = Color3.fromRGB(120, 150, 180),
            range = 35,
            name = "DeepLight1"
        }
    }
    
    for _, lightConfig in ipairs(lightSources) do
        local lightPart = Instance.new("Part")
        lightPart.Name = lightConfig.name .. "Source"
        lightPart.Size = Vector3.new(1, 1, 1)
        lightPart.Anchored = true
        lightPart.CanCollide = false
        lightPart.Transparency = 1
        lightPart.Position = lightConfig.position
        lightPart.Parent = workspace
        
        local pointLight = Instance.new("PointLight")
        pointLight.Brightness = lightConfig.brightness
        pointLight.Color = lightConfig.color
        pointLight.Range = lightConfig.range
        pointLight.Shadows = true
        pointLight.Parent = lightPart
        
        -- Add subtle light animation
        spawn(function()
            while lightPart.Parent do
                local targetBrightness = lightConfig.brightness + math.sin(tick() * 0.5) * 0.2
                pointLight.Brightness = targetBrightness
                wait(0.1)
            end
        end)
    end
    
    print("💡 Depth-based lighting effects created")
end

-- Week 2: Enhanced ambient fish system
function WorldGenerator:SpawnEnhancedAmbientFish()
    print("🐟 Spawning enhanced ambient fish...")
    
    -- Create folder for environmental assets
    local environmentFolder = workspace:FindFirstChild("EnvironmentalAssets")
    if not environmentFolder then
        environmentFolder = Instance.new("Folder")
        environmentFolder.Name = "EnvironmentalAssets"
        environmentFolder.Parent = workspace
    end
    
    local fishFolder = Instance.new("Folder")
    fishFolder.Name = "EnhancedAmbientFish"
    fishFolder.Parent = environmentFolder
    
    -- Spawn more varied fish throughout the larger underwater area
    for i = 1, ENHANCED_WORLD_CONFIG.ambientAssets do
        local fish = self:CreateEnhancedAmbientFish(i)
        fish.Parent = fishFolder
    end
    
    print("✅ Spawned", ENHANCED_WORLD_CONFIG.ambientAssets, "enhanced ambient fish")
end

function WorldGenerator:CreateEnhancedAmbientFish(fishId)
    local fish = Instance.new("Part")
    fish.Name = "EnhancedFish_" .. fishId
    
    -- More varied sizes based on fish type
    local fishType = math.random(1, 4)
    local size, speed, color
    
    if fishType == 1 then -- Small tropical fish
        size = Vector3.new(0.6, 0.3, 1.2)
        speed = {min = 25, max = 45}
        color = {
            Color3.fromRGB(255, 165, 0),  -- Orange
            Color3.fromRGB(255, 255, 0),  -- Yellow
            Color3.fromRGB(255, 20, 147), -- Deep pink
        }
    elseif fishType == 2 then -- Medium reef fish
        size = Vector3.new(1.0, 0.5, 2.0)
        speed = {min = 15, max = 30}
        color = {
            Color3.fromRGB(0, 191, 255),  -- Deep sky blue
            Color3.fromRGB(50, 205, 50),  -- Lime green
            Color3.fromRGB(138, 43, 226), -- Blue violet
        }
    elseif fishType == 3 then -- Large slow fish
        size = Vector3.new(1.8, 0.8, 3.2)
        speed = {min = 8, max = 18}
        color = {
            Color3.fromRGB(70, 130, 180),  -- Steel blue
            Color3.fromRGB(60, 179, 113),  -- Medium sea green
            Color3.fromRGB(72, 61, 139),   -- Dark slate blue
        }
    else -- Tiny schooling fish
        size = Vector3.new(0.3, 0.2, 0.6)
        speed = {min = 35, max = 60}
        color = {
            Color3.fromRGB(192, 192, 192), -- Silver
            Color3.fromRGB(255, 255, 255), -- White
            Color3.fromRGB(220, 220, 220), -- Light gray
        }
    end
    
    fish.Size = size
    fish.Material = Enum.Material.Neon
    fish.CanCollide = false
    fish.Anchored = true
    fish.Shape = Enum.PartType.Block
    
    -- Position within enhanced world bounds
    local bounds = ENHANCED_WORLD_CONFIG.bounds
    fish.Position = Vector3.new(
        math.random(bounds.x.min + 15, bounds.x.max - 15),
        math.random(bounds.y.floor + 4, bounds.y.seaLevel - 3),
        math.random(bounds.z.min + 15, bounds.z.max - 15)
    )
    
    fish.Color = color[math.random(#color)]
    fish:SetAttribute("SpawnTime", tick())
    fish:SetAttribute("FishType", fishType)
    fish:SetAttribute("Speed", speed)
    
    -- Start enhanced fish movement
    self:AnimateEnhancedAmbientFish(fish)
    
    return fish
end

function WorldGenerator:AnimateEnhancedAmbientFish(fish)
    spawn(function()
        local fishType = fish:GetAttribute("FishType")
        local speedRange = fish:GetAttribute("Speed")
        local speed = math.random(speedRange.min, speedRange.max) / 10
        
        local direction = Vector3.new(math.random(-100, 100), math.random(-30, 30), math.random(-100, 100)).Unit
        local startPosition = fish.Position
        local bounds = ENHANCED_WORLD_CONFIG.bounds
        
        -- School behavior for tiny fish
        local schoolRadius = (fishType == 4) and 25 or 0
        
        while fish.Parent do
            -- Move fish
            local newPosition = fish.Position + (direction * speed * 0.1)
            
            -- Enhanced boundary checking with larger world
            if newPosition.X < bounds.x.min + 10 or 
               newPosition.X > bounds.x.max - 10 or
               newPosition.Z < bounds.z.min + 10 or
               newPosition.Z > bounds.z.max - 10 or
               newPosition.Y > bounds.y.seaLevel - 3 or
               newPosition.Y < bounds.y.floor + 3 then
                
                -- More intelligent turning behavior
                local centerDirection = (Vector3.new(0, -20, 0) - fish.Position).Unit
                direction = (centerDirection + direction * 0.5).Unit
            else
                fish.Position = newPosition
            end
            
            -- Rotate fish to face movement direction with banking
            if direction.Magnitude > 0 then
                local bankAngle = math.rad(direction.X * 15) -- Bank into turns
                fish.CFrame = CFrame.lookAt(fish.Position, fish.Position + direction) * CFrame.Angles(0, 0, bankAngle)
            end
            
            -- Enhanced behavior based on fish type
            local directionChangeChance = 0.01 + (fishType * 0.005) -- Larger fish change direction less often
            if math.random() < directionChangeChance then
                direction = Vector3.new(
                    math.random(-100, 100), 
                    math.random(-40, 40),  -- More vertical movement
                    math.random(-100, 100)
                ).Unit
            end
            
            -- Schooling behavior for small fish
            if fishType == 4 and schoolRadius > 0 then
                -- Look for nearby fish of same type
                local nearbyFish = {}
                for _, otherFish in ipairs(workspace.EnvironmentalAssets.EnhancedAmbientFish:GetChildren()) do
                    if otherFish ~= fish and otherFish:GetAttribute("FishType") == 4 then
                        local distance = (fish.Position - otherFish.Position).Magnitude
                        if distance < schoolRadius then
                            table.insert(nearbyFish, otherFish)
                        end
                    end
                end
                
                -- Adjust direction based on nearby fish
                if #nearbyFish > 0 then
                    local avgPosition = Vector3.new(0, 0, 0)
                    for _, nearbyFish in ipairs(nearbyFish) do
                        avgPosition = avgPosition + nearbyFish.Position
                    end
                    avgPosition = avgPosition / #nearbyFish
                    
                    -- Move toward school center
                    local schoolDirection = (avgPosition - fish.Position).Unit
                    direction = (direction * 0.7 + schoolDirection * 0.3).Unit
                end
            end
            
            wait(0.1) -- Maintain 10 FPS movement for performance
        end
    end)
end

-- Enhanced cleanup system for larger world
function WorldGenerator:CleanupEnhancedAmbientAssets()
    local environmentFolder = workspace:FindFirstChild("EnvironmentalAssets")
    if environmentFolder then
        local fishFolder = environmentFolder:FindFirstChild("EnhancedAmbientFish") 
        if fishFolder then
            local fish = fishFolder:GetChildren()
            if #fish > ENHANCED_WORLD_CONFIG.ambientAssets then
                -- Remove oldest fish
                table.sort(fish, function(a, b)
                    return (a:GetAttribute("SpawnTime") or 0) < (b:GetAttribute("SpawnTime") or 0)
                end)
                
                local removeCount = #fish - ENHANCED_WORLD_CONFIG.ambientAssets
                for i = 1, removeCount do
                    if fish[i] then
                        fish[i]:Destroy()
                    end
                end
                
                print("🧹 Cleaned up", removeCount, "enhanced ambient fish for performance")
            end
        end
    end
end

return WorldGenerator