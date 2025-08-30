--[[
TerrainGenerator.lua

Purpose: Enhanced terrain generation system for Week 2 world improvements
Dependencies: TerrainConfig (ReplicatedStorage)
Last Modified: Phase 0 - Week 2
Performance Notes: Optimized noise functions, streaming preparation

Public Methods:
- GenerateEnhancedTerrain(): Create varied underwater terrain with noise
- CreateBiomeFoundations(): Set up biome boundary framework
- GenerateSeafloorVariation(): Advanced seafloor with multiple materials
- AddGeologicalFeatures(): Caves, trenches, and formations
]]--

local TerrainGenerator = {}
local TweenService = game:GetService("TweenService")

-- Enhanced World Configuration for Week 2
local TERRAIN_CONFIG = {
    world = {
        size = {x = 300, z = 300}, -- Expanded from 200x200
        height = {seaLevel = -5, floor = -35, variation = 15}, -- More height variation
        waterDepth = 50
    },
    noise = {
        -- Primary height variation
        primary = {
            frequency = 0.02, -- Larger features
            amplitude = 8,    -- More height variation
            octaves = 3
        },
        -- Detail layer
        detail = {
            frequency = 0.08, -- Smaller features
            amplitude = 3,
            octaves = 2
        },
        -- Material variation
        material = {
            frequency = 0.05,
            threshold = 0.3
        }
    },
    materials = {
        base = Enum.Material.Sand,
        rock = Enum.Material.Rock,
        coral = Enum.Material.Concrete, -- Placeholder until better materials
        mud = Enum.Material.Mud
    },
    features = {
        rockyOutcrops = {count = {12, 18}, size = {8, 25}},
        sandDunes = {count = {8, 12}, size = {15, 30}},
        coralFormations = {count = {6, 10}, size = {5, 15}},
        trenches = {count = {2, 4}, size = {20, 40}}
    }
}

-- Simple noise function (Perlin noise approximation)
local function simpleNoise(x, z, frequency, amplitude)
    -- Basic pseudo-random noise based on position
    local n = math.sin(x * frequency) * math.cos(z * frequency) * amplitude
    return n + (math.random() - 0.5) * amplitude * 0.3
end

-- Multi-octave noise for more complex patterns
local function multiOctaveNoise(x, z, config)
    local total = 0
    local maxValue = 0
    local frequency = config.frequency
    local amplitude = config.amplitude
    
    for i = 1, config.octaves do
        total = total + simpleNoise(x, z, frequency, amplitude)
        maxValue = maxValue + amplitude
        frequency = frequency * 2
        amplitude = amplitude * 0.5
    end
    
    return total / maxValue
end

function TerrainGenerator:GenerateEnhancedTerrain()
    print("🌊 Generating enhanced underwater terrain...")
    
    local terrain = workspace.Terrain
    local startTime = tick()
    
    -- Clear existing terrain in expanded area
    local clearRegion = Region3.new(
        Vector3.new(-TERRAIN_CONFIG.world.size.x, -100, -TERRAIN_CONFIG.world.size.z),
        Vector3.new(TERRAIN_CONFIG.world.size.x, 50, TERRAIN_CONFIG.world.size.z)
    )
    terrain:ReadVoxels(clearRegion, 4)
    
    -- Create water volume (larger and more realistic)
    self:CreateWaterVolume()
    
    -- Generate base seafloor with height variation
    self:GenerateSeafloorVariation()
    
    -- Add geological features
    self:AddGeologicalFeatures()
    
    -- Create biome foundation markers (for future expansion)
    self:CreateBiomeFoundations()
    
    local endTime = tick()
    print(string.format("✅ Enhanced terrain generation complete (%.2fs)", endTime - startTime))
end

function TerrainGenerator:CreateWaterVolume()
    print("💧 Creating enhanced water volume...")
    
    local terrain = workspace.Terrain
    
    -- Larger water volume with depth variation
    local waterRegion = Region3.new(
        Vector3.new(-TERRAIN_CONFIG.world.size.x - 20, TERRAIN_CONFIG.world.height.seaLevel - TERRAIN_CONFIG.world.waterDepth, -TERRAIN_CONFIG.world.size.z - 20),
        Vector3.new(TERRAIN_CONFIG.world.size.x + 20, TERRAIN_CONFIG.world.height.seaLevel + 30, TERRAIN_CONFIG.world.size.z + 20)
    )
    
    terrain:FillRegion(waterRegion, 4, Enum.Material.Water)
    
    -- Add underwater fog effects using Atmosphere (enhanced from Week 1)
    self:EnhanceUnderwaterAtmosphere()
    
    print("💧 Enhanced water volume created")
