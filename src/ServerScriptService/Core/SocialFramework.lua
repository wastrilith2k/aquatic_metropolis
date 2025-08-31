--[[
SocialFramework.lua

Purpose: Social system foundation for Week 6 Phase 1 preparation
Dependencies: PlayerDataManager, BetaAnalytics, DataStoreService
Last Modified: Phase 0 - Week 6
Performance Notes: Efficient friend relationship management with privacy compliance

Foundation Features:
- Friend system data architecture with relationship tracking
- Permission framework for resource sharing and collaborative building
- Privacy-compliant friend discovery and interaction systems
- Social interaction analytics preparation for Phase 1 metrics
- Communication foundation with safety and moderation hooks
- Collaborative building space allocation and ownership tracking
]]--

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Data storage
local SocialDataStore = DataStoreService:GetDataStore("SocialData_v1")
local FriendRelationshipsStore = DataStoreService:GetDataStore("FriendRelationships_v1")
local CollaborativeSpacesStore = DataStoreService:GetDataStore("CollaborativeSpaces_v1")

-- Remote events for social interactions
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Create social remote events
local SendFriendRequestEvent = Instance.new("RemoteEvent")
SendFriendRequestEvent.Name = "SendFriendRequest"
SendFriendRequestEvent.Parent = RemoteEvents

local RespondFriendRequestEvent = Instance.new("RemoteEvent")
RespondFriendRequestEvent.Name = "RespondFriendRequest"
RespondFriendRequestEvent.Parent = RemoteEvents

local GetFriendListEvent = Instance.new("RemoteEvent")
GetFriendListEvent.Name = "GetFriendList"
GetFriendListEvent.Parent = RemoteEvents

local ShareResourcesEvent = Instance.new("RemoteEvent")
ShareResourcesEvent.Name = "ShareResources"
ShareResourcesEvent.Parent = RemoteEvents

local RequestBuildingPermissionEvent = Instance.new("RemoteEvent")
RequestBuildingPermissionEvent.Name = "RequestBuildingPermission"
RequestBuildingPermissionEvent.Parent = RemoteEvents

local SocialFramework = {}
SocialFramework.__index = SocialFramework

-- Friend relationship types
local RELATIONSHIP_TYPES = {
    NONE = "none",
    FRIEND_REQUEST_SENT = "request_sent",
    FRIEND_REQUEST_RECEIVED = "request_received", 
    FRIENDS = "friends",
    BLOCKED = "blocked"
}

-- Permission levels for collaborative features
local PERMISSION_LEVELS = {
    NONE = 0,           -- No access
    VIEW = 1,           -- Can view shared spaces
    INTERACT = 2,       -- Can harvest shared resources
    CONTRIBUTE = 3,     -- Can place/modify buildings in shared spaces
    ADMIN = 4           -- Full control (same as owner)
}

-- Collaboration space types
local SPACE_TYPES = {
    PERSONAL = "personal",       -- Player's private area
    SHARED = "shared",          -- Shared with specific friends
    COMMUNITY = "community"     -- Open to any friends
}

function SocialFramework:Initialize()
    print("🤝 Initializing Social Framework...")
    
    -- Initialize social data structure
    self.playerRelationships = {}  -- userId -> {friendId -> relationshipData}
    self.friendRequests = {}       -- userId -> {requestId -> requestData}
    self.collaborativeSpaces = {} -- spaceId -> spaceData
    self.onlinePlayerTracking = {}
    
    -- Connect social events
    self:connectSocialEvents()
    
    -- Start periodic cleanup and maintenance
    self:startSocialMaintenance()
    
    print("✅ Social Framework initialized")
    return true
end

