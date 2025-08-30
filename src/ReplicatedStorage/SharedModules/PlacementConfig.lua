--[[
PlacementConfig.lua

Purpose: Configuration for procedural asset placement system
Dependencies: None (pure configuration)
Last Modified: Phase 0 - Week 2
Performance Notes: Configuration only, no heavy computations

Configuration Data:
- Resource placement rules and density maps
- Collision detection parameters
- Placement validation settings
- Biome-specific placement modifiers
]]--

local PlacementConfig = {}

-- Grid-based placement system configuration
PlacementConfig.Grid = {
    -- Base grid size (studs between potential placements)
    baseSize = 12,
    
    -- Grid variation (randomize positions within grid cells)
    variation = 6, -- +/- 6 studs from grid center
    
    -- Minimum distance between resources of same type
    minSeparation = 8,
    
    -- Maximum placement attempts per grid cell
    maxAttempts = 5
}

-- Resource-specific placement rules
PlacementConfig.Resources = {
    ["Kelp"] = {
        -- Density per 100x100 stud area
        baseDensity = 0.8,
        
        -- Clustering tendency (0 = random, 1 = heavily clustered)
        clustering = 0.4,
        
        -- Preferred terrain materials
        preferredMaterials = {"Sand", "Mud"},
        
        -- Avoid these materials
        avoidMaterials = {"Rock"},
        
        -- Height preferences (relative to seafloor)
        heightRange = {min = 1, max = 8}, -- 1-8 studs above seafloor
        
        -- Spawn in groups
        groupSize = {min = 1, max = 4},
        groupRadius = 8,
        
        -- Environmental requirements
        minDepth = 8,  -- Minimum water depth required
        maxDepth = 40, -- Maximum depth before too dark
        
        -- Placement validation
        collisionRadius = 3, -- Check for obstacles within 3 studs
        surfaceAngleLimit = 30 -- Maximum slope angle in degrees
    },
    
    ["Rock"] = {
        baseDensity = 0.5,
        clustering = 0.6, -- Rocks cluster more than kelp
        
        preferredMaterials = {"Rock", "Sand"},
        avoidMaterials = {"Water"},
        
        heightRange = {min = 0, max = 3}, -- Close to seafloor
        
        groupSize = {min = 1, max = 6},
        groupRadius = 12,
        
        minDepth = 5,
        maxDepth = 50,
        
        collisionRadius = 4,
        surfaceAngleLimit = 45 -- Rocks can spawn on steeper slopes
    },
    
    ["Pearl"] = {
        baseDensity = 0.15, -- Much rarer
        clustering = 0.2, -- More evenly distributed
        
        preferredMaterials = {"Sand", "Concrete"}, -- Concrete = coral placeholder
        avoidMaterials = {"Rock", "Mud"},
        
        heightRange = {min = 0.5, max = 2}, -- Close to seafloor
        
        groupSize = {min = 1, max = 2}, -- Usually single pearls
        groupRadius = 5,
        
        minDepth = 10, -- Deeper water preferred
        maxDepth = 35,
        
        collisionRadius = 2,
        surfaceAngleLimit = 20 -- Pearls need relatively flat surfaces
    }
}

-- Biome-specific placement modifiers (for future use)
PlacementConfig.BiomeModifiers = {
    ["TidalSprout"] = {
        -- Central hub - balanced resources
        densityMultiplier = {
            Kelp = 1.2,
            Rock = 0.8,
            Pearl = 1.0
        },
        
        -- Safer placement rules in hub area
        minSeparation = 10,
        maxDensity = 0.6 -- Prevent overcrowding in social area
    },
    
    ["KelpForest"] = {
        -- Future kelp forest - high kelp density
        densityMultiplier = {
            Kelp = 2.0,
            Rock = 0.3,
            Pearl = 0.5
        }
    },
    
    ["CrystalGrotto"] = {
        -- Future crystal area - more rocks, fewer pearls
        densityMultiplier = {
            Kelp = 0.4,
            Rock = 1.8,
            Pearl = 0.2
        }
    },
    
    ["FadingReef"] = {
        -- Ancient reef - balanced with slight pearl increase
        densityMultiplier = {
            Kelp = 0.8,
            Rock = 1.0,
            Pearl = 1.4
        }
    }
}