end

function TerrainGenerator:EnhanceUnderwaterAtmosphere()
    local lighting = game:GetService("Lighting")
    
    -- Enhanced underwater lighting with depth variation
    lighting.Brightness = 1.2
    lighting.Ambient = Color3.fromRGB(85, 135, 185) -- Deeper blue-green
    lighting.OutdoorAmbient = Color3.fromRGB(65, 105, 145)
    lighting.TimeOfDay = "13:30:00" -- Slightly earlier for more interesting shadows
    lighting.GeographicLatitude = 15 -- Slight angle for better light rays
    
    -- Enhanced atmosphere with depth effects
    local existingAtmosphere = lighting:FindFirstChildOfClass("Atmosphere")
    if existingAtmosphere then
        existingAtmosphere:Destroy()
    end
    
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density = 0.4 -- Slightly denser for better depth perception
    atmosphere.Offset = 0.15
    atmosphere.Color = Color3.fromRGB(140, 180, 220)
    atmosphere.Decay = Color3.fromRGB(80, 130, 180)
    atmosphere.Glare = 0.3
    atmosphere.Haze = 0.4 -- More haze for underwater feel
    atmosphere.Parent = lighting
end

function TerrainGenerator:GenerateSeafloorVariation()
    print("🏖️ Generating varied seafloor...")
    
    local terrain = workspace.Terrain
    local stepSize = 12 -- Smaller steps for more detail
    
    for x = -TERRAIN_CONFIG.world.size.x, TERRAIN_CONFIG.world.size.x, stepSize do
        for z = -TERRAIN_CONFIG.world.size.z, TERRAIN_CONFIG.world.size.z, stepSize do
            -- Generate height using multi-octave noise
            local primaryHeight = multiOctaveNoise(x, z, TERRAIN_CONFIG.noise.primary)
            local detailHeight = multiOctaveNoise(x, z, TERRAIN_CONFIG.noise.detail)
            
            local finalHeight = TERRAIN_CONFIG.world.height.floor + primaryHeight + detailHeight
            
            -- Determine material based on height and noise
            local material = self:DetermineMaterial(x, z, finalHeight)
            
            -- Create terrain region
            local regionBottom = finalHeight - 8
            local regionTop = finalHeight + 2
            
            local floorRegion = Region3.new(
                Vector3.new(x, regionBottom, z),
                Vector3.new(x + stepSize, regionTop, z + stepSize)
            )
            
            terrain:FillRegion(floorRegion, 4, material)
        end
    end
    
    print("🏖️ Varied seafloor generation complete")
end

function TerrainGenerator:DetermineMaterial(x, z, height)
    -- Use noise to determine material type
    local materialNoise = simpleNoise(x, z, TERRAIN_CONFIG.noise.material.frequency, 1)
    
    -- Height-based material selection
    if height > TERRAIN_CONFIG.world.height.floor + 6 then
        -- Higher areas more likely to be rocky
        return materialNoise > 0.2 and TERRAIN_CONFIG.materials.rock or TERRAIN_CONFIG.materials.base
    elseif height < TERRAIN_CONFIG.world.height.floor - 2 then
        -- Lower areas more likely to be muddy
        return materialNoise < -0.3 and TERRAIN_CONFIG.materials.mud or TERRAIN_CONFIG.materials.base
    else
        -- Middle areas vary between sand and coral
        if materialNoise > TERRAIN_CONFIG.noise.material.threshold then
            return TERRAIN_CONFIG.materials.coral
        else
            return TERRAIN_CONFIG.materials.base
        end
    end
end