function SocialFramework:connectSocialEvents()
    -- Player connection tracking for social features
    Players.PlayerAdded:Connect(function(player)
        self:onPlayerJoinSocial(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:onPlayerLeaveSocial(player)
    end)
    
    -- Friend system events
    SendFriendRequestEvent.OnServerEvent:Connect(function(player, targetPlayerName)
        self:handleFriendRequest(player, targetPlayerName)
    end)
    
    RespondFriendRequestEvent.OnServerEvent:Connect(function(player, requestId, accepted)
        self:handleFriendRequestResponse(player, requestId, accepted)
    end)
    
    GetFriendListEvent.OnServerEvent:Connect(function(player)
        self:sendFriendList(player)
    end)
    
    -- Collaborative features
    ShareResourcesEvent.OnServerEvent:Connect(function(player, friendId, resourceType, amount)
        self:handleResourceSharing(player, friendId, resourceType, amount)
    end)
    
    RequestBuildingPermissionEvent.OnServerEvent:Connect(function(player, spaceId, permissionLevel)
        self:handleBuildingPermissionRequest(player, spaceId, permissionLevel)
    end)
end

-- Player session management
function SocialFramework:onPlayerJoinSocial(player)
    local userId = player.UserId
    
    -- Track online status
    self.onlinePlayerTracking[userId] = {
        player = player,
        joinTime = tick(),
        lastActivity = tick()
    }
    
    -- Load social data
    self:loadPlayerSocialData(userId)
    
    -- Notify friends of online status
    self:notifyFriendsOnlineStatus(userId, true)
    
    print(string.format("👥 Social tracking started for %s", player.Name))
end

function SocialFramework:onPlayerLeaveSocial(player)
    local userId = player.UserId
    
    -- Save social data
    self:savePlayerSocialData(userId)
    
    -- Notify friends of offline status
    self:notifyFriendsOnlineStatus(userId, false)
    
    -- Clean up tracking
    self.onlinePlayerTracking[userId] = nil
    
    print(string.format("👥 Social tracking ended for %s", player.Name))
end

function SocialFramework:loadPlayerSocialData(userId)
    spawn(function()
        -- Load relationship data
        local success, relationshipData = pcall(function()
            return SocialDataStore:GetAsync("relationships_" .. userId)
        end)
        
        if success and relationshipData then
            self.playerRelationships[userId] = relationshipData.relationships or {}
            self.friendRequests[userId] = relationshipData.pendingRequests or {}
        else
            self.playerRelationships[userId] = {}
            self.friendRequests[userId] = {}
        end
        
        -- Load collaborative spaces the player is part of
        local spaceSuccess, spaceData = pcall(function()
            return CollaborativeSpacesStore:GetAsync("player_spaces_" .. userId)
        end)
        
        if spaceSuccess and spaceData then
            -- Update collaborative spaces cache
            for spaceId, permissions in pairs(spaceData.spaces or {}) do
                if not self.collaborativeSpaces[spaceId] then
                    self:loadCollaborativeSpace(spaceId)
                end
            end
        end
    end)
end

function SocialFramework:savePlayerSocialData(userId)
    spawn(function()
        local socialData = {
            relationships = self.playerRelationships[userId] or {},
            pendingRequests = self.friendRequests[userId] or {},
            lastSaved = tick()
        }
        
        local success, error = pcall(function()
            SocialDataStore:SetAsync("relationships_" .. userId, socialData)
        end)
        
        if not success then
            warn("Failed to save social data for user " .. userId .. ":", error)
        end
    end)
end

-- Friend system implementation
function SocialFramework:handleFriendRequest(fromPlayer, targetPlayerName)
    local fromUserId = fromPlayer.UserId
    
    -- Find target player
    local targetPlayer = self:findPlayerByName(targetPlayerName)
    if not targetPlayer then
        -- Player not found or not online
        self:sendSocialNotification(fromPlayer, "error", "Player not found or not online")
        return
    end
    
    local targetUserId = targetPlayer.UserId
    
    -- Prevent self-friending
    if fromUserId == targetUserId then
        self:sendSocialNotification(fromPlayer, "error", "You cannot send a friend request to yourself")
        return
    end
    
    -- Check existing relationship
    local existingRelationship = self:getRelationshipStatus(fromUserId, targetUserId)
    if existingRelationship == RELATIONSHIP_TYPES.FRIENDS then
        self:sendSocialNotification(fromPlayer, "error", "You are already friends with this player")
        return
    elseif existingRelationship == RELATIONSHIP_TYPES.FRIEND_REQUEST_SENT then
        self:sendSocialNotification(fromPlayer, "error", "Friend request already sent")
        return
    elseif existingRelationship == RELATIONSHIP_TYPES.BLOCKED then
        self:sendSocialNotification(fromPlayer, "error", "Cannot send friend request")
        return
    end
    
    -- Create friend request
    local requestId = HttpService:GenerateGUID(false)
    local requestData = {
        id = requestId,
        fromUserId = fromUserId,
        fromPlayerName = fromPlayer.Name,
        toUserId = targetUserId,
        toPlayerName = targetPlayer.Name,
        timestamp = tick(),
        status = "pending"
    }
    
    -- Store request
    if not self.friendRequests[targetUserId] then
        self.friendRequests[targetUserId] = {}
    end
    self.friendRequests[targetUserId][requestId] = requestData
    
    -- Update relationship status
    self:setRelationshipStatus(fromUserId, targetUserId, RELATIONSHIP_TYPES.FRIEND_REQUEST_SENT)
    self:setRelationshipStatus(targetUserId, fromUserId, RELATIONSHIP_TYPES.FRIEND_REQUEST_RECEIVED)
    
    -- Notify both players
    self:sendSocialNotification(fromPlayer, "success", "Friend request sent to " .. targetPlayer.Name)
    self:sendSocialNotification(targetPlayer, "friend_request", fromPlayer.Name .. " sent you a friend request", requestData)
    
    -- Analytics tracking
    if _G.BetaAnalytics then
        _G.BetaAnalytics:recordPlayerAction(fromPlayer, "friend_request_sent", {
            targetUserId = targetUserId,
            targetPlayerName = targetPlayer.Name
        })
    end
    
    print(string.format("👫 Friend request: %s -> %s", fromPlayer.Name, targetPlayer.Name))
end

function SocialFramework:handleFriendRequestResponse(player, requestId, accepted)
    local userId = player.UserId
    local requestData = self.friendRequests[userId] and self.friendRequests[userId][requestId]
    
    if not requestData then
        self:sendSocialNotification(player, "error", "Friend request not found")
        return
    end
    
    local fromUserId = requestData.fromUserId
    local fromPlayer = Players:GetPlayerByUserId(fromUserId)
    
    -- Remove the request
    self.friendRequests[userId][requestId] = nil
    
    if accepted then
        -- Create friendship
        self:setRelationshipStatus(userId, fromUserId, RELATIONSHIP_TYPES.FRIENDS)
        self:setRelationshipStatus(fromUserId, userId, RELATIONSHIP_TYPES.FRIENDS)
        
        -- Create friendship record with metadata
        local friendshipData = {
            establishedDate = tick(),
            sharedResources = 0,
            collaborativeBuildingCount = 0,
            lastInteraction = tick()
        }
        
        self:setFriendshipData(userId, fromUserId, friendshipData)
        self:setFriendshipData(fromUserId, userId, friendshipData)
        
        -- Notify both players
        self:sendSocialNotification(player, "success", "You are now friends with " .. requestData.fromPlayerName)
        if fromPlayer then
            self:sendSocialNotification(fromPlayer, "success", player.Name .. " accepted your friend request")
        end
        
        -- Analytics tracking
        if _G.BetaAnalytics then
            _G.BetaAnalytics:recordPlayerAction(player, "friend_request_accepted", {
                fromUserId = fromUserId,
                fromPlayerName = requestData.fromPlayerName
            })
        end
        
        print(string.format("✅ Friendship established: %s <-> %s", player.Name, requestData.fromPlayerName))
    else
        -- Clear relationship status
        self:setRelationshipStatus(userId, fromUserId, RELATIONSHIP_TYPES.NONE)
        self:setRelationshipStatus(fromUserId, userId, RELATIONSHIP_TYPES.NONE)
        
        -- Notify only the responding player (don't tell sender about rejection)
        self:sendSocialNotification(player, "info", "Friend request declined")
        
        -- Analytics tracking
        if _G.BetaAnalytics then
            _G.BetaAnalytics:recordPlayerAction(player, "friend_request_declined", {
                fromUserId = fromUserId
            })
        end
    end
end

function SocialFramework:sendFriendList(player)
    local userId = player.UserId
    local friendList = {}
    
    -- Get all friends
    local relationships = self.playerRelationships[userId] or {}
    for friendId, relationshipData in pairs(relationships) do
        if relationshipData.status == RELATIONSHIP_TYPES.FRIENDS then
            local friendInfo = {
                userId = friendId,
                isOnline = self.onlinePlayerTracking[friendId] ~= nil,
                friendshipData = relationshipData.friendshipData or {},
                lastSeen = relationshipData.lastSeen or 0
            }
            
            -- Get current name if online
            if friendInfo.isOnline then
                local friendPlayer = Players:GetPlayerByUserId(friendId)
                if friendPlayer then
                    friendInfo.name = friendPlayer.Name
                end
            end
            
            table.insert(friendList, friendInfo)
        end
    end
    
    -- Send friend list to client
    GetFriendListEvent:FireClient(player, friendList)
end

-- Resource sharing system
function SocialFramework:handleResourceSharing(player, friendId, resourceType, amount)
    local userId = player.UserId
    
    -- Validate friendship
    if not self:areFriends(userId, friendId) then
        self:sendSocialNotification(player, "error", "You can only share resources with friends")
        return
    end
    
    -- Validate player has resources
    local PlayerDataManager = require(script.Parent.PlayerDataManager)
    local playerData = PlayerDataManager:GetPlayerData(player)
    
    if not playerData or not playerData.inventory or (playerData.inventory[resourceType] or 0) < amount then
        self:sendSocialNotification(player, "error", "You don't have enough " .. resourceType .. " to share")
        return
    end
    
    -- Find friend player
    local friendPlayer = Players:GetPlayerByUserId(friendId)
    if not friendPlayer then
        self:sendSocialNotification(player, "error", "Friend is not online")
        return
    end
    
    -- Transfer resources
    local success = PlayerDataManager:TransferResources(player, friendPlayer, resourceType, amount)
    if success then
        -- Update friendship interaction data
        self:updateFriendshipInteraction(userId, friendId, "resource_shared", {
            resourceType = resourceType,
            amount = amount,
            timestamp = tick()
        })
        
        -- Notify both players
        self:sendSocialNotification(player, "success", string.format("Shared %d %s with %s", amount, resourceType, friendPlayer.Name))
        self:sendSocialNotification(friendPlayer, "resource_received", string.format("%s shared %d %s with you", player.Name, amount, resourceType))
        
        -- Analytics tracking
        if _G.BetaAnalytics then
            _G.BetaAnalytics:recordPlayerAction(player, "resource_shared", {
                friendId = friendId,
                resourceType = resourceType,
                amount = amount
            })
        end
        
        print(string.format("📤 Resource shared: %s -> %s: %d %s", player.Name, friendPlayer.Name, amount, resourceType))
    else
        self:sendSocialNotification(player, "error", "Failed to share resources")
    end
end

-- Collaborative building system foundation
function SocialFramework:createCollaborativeSpace(ownerId, spaceType, spaceName)
    local spaceId = HttpService:GenerateGUID(false)
    local spaceData = {
        id = spaceId,
        name = spaceName or "Collaborative Space",
        ownerId = ownerId,
        type = spaceType,
        createdDate = tick(),
        lastModified = tick(),
        participants = {
            [ownerId] = {
                permissionLevel = PERMISSION_LEVELS.ADMIN,
                joinedDate = tick(),
                contributionScore = 0
            }
        },
        buildings = {},
        sharedResources = {},
        settings = {
            allowFriendInvites = true,
            requirePermissionForBuilding = true,
            maxParticipants = spaceType == "community" and 10 or 4
        }
    }
    
    self.collaborativeSpaces[spaceId] = spaceData
    self:saveCollaborativeSpace(spaceId)
    
    return spaceId, spaceData
end

function SocialFramework:handleBuildingPermissionRequest(player, spaceId, permissionLevel)
    local userId = player.UserId
    local spaceData = self.collaborativeSpaces[spaceId]
    
    if not spaceData then
        self:sendSocialNotification(player, "error", "Collaborative space not found")
        return
    end
    
    -- Check if player is owner or admin
    local playerPermission = spaceData.participants[userId]
    if not playerPermission or playerPermission.permissionLevel < PERMISSION_LEVELS.ADMIN then
        self:sendSocialNotification(player, "error", "You don't have permission to modify this space")
        return
    end
    
    -- Handle permission logic here
    -- For now, this is foundation - full implementation would be in Phase 1
    self:sendSocialNotification(player, "info", "Building permission system ready for Phase 1 implementation")
end

-- Relationship management utilities
function SocialFramework:getRelationshipStatus(userId1, userId2)
    if self.playerRelationships[userId1] and self.playerRelationships[userId1][userId2] then
        return self.playerRelationships[userId1][userId2].status
    end
    return RELATIONSHIP_TYPES.NONE
end

function SocialFramework:setRelationshipStatus(userId1, userId2, status)
    if not self.playerRelationships[userId1] then
        self.playerRelationships[userId1] = {}
    end
    
    if not self.playerRelationships[userId1][userId2] then
        self.playerRelationships[userId1][userId2] = {}
    end
    
    self.playerRelationships[userId1][userId2].status = status
    self.playerRelationships[userId1][userId2].lastUpdated = tick()
end

function SocialFramework:setFriendshipData(userId1, userId2, friendshipData)
    if not self.playerRelationships[userId1] then
        self.playerRelationships[userId1] = {}
    end
    
    if not self.playerRelationships[userId1][userId2] then
        self.playerRelationships[userId1][userId2] = {}
    end
    
    self.playerRelationships[userId1][userId2].friendshipData = friendshipData
end

function SocialFramework:areFriends(userId1, userId2)
    return self:getRelationshipStatus(userId1, userId2) == RELATIONSHIP_TYPES.FRIENDS
end

function SocialFramework:updateFriendshipInteraction(userId1, userId2, interactionType, data)
    if not self:areFriends(userId1, userId2) then return end
    
    local friendshipData1 = self.playerRelationships[userId1][userId2].friendshipData
    local friendshipData2 = self.playerRelationships[userId2][userId1].friendshipData
    
    if friendshipData1 then
        friendshipData1.lastInteraction = tick()
        if interactionType == "resource_shared" then
            friendshipData1.sharedResources = (friendshipData1.sharedResources or 0) + (data.amount or 0)
        end
    end
    
    if friendshipData2 then
        friendshipData2.lastInteraction = tick()
        if interactionType == "resource_shared" then
            friendshipData2.sharedResources = (friendshipData2.sharedResources or 0) + (data.amount or 0)
        end
    end
end

-- Utility functions
function SocialFramework:findPlayerByName(playerName)
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == playerName:lower() then
            return player
        end
    end
    return nil
end

function SocialFramework:notifyFriendsOnlineStatus(userId, isOnline)
    local relationships = self.playerRelationships[userId] or {}
    
    for friendId, relationshipData in pairs(relationships) do
        if relationshipData.status == RELATIONSHIP_TYPES.FRIENDS then
            local friendPlayer = Players:GetPlayerByUserId(friendId)
            if friendPlayer then
                local playerName = "Friend"
                if isOnline then
                    local player = Players:GetPlayerByUserId(userId)
                    playerName = player and player.Name or "Friend"
                end
                
                self:sendSocialNotification(friendPlayer, "friend_status", 
                    playerName .. (isOnline and " came online" or " went offline"))
            end
        end
    end
end

function SocialFramework:sendSocialNotification(player, notificationType, message, data)
    -- Send notification to client
    -- This would connect to a notification system
    print(string.format("📢 Social notification to %s [%s]: %s", player.Name, notificationType, message))
    
    -- For now, just print - in full implementation would fire client events
end

function SocialFramework:loadCollaborativeSpace(spaceId)
    spawn(function()
        local success, spaceData = pcall(function()
            return CollaborativeSpacesStore:GetAsync("space_" .. spaceId)
        end)
        
        if success and spaceData then
            self.collaborativeSpaces[spaceId] = spaceData
        end
    end)
end

function SocialFramework:saveCollaborativeSpace(spaceId)
    spawn(function()
        local spaceData = self.collaborativeSpaces[spaceId]
        if spaceData then
            local success, error = pcall(function()
                CollaborativeSpacesStore:SetAsync("space_" .. spaceId, spaceData)
            end)
            
            if not success then
                warn("Failed to save collaborative space " .. spaceId .. ":", error)
            end
        end
    end)
end

function SocialFramework:startSocialMaintenance()
    -- Periodic cleanup and maintenance
    spawn(function()
        while true do
            wait(300) -- Every 5 minutes
            
            -- Clean up old friend requests (older than 7 days)
            local currentTime = tick()
            for userId, requests in pairs(self.friendRequests) do
                for requestId, requestData in pairs(requests) do
                    if currentTime - requestData.timestamp > 604800 then -- 7 days
                        requests[requestId] = nil
                    end
                end
            end
            
            -- Save all player social data
            for userId, _ in pairs(self.playerRelationships) do
                if self.onlinePlayerTracking[userId] then
                    self:savePlayerSocialData(userId)
                end
            end
        end
    end)
end

-- Public API for other systems
function SocialFramework:GetPlayerFriends(userId)
    local friends = {}
    local relationships = self.playerRelationships[userId] or {}
    
    for friendId, relationshipData in pairs(relationships) do
        if relationshipData.status == RELATIONSHIP_TYPES.FRIENDS then
            table.insert(friends, {
                userId = friendId,
                friendshipData = relationshipData.friendshipData or {},
                isOnline = self.onlinePlayerTracking[friendId] ~= nil
            })
        end
    end
    
    return friends
end

function SocialFramework:GetCollaborativeSpaces(userId)
    local userSpaces = {}
    
    for spaceId, spaceData in pairs(self.collaborativeSpaces) do
        if spaceData.participants[userId] then
            table.insert(userSpaces, {
                id = spaceId,
                name = spaceData.name,
                type = spaceData.type,
                permissionLevel = spaceData.participants[userId].permissionLevel,
                participantCount = 0 -- Would count participants
            })
        end
    end
    
    return userSpaces
end

function SocialFramework:CanPlayerInteract(userId1, userId2, interactionType)
    if interactionType == "friend_request" then
        return self:getRelationshipStatus(userId1, userId2) == RELATIONSHIP_TYPES.NONE
    elseif interactionType == "resource_share" then
        return self:areFriends(userId1, userId2)
    elseif interactionType == "collaborative_build" then
        return self:areFriends(userId1, userId2) -- Phase 1 will have more complex logic
    end
    
    return false
end

return SocialFramework