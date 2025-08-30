# AquaticMetropolis - AI Coding Agent Instructions

## Project Overview

AquaticMetropolis is a Roblox underwater survival/crafting game built with Luau. This is an MVP Beta implementation (Phase 0, Week 1) focused on core resource gathering mechanics with performance-first architecture.

## Architecture Patterns

### Server-Client Authority Model

- **All game logic runs server-side** to prevent exploiting
- Client handles only UI feedback and visual effects
- Use `RemoteEvents` in `ReplicatedStorage/RemoteEvents/` for communication
- Example: `ResourceEvents.lua` handles harvest requests/responses

### Modular Data-Driven Design

Core game data lives in `ReplicatedStorage/SharedModules/`:

- `ResourceData.lua` - Resource definitions with spawn rules and visual properties
- `CraftingData.lua` - Recipe definitions with ingredients and durability
- Use module pattern: return both data tables and utility functions

### Performance Budget Enforcement

Critical for Roblox environments:

- Max 1000 parts in workspace (see `GameManager:CleanupExcessParts()`)
- Target 30+ FPS with automatic quality reduction
- Use `spawn()` for background processes, never blocking scripts
- Monitor with `GameManager:MonitorPerformance()` every 5 seconds

## Development Workflows

### Roblox Studio Integration

```bash
# Build place file
rojo build -o "AquaticMetropolis.rbxlx"

# Live sync during development
rojo serve
```

### Server Initialization Sequence

1. `Main.server.lua` coordinates startup
2. `GameManager` initializes world and systems
3. `ResourceSpawner` creates initial resource nodes
4. `PlayerDataManager` handles join/leave events
5. Performance monitoring starts automatically

### Project Structure Convention

```
src/
├── ServerScriptService/Core/     # Core game systems
├── ReplicatedStorage/SharedModules/  # Data definitions
├── StarterGui/                   # Client UI controllers
└── client/                       # Client-only scripts
```

## Project-Specific Patterns

### Resource System Architecture

Resources use server-authoritative spawning:

- Resources spawn at predetermined grid positions (20x20 stud grid)
- Each resource has `spawnChance`, `respawnTime`, `harvestValue`
- Server validates harvest distance (10 stud max) before allowing collection
- Client shows immediate feedback, server confirms/corrects

### UI State Management Pattern

Client UI follows event-driven pattern:

- `InitializeUI` RemoteEvent sends full player data on join
- `HarvestSuccess`/`HarvestFailure` events update UI immediately
- Local state (`currentPlayerData`) mirrors server state
- Use `TweenService` for feedback animations (see `showHarvestMessage()`)

### Error Handling Convention

- Server initialization uses `pcall()` with emergency recovery
- Failed harvests return specific error messages to client
- Performance degradation triggers automatic quality reduction
- Triple-redundant save system (Primary → Backup → Emergency DataStores)

### MVP Constraints

Current implementation deliberately limited:

- 3 resource types only (Kelp, Rock, Pearl)
- 5-slot inventory maximum
- 5 crafting recipes total
- Single 200x200 stud world area
- Focus on core loop validation, not feature completeness

## Integration Points

### Roblox Services Usage

- `DataStoreService` - Triple-redundant player save system
- `RunService.Heartbeat` - Performance monitoring
- `Players.PlayerAdded/Removing` - Session management
- `TweenService` - UI animations and feedback

### External Dependencies

- **Rojo 7.5.1** (managed via Aftman) - File sync and building
- **Aftman** - Toolchain management
- Default Roblox assets for placeholder models

## Critical Implementation Notes

### Performance-First Design

- Scripts auto-cleanup excess parts when limits exceeded
- Background processes use `spawn()`, never block main thread
- Resource nodes limited to 60 total across all types
- UI updates batch every frame, not per-event

### Data Persistence Strategy

Player data saves every 30 seconds with triple redundancy:

```lua
-- Save to 3 DataStores for fault tolerance
"PlayerData_Beta_v1" (Primary)
"PlayerDataBackup_Beta_v1" (Backup)
"PlayerDataEmergency_Beta_v1" (Emergency)
```

### Client-Server Communication

Use specific RemoteEvents, never generic:

- `HarvestResource(resourceType, position)` - Harvest attempt
- `CraftItem(recipeId)` - Crafting request
- `PlaceBuilding(itemId, position)` - Building placement

When adding features, follow the server-authoritative pattern: client requests, server validates and broadcasts results.