function TerrainGenerator:AddGeologicalFeatures()
    print("🗻 Adding geological features...")
    
    -- Rocky outcrops (enhanced from Week 1)
    self:CreateRockyOutcrops()
    
    -- Sand dunes for variety
    self:CreateSandDunes()
    
    -- Coral formations (placeholder)
    self:CreateCoralFormations()
    
    -- Small trenches and valleys
    self:CreateTrenches()
    
    print("🗻 Geological features added")
end

function TerrainGenerator:CreateRockyOutcrops()
    local terrain = workspace.Terrain
    local config = TERRAIN_CONFIG.features.rockyOutcrops
    local outcroppings = math.random(config.count[1], config.count[2])
    
    for i = 1, outcroppings do
        local x = math.random(-TERRAIN_CONFIG.world.size.x + 30, TERRAIN_CONFIG.world.size.x - 30)
        local z = math.random(-TERRAIN_CONFIG.world.size.z + 30, TERRAIN_CONFIG.world.size.z - 30)
        
        -- Varied heights and sizes
        local baseHeight = TERRAIN_CONFIG.world.height.floor + math.random(2, 8)
        local size = math.random(config.size[1], config.size[2])
        local height = math.random(8, 15)
        
        -- Create irregular rock formation
        local rockRegion = Region3.new(
            Vector3.new(x, baseHeight - 3, z),
            Vector3.new(x + size, baseHeight + height, z + size * 0.8)
        )
        
        terrain:FillRegion(rockRegion, 4, TERRAIN_CONFIG.materials.rock)
        
        -- Add smaller rock pieces around main formation
        for j = 1, math.random(2, 4) do
            local offsetX = x + math.random(-size/2, size/2)
            local offsetZ = z + math.random(-size/2, size/2)
            local smallSize = math.random(3, 8)
            
            local smallRockRegion = Region3.new(
                Vector3.new(offsetX, baseHeight - 1, offsetZ),
                Vector3.new(offsetX + smallSize, baseHeight + smallSize, offsetZ + smallSize)
            )
            
            terrain:FillRegion(smallRockRegion, 4, TERRAIN_CONFIG.materials.rock)
        end
    end
    
    print("🪨 Enhanced rocky outcroppings created")
end

function TerrainGenerator:CreateSandDunes()
    local terrain = workspace.Terrain
    local config = TERRAIN_CONFIG.features.sandDunes
    local dunes = math.random(config.count[1], config.count[2])
    
    for i = 1, dunes do
        local x = math.random(-TERRAIN_CONFIG.world.size.x + 20, TERRAIN_CONFIG.world.size.x - 20)
        local z = math.random(-TERRAIN_CONFIG.world.size.z + 20, TERRAIN_CONFIG.world.size.z - 20)
        
        local size = math.random(config.size[1], config.size[2])
        local height = math.random(3, 6)
        local baseHeight = TERRAIN_CONFIG.world.height.floor + 1
        
        -- Create gentle sloping dune
        local duneRegion = Region3.new(
            Vector3.new(x, baseHeight - 2, z),
            Vector3.new(x + size, baseHeight + height, z + size * 0.6)
        )
        
        terrain:FillRegion(duneRegion, 4, TERRAIN_CONFIG.materials.base)
    end
    
    print("🏔️ Sand dunes created")
end

function TerrainGenerator:CreateCoralFormations()
    local terrain = workspace.Terrain
    local config = TERRAIN_CONFIG.features.coralFormations
    local formations = math.random(config.count[1], config.count[2])
    
    for i = 1, formations do
        local x = math.random(-TERRAIN_CONFIG.world.size.x + 15, TERRAIN_CONFIG.world.size.x - 15)
        local z = math.random(-TERRAIN_CONFIG.world.size.z + 15, TERRAIN_CONFIG.world.size.z - 15)
        
        local size = math.random(config.size[1], config.size[2])
        local height = math.random(4, 10)
        local baseHeight = TERRAIN_CONFIG.world.height.floor + 2
        
        -- Create coral-like structure (using concrete as placeholder)
        local coralRegion = Region3.new(
            Vector3.new(x, baseHeight, z),
            Vector3.new(x + size, baseHeight + height, z + size)
        )
        
        terrain:FillRegion(coralRegion, 4, TERRAIN_CONFIG.materials.coral)
    end
    
    print("🪸 Coral formations created")
end

