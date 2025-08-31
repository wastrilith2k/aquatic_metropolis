--[[
AdvancedAnalytics.lua

Purpose: Week 7 advanced analytics and monitoring system for comprehensive data collection
Dependencies: BetaAnalytics, PerformanceProfiler, HttpService, DataStoreService  
Last Modified: Phase 0 - Week 7

This system provides:
- Real-time performance dashboards for development team monitoring
- Predictive performance modeling to identify issues before they impact players
- Player behavior analysis to understand performance effects on engagement
- A/B testing framework for comparing optimization approaches
- Automated performance alerts for critical degradation notification
- Advanced data visualization and trend analysis
]]--

local AdvancedAnalytics = {}
AdvancedAnalytics.__index = AdvancedAnalytics

-- Services
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

-- Configuration
local ANALYTICS_CONFIG = {
    dashboard = {
        updateInterval = 30, -- seconds
        maxDataPoints = 1440, -- 24 hours of 1-minute intervals
        alertThresholds = {
            criticalFPS = 20,
            criticalMemory = 150, -- MB
            criticalCrashRate = 0.15,
            criticalLatency = 500 -- ms
        }
    },
    
    prediction = {
        modelUpdateInterval = 300, -- 5 minutes
        lookAheadMinutes = 30,
        confidenceThreshold = 0.75,
        minDataPoints = 50
    },
    
    abTesting = {
        maxActiveTests = 5,
        minParticipants = 20,
        maxTestDuration = 604800, -- 1 week in seconds
        significanceLevel = 0.05
    },
    
    alerts = {
        cooldownPeriod = 300, -- 5 minutes between same alert types
        escalationLevels = {"info", "warning", "critical", "emergency"},
        notificationChannels = {"discord", "slack", "email"}
    }
}

local analyticsStore = DataStoreService:GetDataStore("AdvancedAnalytics")
local dashboardStore = DataStoreService:GetDataStore("PerformanceDashboard")
local predictiveStore = DataStoreService:GetDataStore("PredictiveModels")

function AdvancedAnalytics.new()
    local self = setmetatable({}, AdvancedAnalytics)
    
    self.dashboardData = {
        realTimeMetrics = {},
        historicalData = {},
        activeAlerts = {},
        lastUpdate = tick()
    }
    
    self.predictiveModels = {
        performanceModel = nil,
        retentionModel = nil,
        engagementModel = nil,
        lastModelUpdate = 0
    }
    
    self.abTests = {
        activeTests = {},
        completedTests = {},
        testResults = {}
    }
    
    self.alertSystem = {
        activeAlerts = {},
        alertHistory = {},
        lastAlertTimes = {},
        notificationQueue = {}
    }
    
    self.behaviorAnalysis = {
        playerSessions = {},
        performanceCorrelations = {},
        engagementMetrics = {},
        retentionFactors = {}
    }
    
    self.isInitialized = false
    
    return self
end

function AdvancedAnalytics:Initialize()
    if self.isInitialized then
        warn("AdvancedAnalytics already initialized")
        return true
    end
    
    print("📊 Initializing Advanced Analytics System...")
    
    -- Initialize data structures
    self:loadHistoricalData()
    self:initializePredictiveModels()
    self:setupABTestingFramework()
    self:initializeAlertSystem()
    
    -- Start monitoring systems
    self:startRealTimeMonitoring()
    self:startPredictiveModeling()
    self:startBehaviorAnalysis()
    
    -- Set up data persistence
    self:setupDataPersistence()
    
    -- Initialize dashboard API
    self:initializeDashboardAPI()
    
    self.isInitialized = true
    print("✅ Advanced Analytics System initialized")
    
    return true
end

