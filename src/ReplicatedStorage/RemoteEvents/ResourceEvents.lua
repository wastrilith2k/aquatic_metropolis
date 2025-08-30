--[[
ResourceEvents.lua

Purpose: Remote events for resource harvesting communication
Dependencies: None (RemoteEvent container)
Last Modified: Phase 0 - Week 1

Events:
- HarvestSuccess: Server → Client when harvest succeeds
- HarvestFailure: Server → Client when harvest fails
- UpdateInventory: Server → Client when inventory changes
- InitializeUI: Server → Client when player joins
]]--

-- Create RemoteEvents folder if it doesn't exist
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")

if not RemoteEventsFolder then
    RemoteEventsFolder = Instance.new("Folder")
    RemoteEventsFolder.Name = "RemoteEvents"
    RemoteEventsFolder.Parent = ReplicatedStorage
end

-- Resource harvesting events
local HarvestSuccess = Instance.new("RemoteEvent")
HarvestSuccess.Name = "HarvestSuccess"
HarvestSuccess.Parent = RemoteEventsFolder

local HarvestFailure = Instance.new("RemoteEvent")
HarvestFailure.Name = "HarvestFailure"
HarvestFailure.Parent = RemoteEventsFolder

-- UI update events
local UpdateInventory = Instance.new("RemoteEvent")
UpdateInventory.Name = "UpdateInventory"
UpdateInventory.Parent = ReplicatedStorage

local InitializeUI = Instance.new("RemoteEvent")
InitializeUI.Name = "InitializeUI"
InitializeUI.Parent = ReplicatedStorage

print("✅ Remote events created for resource system")