-- Collision detection configuration
PlacementConfig.Collision = {
    -- Raycast parameters for surface detection
    raycastParams = {
        direction = Vector3.new(0, -20, 0), -- Cast downward 20 studs
        filterType = Enum.RaycastFilterType.Blacklist,
        ignoreWater = false
    },
    
    -- Overlap detection for other resources
    overlapRadius = 5, -- Check 5 stud radius for existing resources
    
    -- Surface validation
    requireSolidSurface = true,
    maxSurfaceDistance = 3, -- Surface must be within 3 studs below spawn point
    
    -- Avoid player spawn areas
    playerSpawnRadius = 25, -- Keep resources away from spawn points
    
    -- Building area avoidance (for future building system)
    buildingAreaRadius = 15
}

-- Noise-based placement variation
PlacementConfig.Noise = {
    -- Primary density variation across world
    primary = {
        frequency = 0.03,
        amplitude = 0.4, -- Can reduce density by up to 40%
        offset = 0.6 -- Base density multiplier
    },
    
    -- Secondary cluster formation
    secondary = {
        frequency = 0.08,
        amplitude = 0.3,
        threshold = 0.2 -- Only apply clustering above this noise value
    },
    
    -- Material preference modifier
    material = {
        frequency = 0.05,
        amplitude = 0.25
    }
}

-- Performance limits and optimization
PlacementConfig.Performance = {
    -- Maximum resources per region (100x100 stud area)
    maxResourcesPerRegion = 50,
    
    -- Maximum total resources in world
    maxTotalResources = 200, -- Increased from Week 1's 60
    
    -- Placement processing limits
    maxPlacementsPerFrame = 10, -- Place max 10 resources per frame
    placementYieldInterval = 0.05, -- Yield every 50ms during placement
    
    -- Batch processing configuration
    processingBatchSize = 25, -- Process 25 grid cells at once
    batchDelay = 0.1, -- Wait 100ms between batches
    
    -- Cleanup thresholds
    cleanupTriggerCount = 180, -- Start cleanup when over this count
    cleanupTargetCount = 150   -- Clean down to this count
}

-- Validation functions for placement system
PlacementConfig.Validation = {
    -- Check if material is suitable for resource type
    isMaterialSuitable = function(material, resourceType)
        local config = PlacementConfig.Resources[resourceType]
        if not config then return false end
        
        local materialName = tostring(material):gsub("Enum.Material.", "")
        
        -- Check if material is preferred
        for _, preferred in ipairs(config.preferredMaterials) do
            if materialName == preferred then
                return true
            end
        end
        
        -- Check if material is avoided
        for _, avoided in ipairs(config.avoidMaterials) do
            if materialName == avoided then
                return false
            end
        end
        
        -- Neutral materials are acceptable with reduced probability
        return math.random() < 0.3
    end,
    
    -- Check if position is valid for resource type
    isPositionValid = function(position, resourceType, existingResources)
        local config = PlacementConfig.Resources[resourceType]
        if not config then return false end
        
        -- Check minimum separation from existing resources
        for _, existing in ipairs(existingResources) do
            local distance = (position - existing.Position).Magnitude
            if distance < config.collisionRadius * 2 then
                return false
            end
        end
        
        return true
    end,
    
    -- Calculate density modifier based on biome
    getBiomeDensityModifier = function(position, resourceType)
        -- Simple distance-based biome detection for now
        local distanceFromCenter = (position - Vector3.new(0, 0, 0)).Magnitude
        
        if distanceFromCenter < 50 then
            -- Central hub area
            local modifier = PlacementConfig.BiomeModifiers.TidalSprout.densityMultiplier[resourceType]
            return modifier or 1.0
        end
        
        -- Default modifier for areas outside defined biomes
        return 1.0
    end
}

-- Debug and monitoring configuration
PlacementConfig.Debug = {
    -- Enable debug visualization
    showPlacementGrid = false,
    showCollisionAreas = false,
    showDensityMaps = false,
    
    -- Logging levels
    logPlacements = false,
    logCollisions = false,
    logPerformance = true,
    
    -- Debug colors for different resource types
    debugColors = {
        Kelp = Color3.fromRGB(0, 255, 0),
        Rock = Color3.fromRGB(128, 128, 128),
        Pearl = Color3.fromRGB(255, 255, 255)
    }
}

return PlacementConfig