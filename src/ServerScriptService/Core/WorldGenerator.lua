--[[
WorldGenerator.lua

Purpose: Creates simplified underwater world for MVP
Dependencies: None (uses Roblox Terrain API)
Last Modified: Phase 0 - Week 1
Performance Notes: Optimized for fast generation, minimal complexity

Public Methods:
- CreateBasicTerrain(): Generate underwater terrain
- SetupEnvironment(): Configure lighting and atmosphere
- SpawnAmbientFish(): Add environmental life
]]--

local WorldGenerator = {}
local TweenService = game:GetService("TweenService")

-- MVP World Configuration (simplified from complex procedural generation)
local WORLD_CONFIG = {
    bounds = {
        x = {min = -100, max = 100}, -- 200 stud width
        z = {min = -100, max = 100}, -- 200 stud depth  
        y = {seaLevel = -5, floor = -25} -- 20 stud height range
    },
    spawnGrid = 15, -- 15 studs between potential resource spawns
    maxResourceNodes = 60, -- Total resource cap for MVP performance
    ambientAssets = 20 -- Decorative fish count
}

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
        Vector3.new(WORLD_CONFIG.bounds.x.min - 10, WORLD_CONFIG.bounds.y.seaLevel - 30, WORLD_CONFIG.bounds.z.min - 10),
        Vector3.new(WORLD_CONFIG.bounds.x.max + 10, WORLD_CONFIG.bounds.y.seaLevel + 20, WORLD_CONFIG.bounds.z.max + 10)
    )
    
    -- Fill with water
    terrain:FillRegion(waterRegion, 4, Enum.Material.Water)
    print("💧 Water volume created")
    
    -- Create sandy seafloor with slight height variation
    for x = WORLD_CONFIG.bounds.x.min, WORLD_CONFIG.bounds.x.max, 20 do
        for z = WORLD_CONFIG.bounds.z.min, WORLD_CONFIG.bounds.z.max, 20 do
            -- Simple height variation (no complex noise functions)
            local height = WORLD_CONFIG.bounds.y.floor + math.random(0, 3)
            
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
        local x = math.random(WORLD_CONFIG.bounds.x.min + 20, WORLD_CONFIG.bounds.x.max - 20)
        local z = math.random(WORLD_CONFIG.bounds.z.min + 20, WORLD_CONFIG.bounds.z.max - 20)
        local height = WORLD_CONFIG.bounds.y.floor + math.random(2, 6)
        
        local rockRegion = Region3.new(
            Vector3.new(x, WORLD_CONFIG.bounds.y.floor, z),
            Vector3.new(x + math.random(8, 15), height, z + math.random(8, 15))
        )
        
        terrain:FillRegion(rockRegion, 4, Enum.Material.Rock)
    end
    
    print("🪨 Rocky outcroppings added")
end

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
    for i = 1, WORLD_CONFIG.ambientAssets do
        local fish = self:CreateAmbientFish(i)
        fish.Parent = fishFolder
    end
    
    print("✅ Spawned", WORLD_CONFIG.ambientAssets, "ambient fish")
end

function WorldGenerator:CreateAmbientFish(fishId)
    local fish = Instance.new("Part")
    fish.Name = "Fish_" .. fishId
    fish.Size = Vector3.new(math.random(8, 15)/10, math.random(4, 8)/10, math.random(15, 25)/10) -- Varied sizes
    fish.Material = Enum.Material.Neon
    fish.CanCollide = false
    fish.Anchored = true
    fish.Shape = Enum.PartType.Block
    
    -- Random underwater position within bounds
    fish.Position = Vector3.new(
        math.random(WORLD_CONFIG.bounds.x.min + 10, WORLD_CONFIG.bounds.x.max - 10),
        math.random(WORLD_CONFIG.bounds.y.floor + 3, WORLD_CONFIG.bounds.y.seaLevel - 2),
        math.random(WORLD_CONFIG.bounds.z.min + 10, WORLD_CONFIG.bounds.z.max - 10)
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
    self:AnimateAmbientFish(fish)
    
    return fish
end

function WorldGenerator:AnimateAmbientFish(fish)
    spawn(function()
        local speed = math.random(15, 40) / 10 -- 1.5 to 4.0 studs/second
        local direction = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100)).Unit
        local startPosition = fish.Position
        
        while fish.Parent do
            -- Move fish
            local newPosition = fish.Position + (direction * speed * 0.1)
            
            -- Keep within world bounds and depth limits
            if newPosition.X < WORLD_CONFIG.bounds.x.min + 5 or 
               newPosition.X > WORLD_CONFIG.bounds.x.max - 5 or
               newPosition.Z < WORLD_CONFIG.bounds.z.min + 5 or
               newPosition.Z > WORLD_CONFIG.bounds.z.max - 5 or
               newPosition.Y > WORLD_CONFIG.bounds.y.seaLevel - 2 or
               newPosition.Y < WORLD_CONFIG.bounds.y.floor + 2 then
                
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
    return WORLD_CONFIG.bounds
end

function WorldGenerator:GetSpawnGrid()
    return WORLD_CONFIG.spawnGrid
end

function WorldGenerator:CleanupAmbientAssets()
    -- Clean up old ambient assets if performance drops
    local environmentFolder = workspace:FindFirstChild("EnvironmentalAssets")
    if environmentFolder then
        local fishFolder = environmentFolder:FindFirstChild("AmbientFish") 
        if fishFolder then
            local fish = fishFolder:GetChildren()
            if #fish > WORLD_CONFIG.ambientAssets then
                -- Remove oldest fish
                table.sort(fish, function(a, b)
                    return (a:GetAttribute("SpawnTime") or 0) < (b:GetAttribute("SpawnTime") or 0)
                end)
                
                local removeCount = #fish - WORLD_CONFIG.ambientAssets
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

return WorldGenerator