function TerrainGenerator:CreateTrenches()
    local terrain = workspace.Terrain
    local config = TERRAIN_CONFIG.features.trenches
    local trenches = math.random(config.count[1], config.count[2])
    
    for i = 1, trenches do
        local x = math.random(-TERRAIN_CONFIG.world.size.x + 40, TERRAIN_CONFIG.world.size.x - 40)
        local z = math.random(-TERRAIN_CONFIG.world.size.z + 40, TERRAIN_CONFIG.world.size.z - 40)
        
        local length = math.random(config.size[1], config.size[2])
        local width = math.random(8, 15)
        local depth = math.random(6, 12)
        
        -- Create trench by removing terrain
        local trenchRegion = Region3.new(
            Vector3.new(x, TERRAIN_CONFIG.world.height.floor - depth, z),
            Vector3.new(x + length, TERRAIN_CONFIG.world.height.floor + 2, z + width)
        )
        
        -- Fill with water to create deep channel
        terrain:ReadVoxels(trenchRegion, 4)
        terrain:FillRegion(trenchRegion, 4, Enum.Material.Water)
    end
    
    print("🕳️ Trenches and valleys created")
end

function TerrainGenerator:CreateBiomeFoundations()
    print("🗺️ Creating biome foundation markers...")
    
    -- Create invisible markers for future biome system
    local biomeFolder = workspace:FindFirstChild("BiomeMarkers")
    if not biomeFolder then
        biomeFolder = Instance.new("Folder")
        biomeFolder.Name = "BiomeMarkers"
        biomeFolder.Parent = workspace
    end
    
    -- Define future biome areas (central hub + surrounding zones)
    local biomes = {
        {name = "TidalSprout", center = Vector3.new(0, -15, 0), radius = 50, priority = 1},
        {name = "KelpForest", center = Vector3.new(-80, -20, 80), radius = 60, priority = 2},
        {name = "CrystalGrotto", center = Vector3.new(90, -25, -70), radius = 45, priority = 3},
        {name = "FadingReef", center = Vector3.new(70, -18, 90), radius = 55, priority = 4}
    }
    
    for _, biome in ipairs(biomes) do
        local marker = Instance.new("Part")
        marker.Name = biome.name .. "_Marker"
        marker.Size = Vector3.new(1, 1, 1)
        marker.Material = Enum.Material.ForceField
        marker.CanCollide = false
        marker.Anchored = true
        marker.Transparency = 1 -- Invisible
        marker.Position = biome.center
        marker.Parent = biomeFolder
        
        -- Store biome data as attributes
        marker:SetAttribute("BiomeName", biome.name)
        marker:SetAttribute("Radius", biome.radius)
        marker:SetAttribute("Priority", biome.priority)
        marker:SetAttribute("Active", false) -- Will be activated in future weeks
    end
    
    print("🗺️ Biome foundation markers created for future expansion")
end

function TerrainGenerator:GetTerrainBounds()
    return {
        x = {min = -TERRAIN_CONFIG.world.size.x, max = TERRAIN_CONFIG.world.size.x},
        z = {min = -TERRAIN_CONFIG.world.size.z, max = TERRAIN_CONFIG.world.size.z},
        y = {
            seaLevel = TERRAIN_CONFIG.world.height.seaLevel,
            floor = TERRAIN_CONFIG.world.height.floor,
            ceiling = TERRAIN_CONFIG.world.height.seaLevel - 2
        }
    }
end

function TerrainGenerator:GetWorldSize()
    return TERRAIN_CONFIG.world.size
end

-- Performance monitoring for terrain generation
function TerrainGenerator:BenchmarkGeneration()
    local startTime = tick()
    
    -- Run a small test generation
    local testSize = 50
    local terrain = workspace.Terrain
    
    for x = -testSize, testSize, 10 do
        for z = -testSize, testSize, 10 do
            local height = multiOctaveNoise(x, z, TERRAIN_CONFIG.noise.primary)
            -- Minimal terrain operation for benchmarking
        end
    end
    
    local endTime = tick()
    local generationTime = endTime - startTime
    
    print(string.format("🔧 Terrain benchmark: %.3fs for test area", generationTime))
    
    return generationTime
end

return TerrainGenerator