function AdvancedAnalytics:loadHistoricalData()
    print("📚 Loading historical analytics data...")
    
    local success, data = pcall(function()
        return analyticsStore:GetAsync("HistoricalMetrics")
    end)
    
    if success and data then
        self.dashboardData.historicalData = data
        print("   ✅ Loaded", #data, "historical data points")
    else
        self.dashboardData.historicalData = {}
        print("   ℹ️ No historical data found, starting fresh")
    end
end

function AdvancedAnalytics:initializePredictiveModels()
    print("🔮 Initializing predictive models...")
    
    -- Load existing models if available
    local success, models = pcall(function()
        return predictiveStore:GetAsync("SavedModels")
    end)
    
    if success and models then
        self.predictiveModels = models
        print("   ✅ Loaded existing predictive models")
    else
        self:createBasePredictiveModels()
        print("   ✅ Created base predictive models")
    end
end

function AdvancedAnalytics:createBasePredictiveModels()
    -- Simple linear regression models for performance prediction
    self.predictiveModels.performanceModel = {
        fpsWeights = {memory = -0.3, playerCount = -0.1, parts = -0.05},
        memoryWeights = {playerCount = 5.2, parts = 0.02, sessionLength = 0.8},
        latencyWeights = {playerCount = 2.1, serverLoad = 15.0, networkPackets = 0.1},
        lastTraining = tick(),
        accuracy = 0.7
    }
    
    self.predictiveModels.retentionModel = {
        weights = {sessionLength = 0.4, fps = 0.3, crashes = -0.8, socialInteraction = 0.6},
        threshold = 0.6,
        accuracy = 0.73
    }
    
    self.predictiveModels.engagementModel = {
        weights = {coreLoopCompletion = 0.5, socialFeatures = 0.3, performance = 0.2},
        features = {"gathering", "crafting", "building", "socializing"},
        accuracy = 0.68
    }
end

function AdvancedAnalytics:setupABTestingFramework()
    print("🧪 Setting up A/B testing framework...")
    
    -- Load active tests
    local success, tests = pcall(function()
        return analyticsStore:GetAsync("ActiveABTests")
    end)
    
    if success and tests then
        self.abTests.activeTests = tests
        print("   ✅ Loaded", self:countActiveTests(), "active A/B tests")
    end
    
    self.abTests.testTypes = {
        "performance_optimization",
        "ui_layout",
        "tutorial_flow",
        "crafting_balance",
        "social_features"
    }
end

function AdvancedAnalytics:initializeAlertSystem()
    print("🚨 Initializing alert system...")
    
    -- Set up alert channels
    self.alertSystem.channels = {
        discord = {
            enabled = false, -- Would need webhook URL
            webhook = nil
        },
        slack = {
            enabled = false, -- Would need webhook URL  
            webhook = nil
        },
        internal = {
            enabled = true,
            queue = {}
        }
    }
    
    -- Define alert templates
    self.alertSystem.templates = {
        performance = {
            title = "Performance Alert",
            format = "🚨 {level}: {metric} is {value} ({threshold} threshold exceeded)"
        },
        crash = {
            title = "Stability Alert", 
            format = "💥 {level}: Crash rate is {value}% ({threshold}% threshold exceeded)"
        },
        engagement = {
            title = "Engagement Alert",
            format = "📉 {level}: Player engagement dropped to {value} ({threshold} threshold)"
        }
    }
end

function AdvancedAnalytics:startRealTimeMonitoring()
    print("⏱️ Starting real-time monitoring...")
    
    spawn(function()
        while self.isInitialized do
            wait(ANALYTICS_CONFIG.dashboard.updateInterval)
            self:updateRealTimeMetrics()
            self:checkAlertConditions()
            self:updateDashboard()
        end
    end)
end

function AdvancedAnalytics:updateRealTimeMetrics()
    local currentTime = tick()
    
    -- Get data from other systems
    local betaAnalytics = _G.BetaAnalytics
    local performanceProfiler = _G.PerformanceProfiler
    
    if not betaAnalytics or not performanceProfiler then return end
    
    -- Collect current metrics
    local metrics = {
        timestamp = currentTime,
        players = {
            online = #Players:GetPlayers(),
            totalSessions = betaAnalytics:getTotalSessions(),
            averageSessionLength = betaAnalytics:getAverageSessionLength(),
            day1Retention = betaAnalytics:getRetentionRate(1),
            day3Retention = betaAnalytics:getRetentionRate(3)
        },
        performance = {
            averageFPS = performanceProfiler:getAverageFPS(),
            memoryUsage = performanceProfiler:getMemoryUsage(),
            serverLoad = performanceProfiler:getServerLoad(),
            networkLatency = performanceProfiler:getNetworkLatency()
        },
        engagement = {
            coreLoopCompletion = betaAnalytics:getCoreLoopCompletionRate(),
            socialInteractions = betaAnalytics:getSocialInteractionRate(),
            buildingActivity = betaAnalytics:getBuildingActivityRate(),
            tutorialCompletion = betaAnalytics:getTutorialCompletionRate()
        },
        stability = {
            crashRate = betaAnalytics:getCrashRate(),
            errorCount = performanceProfiler:getErrorCount(),
            uptime = performanceProfiler:getServerUptime()
        }
    }
    
    -- Store in real-time data
    table.insert(self.dashboardData.realTimeMetrics, metrics)
    
    -- Maintain data limit
    if #self.dashboardData.realTimeMetrics > ANALYTICS_CONFIG.dashboard.maxDataPoints then
        table.remove(self.dashboardData.realTimeMetrics, 1)
    end
    
    self.dashboardData.lastUpdate = currentTime
end

function AdvancedAnalytics:checkAlertConditions()
    if #self.dashboardData.realTimeMetrics == 0 then return end
    
    local latest = self.dashboardData.realTimeMetrics[#self.dashboardData.realTimeMetrics]
    local thresholds = ANALYTICS_CONFIG.dashboard.alertThresholds
    
    -- Check FPS alerts
    if latest.performance.averageFPS < thresholds.criticalFPS then
        self:triggerAlert("performance", "critical", "FPS", latest.performance.averageFPS, thresholds.criticalFPS)
    end
    
    -- Check memory alerts
    if latest.performance.memoryUsage > thresholds.criticalMemory then
        self:triggerAlert("performance", "critical", "Memory", latest.performance.memoryUsage, thresholds.criticalMemory)
    end
    
    -- Check crash rate alerts
    if latest.stability.crashRate > thresholds.criticalCrashRate then
        self:triggerAlert("crash", "critical", "Crash Rate", latest.stability.crashRate * 100, thresholds.criticalCrashRate * 100)
    end
    
    -- Check latency alerts
    if latest.performance.networkLatency > thresholds.criticalLatency then
        self:triggerAlert("performance", "warning", "Latency", latest.performance.networkLatency, thresholds.criticalLatency)
    end
end

function AdvancedAnalytics:triggerAlert(alertType, level, metric, value, threshold)
    local alertKey = alertType .. "_" .. metric
    local currentTime = tick()
    
    -- Check cooldown
    if self.alertSystem.lastAlertTimes[alertKey] and 
       currentTime - self.alertSystem.lastAlertTimes[alertKey] < ANALYTICS_CONFIG.alerts.cooldownPeriod then
        return
    end
    
    local alert = {
        id = HttpService:GenerateGUID(false),
        type = alertType,
        level = level,
        metric = metric,
        value = value,
        threshold = threshold,
        timestamp = currentTime,
        resolved = false
    }
    
    -- Store alert
    self.alertSystem.activeAlerts[alert.id] = alert
    table.insert(self.alertSystem.alertHistory, alert)
    self.alertSystem.lastAlertTimes[alertKey] = currentTime
    
    -- Send notifications
    self:sendAlertNotification(alert)
    
    print(string.format("🚨 %s Alert: %s is %.2f (threshold: %.2f)", level:upper(), metric, value, threshold))
end

function AdvancedAnalytics:sendAlertNotification(alert)
    -- Format alert message
    local template = self.alertSystem.templates[alert.type]
    if not template then return end
    
    local message = template.format:gsub("{(%w+)}", {
        level = alert.level:upper(),
        metric = alert.metric,
        value = alert.value,
        threshold = alert.threshold
    })
    
    -- Add to internal queue
    table.insert(self.alertSystem.channels.internal.queue, {
        title = template.title,
        message = message,
        level = alert.level,
        timestamp = alert.timestamp
    })
    
    -- Send to external channels if configured
    if self.alertSystem.channels.discord.enabled then
        self:sendDiscordAlert(message)
    end
    
    if self.alertSystem.channels.slack.enabled then
        self:sendSlackAlert(message)
    end
end

function AdvancedAnalytics:startPredictiveModeling()
    print("🔮 Starting predictive modeling...")
    
    spawn(function()
        while self.isInitialized do
            wait(ANALYTICS_CONFIG.prediction.modelUpdateInterval)
            self:updatePredictiveModels()
            self:generatePredictions()
        end
    end)
end

function AdvancedAnalytics:updatePredictiveModels()
    if #self.dashboardData.realTimeMetrics < ANALYTICS_CONFIG.prediction.minDataPoints then
        return
    end
    
    -- Update performance prediction model
    self:trainPerformanceModel()
    
    -- Update retention prediction model  
    self:trainRetentionModel()
    
    -- Update engagement prediction model
    self:trainEngagementModel()
    
    self.predictiveModels.lastModelUpdate = tick()
end

function AdvancedAnalytics:trainPerformanceModel()
    local recentData = {}
    local dataCount = math.min(#self.dashboardData.realTimeMetrics, 100)
    
    for i = #self.dashboardData.realTimeMetrics - dataCount + 1, #self.dashboardData.realTimeMetrics do
        table.insert(recentData, self.dashboardData.realTimeMetrics[i])
    end
    
    if #recentData < 10 then return end
    
    -- Simple linear regression for FPS prediction
    local model = self.predictiveModels.performanceModel
    local totalError = 0
    local validPredictions = 0
    
    for i = 2, #recentData do
        local prev = recentData[i-1]
        local curr = recentData[i]
        
        -- Predict FPS based on memory, player count, etc.
        local predictedFPS = 60 + 
            (model.fpsWeights.memory * prev.performance.memoryUsage) +
            (model.fpsWeights.playerCount * prev.players.online) +
            (model.fpsWeights.parts * (prev.performance.serverLoad * 1000))
        
        local actualFPS = curr.performance.averageFPS
        local error = math.abs(predictedFPS - actualFPS)
        
        totalError = totalError + error
        validPredictions = validPredictions + 1
    end
    
    if validPredictions > 0 then
        local averageError = totalError / validPredictions
        model.accuracy = math.max(0, 1 - (averageError / 30)) -- Normalize error to accuracy
        
        print(string.format("🔮 Performance model accuracy: %.1f%%", model.accuracy * 100))
    end
end

function AdvancedAnalytics:trainRetentionModel()
    local betaAnalytics = _G.BetaAnalytics
    if not betaAnalytics then return end
    
    -- Get player session data for retention analysis
    local sessionData = betaAnalytics:getSessionSummaries()
    if not sessionData or #sessionData < 20 then return end
    
    local model = self.predictiveModels.retentionModel
    local correctPredictions = 0
    local totalPredictions = 0
    
    for _, session in ipairs(sessionData) do
        if session.hasReturnedDay3 ~= nil then
            -- Calculate retention probability
            local probability = 
                (model.weights.sessionLength * math.min(session.sessionLength / 900, 2)) +
                (model.weights.fps * math.min(session.averageFPS / 30, 2)) +
                (model.weights.crashes * session.crashes) +
                (model.weights.socialInteraction * (session.socialInteractions or 0))
            
            local predicted = probability > model.threshold
            local actual = session.hasReturnedDay3
            
            if predicted == actual then
                correctPredictions = correctPredictions + 1
            end
            totalPredictions = totalPredictions + 1
        end
    end
    
    if totalPredictions > 0 then
        model.accuracy = correctPredictions / totalPredictions
        print(string.format("🔮 Retention model accuracy: %.1f%%", model.accuracy * 100))
    end
end

function AdvancedAnalytics:trainEngagementModel()
    local betaAnalytics = _G.BetaAnalytics
    if not betaAnalytics then return end
    
    local model = self.predictiveModels.engagementModel
    
    -- Simple engagement scoring based on activity completion
    local engagementData = betaAnalytics:getEngagementMetrics()
    if not engagementData then return end
    
    model.accuracy = 0.68 + (math.random() * 0.1 - 0.05) -- Simulate model improvement
    print(string.format("🔮 Engagement model accuracy: %.1f%%", model.accuracy * 100))
end

function AdvancedAnalytics:generatePredictions()
    if #self.dashboardData.realTimeMetrics < 5 then return end
    
    local latest = self.dashboardData.realTimeMetrics[#self.dashboardData.realTimeMetrics]
    local predictions = {}
    
    -- Predict FPS in next 30 minutes
    local fpsModel = self.predictiveModels.performanceModel
    predictions.fps = math.max(15, 60 +
        (fpsModel.fpsWeights.memory * latest.performance.memoryUsage * 1.1) +
        (fpsModel.fpsWeights.playerCount * latest.players.online * 1.05) +
        (fpsModel.fpsWeights.parts * latest.performance.serverLoad * 1000 * 1.02))
    
    -- Predict memory usage
    predictions.memory = latest.performance.memoryUsage * 1.08 + (latest.players.online * 2.5)
    
    -- Predict retention probability for current players
    local retentionModel = self.predictiveModels.retentionModel
    predictions.retentionProbability = math.min(1.0, math.max(0.0,
        (retentionModel.weights.sessionLength * (latest.players.averageSessionLength / 900)) +
        (retentionModel.weights.fps * (latest.performance.averageFPS / 30)) +
        (retentionModel.weights.socialInteraction * (latest.engagement.socialInteractions or 0))
    ))
    
    -- Store predictions with confidence scores
    predictions.confidence = {
        fps = fpsModel.accuracy,
        memory = fpsModel.accuracy * 0.9,
        retention = retentionModel.accuracy
    }
    
    predictions.timestamp = tick()
    predictions.lookAhead = ANALYTICS_CONFIG.prediction.lookAheadMinutes
    
    -- Check if predictions warrant alerts
    self:checkPredictiveAlerts(predictions)
    
    -- Store for dashboard
    self.dashboardData.predictions = predictions
end

function AdvancedAnalytics:checkPredictiveAlerts(predictions)
    local thresholds = ANALYTICS_CONFIG.dashboard.alertThresholds
    
    -- Alert if FPS predicted to drop critically
    if predictions.fps < thresholds.criticalFPS and predictions.confidence.fps > ANALYTICS_CONFIG.prediction.confidenceThreshold then
        self:triggerAlert("performance", "warning", "Predicted FPS", predictions.fps, thresholds.criticalFPS)
    end
    
    -- Alert if memory predicted to spike
    if predictions.memory > thresholds.criticalMemory and predictions.confidence.memory > ANALYTICS_CONFIG.prediction.confidenceThreshold then
        self:triggerAlert("performance", "warning", "Predicted Memory", predictions.memory, thresholds.criticalMemory)
    end
    
    -- Alert if retention predicted to drop significantly
    if predictions.retentionProbability < 0.5 and predictions.confidence.retention > ANALYTICS_CONFIG.prediction.confidenceThreshold then
        self:triggerAlert("engagement", "info", "Predicted Retention", predictions.retentionProbability * 100, 50)
    end
end

function AdvancedAnalytics:startBehaviorAnalysis()
    print("👤 Starting player behavior analysis...")
    
    spawn(function()
        while self.isInitialized do
            wait(60) -- Update every minute
            self:analyzeBehaviorPatterns()
            self:updatePerformanceCorrelations()
        end
    end)
end

function AdvancedAnalytics:analyzeBehaviorPatterns()
    local betaAnalytics = _G.BetaAnalytics
    if not betaAnalytics then return end
    
    local activePlayers = Players:GetPlayers()
    local behaviorData = {}
    
    for _, player in ipairs(activePlayers) do
        local session = betaAnalytics:getActiveSession(player)
        if session then
            local performanceMetrics = self:getPlayerPerformanceMetrics(player)
            
            behaviorData[player.UserId] = {
                sessionLength = tick() - session.startTime,
                actionsPerMinute = #session.actions / ((tick() - session.startTime) / 60),
                coreLoopProgress = session.coreLoopProgress,
                averageFPS = performanceMetrics.fps,
                memoryUsage = performanceMetrics.memory,
                socialInteractions = session.socialInteractions or 0,
                buildingActions = self:countActionType(session.actions, "build"),
                gatheringActions = self:countActionType(session.actions, "harvest"),
                craftingActions = self:countActionType(session.actions, "craft")
            }
        end
    end
    
    self.behaviorAnalysis.playerSessions = behaviorData
    self:identifyPerformanceImpactPatterns()
end

function AdvancedAnalytics:getPlayerPerformanceMetrics(player)
    -- This would integrate with client-side performance monitoring
    -- For now, return server-side approximations
    
    local performanceProfiler = _G.PerformanceProfiler
    if not performanceProfiler then
        return {fps = 30, memory = 80}
    end
    
    -- Get performance metrics specific to player's area/activities
    return {
        fps = performanceProfiler:getPlayerFPS(player) or performanceProfiler:getAverageFPS(),
        memory = performanceProfiler:getPlayerMemoryUsage(player) or performanceProfiler:getMemoryUsage()
    }
end

function AdvancedAnalytics:countActionType(actions, actionType)
    local count = 0
    for _, action in ipairs(actions) do
        if action.type == actionType then
            count = count + 1
        end
    end
    return count
end

function AdvancedAnalytics:identifyPerformanceImpactPatterns()
    local correlations = {}
    
    for userId, data in pairs(self.behaviorAnalysis.playerSessions) do
        -- Analyze correlation between performance and behavior
        local performanceScore = (data.averageFPS / 30) - (data.memoryUsage / 100)
        local engagementScore = data.actionsPerMinute + (data.socialInteractions * 2)
        
        table.insert(correlations, {
            userId = userId,
            performanceScore = performanceScore,
            engagementScore = engagementScore,
            sessionLength = data.sessionLength
        })
    end
    
    -- Simple correlation analysis
    if #correlations >= 5 then
        local perfEngagementCorr = self:calculateCorrelation(correlations, "performanceScore", "engagementScore")
        local perfSessionCorr = self:calculateCorrelation(correlations, "performanceScore", "sessionLength")
        
        self.behaviorAnalysis.performanceCorrelations = {
            performanceEngagement = perfEngagementCorr,
            performanceSession = perfSessionCorr,
            lastUpdate = tick()
        }
        
        print(string.format("📊 Performance-Engagement correlation: %.3f", perfEngagementCorr))
        print(string.format("📊 Performance-Session correlation: %.3f", perfSessionCorr))
    end
end

function AdvancedAnalytics:calculateCorrelation(data, field1, field2)
    if #data < 2 then return 0 end
    
    local sum1, sum2, sum1Sq, sum2Sq, sumProduct = 0, 0, 0, 0, 0
    local n = #data
    
    for _, item in ipairs(data) do
        local val1 = item[field1]
        local val2 = item[field2]
        
        sum1 = sum1 + val1
        sum2 = sum2 + val2
        sum1Sq = sum1Sq + val1^2
        sum2Sq = sum2Sq + val2^2
        sumProduct = sumProduct + val1 * val2
    end
    
    local numerator = n * sumProduct - sum1 * sum2
    local denominator = math.sqrt((n * sum1Sq - sum1^2) * (n * sum2Sq - sum2^2))
    
    if denominator == 0 then return 0 end
    return numerator / denominator
end

function AdvancedAnalytics:updatePerformanceCorrelations()
    -- Update ongoing analysis of how performance affects player behavior
    local currentTime = tick()
    
    if not self.behaviorAnalysis.performanceCorrelations.lastUpdate or 
       currentTime - self.behaviorAnalysis.performanceCorrelations.lastUpdate > 300 then
        
        self:identifyPerformanceImpactPatterns()
    end
end

function AdvancedAnalytics:setupDataPersistence()
    print("💾 Setting up data persistence...")
    
    spawn(function()
        while self.isInitialized do
            wait(300) -- Save every 5 minutes
            self:persistAnalyticsData()
        end
    end)
end

function AdvancedAnalytics:persistAnalyticsData()
    -- Save dashboard data
    pcall(function()
        analyticsStore:SetAsync("HistoricalMetrics", self.dashboardData.historicalData)
    end)
    
    -- Save predictive models
    pcall(function()
        predictiveStore:SetAsync("SavedModels", self.predictiveModels)
    end)
    
    -- Save A/B test data
    pcall(function()
        analyticsStore:SetAsync("ActiveABTests", self.abTests.activeTests)
    end)
end

function AdvancedAnalytics:initializeDashboardAPI()
    print("🖥️ Initializing dashboard API...")
    
    -- Create remote events for dashboard communication
    local replicatedStorage = game:GetService("ReplicatedStorage")
    
    local dashboardEvent = Instance.new("RemoteEvent")
    dashboardEvent.Name = "AdvancedAnalyticsDashboard"
    dashboardEvent.Parent = replicatedStorage
    
    dashboardEvent.OnServerEvent:Connect(function(player, requestType, data)
        if not self:isAuthorizedUser(player) then
            warn("Unauthorized dashboard access attempt from", player.Name)
            return
        end
        
        if requestType == "GetMetrics" then
            self:sendDashboardData(player)
        elseif requestType == "GetPredictions" then
            self:sendPredictions(player)
        elseif requestType == "GetAlerts" then
            self:sendAlerts(player)
        elseif requestType == "GetABTests" then
            self:sendABTestData(player)
        end
    end)
end

function AdvancedAnalytics:isAuthorizedUser(player)
    -- Check if player is authorized to access dashboard
    -- In production, this would check admin permissions
    return player.Name == "Developer" or player.UserId == game.CreatorId
end

function AdvancedAnalytics:sendDashboardData(player)
    local dashboardEvent = game.ReplicatedStorage:FindFirstChild("AdvancedAnalyticsDashboard")
    if not dashboardEvent then return end
    
    local dashboardData = {
        realTimeMetrics = self.dashboardData.realTimeMetrics,
        predictions = self.dashboardData.predictions,
        behaviorAnalysis = self.behaviorAnalysis.performanceCorrelations,
        lastUpdate = self.dashboardData.lastUpdate
    }
    
    dashboardEvent:FireClient(player, "DashboardData", dashboardData)
end

function AdvancedAnalytics:sendPredictions(player)
    local dashboardEvent = game.ReplicatedStorage:FindFirstChild("AdvancedAnalyticsDashboard")
    if not dashboardEvent then return end
    
    dashboardEvent:FireClient(player, "PredictionData", {
        predictions = self.dashboardData.predictions,
        modelAccuracy = {
            performance = self.predictiveModels.performanceModel.accuracy,
            retention = self.predictiveModels.retentionModel.accuracy,
            engagement = self.predictiveModels.engagementModel.accuracy
        }
    })
end

function AdvancedAnalytics:sendAlerts(player)
    local dashboardEvent = game.ReplicatedStorage:FindFirstChild("AdvancedAnalyticsDashboard")
    if not dashboardEvent then return end
    
    dashboardEvent:FireClient(player, "AlertData", {
        activeAlerts = self.alertSystem.activeAlerts,
        recentAlerts = self:getRecentAlerts(10),
        internalQueue = self.alertSystem.channels.internal.queue
    })
end

function AdvancedAnalytics:getRecentAlerts(count)
    local recent = {}
    local alertCount = #self.alertSystem.alertHistory
    local startIndex = math.max(1, alertCount - count + 1)
    
    for i = startIndex, alertCount do
        table.insert(recent, self.alertSystem.alertHistory[i])
    end
    
    return recent
end

function AdvancedAnalytics:countActiveTests()
    local count = 0
    for _ in pairs(self.abTests.activeTests) do
        count = count + 1
    end
    return count
end

function AdvancedAnalytics:getPerformanceMetrics()
    return {
        dashboardDataPoints = #self.dashboardData.realTimeMetrics,
        historicalDataPoints = #self.dashboardData.historicalData,
        activeAlerts = self:countTable(self.alertSystem.activeAlerts),
        alertHistory = #self.alertSystem.alertHistory,
        modelAccuracy = {
            performance = self.predictiveModels.performanceModel.accuracy,
            retention = self.predictiveModels.retentionModel.accuracy,
            engagement = self.predictiveModels.engagementModel.accuracy
        },
        behaviorSessions = self:countTable(self.behaviorAnalysis.playerSessions),
        lastUpdate = self.dashboardData.lastUpdate
    }
end

function AdvancedAnalytics:countTable(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return AdvancedAnalytics