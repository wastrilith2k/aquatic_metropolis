--[[
GateEvaluation.lua

Purpose: Week 8 Gate Decision evaluation system for Phase C compliance
Dependencies: BetaAnalytics, DataStoreService
Last Modified: Phase 0 - Week 5
Performance Notes: Comprehensive evaluation framework for beta progression

Critical System: Automated Week 8 Gate Decision Framework

Features:
- Automated threshold evaluation against Phase C requirements
- Real-time metrics dashboard for development monitoring
- Decision matrix implementation with pass/fail/iterate logic
- Comprehensive report generation for stakeholder review
- Data export capabilities for external analysis
- Historical trend analysis and projection capabilities
]]--

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Data storage
local GateEvaluationStore = DataStoreService:GetDataStore("GateEvaluation_v1")
local ReportsStore = DataStoreService:GetDataStore("GateReports_v1")

local GateEvaluation = {}
GateEvaluation.__index = GateEvaluation

-- Phase C Gate Decision Criteria (From Phase C Documents)
local GATE_CRITERIA = {
    -- Quantitative Metrics (70% weight)
    quantitative = {
        sessionLength = {
            name = "Average Session Length",
            target = 900, -- 15 minutes
            minimum = 720, -- 12 minutes
            weight = 0.20,
            unit = "seconds",
            description = "Average time players spend per session"
        },
        
        day3Retention = {
            name = "Day 3 Retention Rate",
            target = 0.60, -- 60%
            minimum = 0.50, -- 50%
            weight = 0.20,
            unit = "percentage",
            description = "Percentage of players who return after 3 days"
        },
        
        coreLoopCompletion = {
            name = "Core Loop Completion Rate",
            target = 0.80, -- 80%
            minimum = 0.70, -- 70%
            weight = 0.15,
            unit = "percentage", 
            description = "Players who complete gather→craft→build cycle"
        },
        
        averageFPS = {
            name = "Average Frame Rate",
            target = 30.0, -- 30 FPS
            minimum = 25.0, -- 25 FPS
            weight = 0.10,
            unit = "fps",
            description = "Server-side frame rate performance"
        },
        
        crashRate = {
            name = "Crash Rate",
            target = 0.05, -- 5%
            minimum = 0.10, -- 10% (maximum acceptable)
            weight = 0.05,
            unit = "percentage",
            description = "Percentage of sessions ending in crashes",
            inverted = true -- Lower is better
        }
    },
    
    -- Qualitative Metrics (30% weight)
    qualitative = {
        playerSatisfaction = {
            name = "Player Satisfaction Score",
            target = 7.0, -- 7/10
            minimum = 6.0, -- 6/10
            weight = 0.20,
            unit = "rating",
            description = "Average player satisfaction rating (1-10)"
        },
        
        featureEngagement = {
            name = "Feature Engagement Score",
            target = 0.75, -- 75%
            minimum = 0.60, -- 60%
            weight = 0.05,
            unit = "percentage",
            description = "Percentage of core features used by players"
        },
        
        bugSeverity = {
            name = "Bug Severity Index",
            target = 2.0, -- Low severity average
            minimum = 3.0, -- Medium severity maximum
            weight = 0.05,
            unit = "severity",
            description = "Average severity of reported bugs (1=low, 5=critical)",
            inverted = true -- Lower is better
        }
    }
}

-- Decision Matrix Thresholds
local DECISION_THRESHOLDS = {
    pass = 85, -- 85%+ overall score = immediate Phase 1 progression
    conditionalPass = 70, -- 70-84% = conditional pass with 2-week iteration
    fail = 70 -- <70% = major scope reduction or timeline extension
}

function GateEvaluation:Initialize()
    print("🎯 Initializing Gate Evaluation System...")
    
    -- Initialize evaluation state
    self.currentEvaluation = {
        timestamp = 0,
        metrics = {},
        scores = {},
        overallScore = 0,
        decision = "pending",
        recommendations = {}
    }
    
    self.historicalEvaluations = {}
    self.trendAnalysis = {}
    
    -- Load historical data
    self:loadHistoricalData()
    
    print("✅ Gate Evaluation System initialized")
    return true
end

function GateEvaluation:EvaluateGateCriteria(betaAnalytics)
    print("🔍 Performing Gate Evaluation...")
    
    local currentTime = tick()
    local analyticsStatus = betaAnalytics:GetGateEvaluationStatus()
    
    -- Get raw metrics from analytics
    local rawMetrics = analyticsStatus.metrics
    
    -- Calculate scores for each criterion
    local quantitativeScore = self:evaluateQuantitativeMetrics(rawMetrics)
    local qualitativeScore = self:evaluateQualitativeMetrics(rawMetrics)
    
    -- Calculate overall weighted score
    local overallScore = (quantitativeScore * 0.70) + (qualitativeScore * 0.30)
    
    -- Determine decision
    local decision = self:determineGateDecision(overallScore)
    
    -- Generate recommendations
    local recommendations = self:generateRecommendations(rawMetrics, overallScore)
    
    -- Create evaluation summary
    self.currentEvaluation = {
        timestamp = currentTime,
        rawMetrics = rawMetrics,
        quantitativeScore = quantitativeScore,
        qualitativeScore = qualitativeScore,
        overallScore = overallScore,
        decision = decision,
        recommendations = recommendations,
        criteriaDetails = self:generateCriteriaDetails(rawMetrics)
    }
    
    -- Store historical evaluation
    table.insert(self.historicalEvaluations, {
        timestamp = currentTime,
        score = overallScore,
        decision = decision
    })
    
    -- Update trend analysis
    self:updateTrendAnalysis()
    
    -- Save evaluation data
    self:saveEvaluationData()
    
    print(string.format("✅ Gate Evaluation Complete: %.1f%% (%s)", 
        overallScore, decision:upper()))
    
    return self.currentEvaluation
end

function GateEvaluation:evaluateQuantitativeMetrics(rawMetrics)
    local totalWeight = 0
    local weightedScore = 0
    
    for metricKey, criteria in pairs(GATE_CRITERIA.quantitative) do
        local rawValue = rawMetrics[metricKey] or 0
        local score = self:calculateMetricScore(rawValue, criteria)
        
        weightedScore = weightedScore + (score * criteria.weight)
        totalWeight = totalWeight + criteria.weight
    end
    
    return totalWeight > 0 and (weightedScore / totalWeight * 100) or 0
end

function GateEvaluation:evaluateQualitativeMetrics(rawMetrics)
    local totalWeight = 0
    local weightedScore = 0
    
    for metricKey, criteria in pairs(GATE_CRITERIA.qualitative) do
        local rawValue = rawMetrics[metricKey] or 0
        local score = self:calculateMetricScore(rawValue, criteria)
        
        weightedScore = weightedScore + (score * criteria.weight)
        totalWeight = totalWeight + criteria.weight
    end
    
    return totalWeight > 0 and (weightedScore / totalWeight * 100) or 0
end

function GateEvaluation:calculateMetricScore(rawValue, criteria)
    -- Handle inverted metrics (where lower is better)
    local value = rawValue
    local target = criteria.target
    local minimum = criteria.minimum
    
    if criteria.inverted then
        -- For inverted metrics, flip the logic
        if value <= target then
            return 100 -- Perfect score for being at or below target
        elseif value <= minimum then
            -- Linear scale between target and minimum
            local range = minimum - target
            local distance = value - target
            return math.max(0, 100 - (distance / range * 50))
        else
            return 0 -- Fail if above minimum threshold
        end
    else
        -- Normal metrics (higher is better)
        if value >= target then
            return 100 -- Perfect score for meeting or exceeding target
        elseif value >= minimum then
            -- Linear scale between minimum and target
            local range = target - minimum
            local progress = value - minimum
            return 50 + (progress / range * 50)
        else
            -- Partial credit for being below minimum
            local partialCredit = math.min(value / minimum * 50, 50)
            return math.max(0, partialCredit)
        end
    end
end

function GateEvaluation:determineGateDecision(overallScore)
    if overallScore >= DECISION_THRESHOLDS.pass then
        return "pass"
    elseif overallScore >= DECISION_THRESHOLDS.conditionalPass then
        return "conditional_pass"
    else
        return "fail"
    end
end

function GateEvaluation:generateRecommendations(rawMetrics, overallScore)
    local recommendations = {}
    
    -- Analyze each metric for specific recommendations
    for categoryName, category in pairs(GATE_CRITERIA) do
        for metricKey, criteria in pairs(category) do
            local rawValue = rawMetrics[metricKey] or 0
            local score = self:calculateMetricScore(rawValue, criteria)
            
            if score < 75 then -- Below good threshold
                local recommendation = self:getMetricRecommendation(metricKey, rawValue, criteria, score)
                if recommendation then
                    table.insert(recommendations, recommendation)
                end
            end
        end
    end
    
    -- Overall recommendations based on decision
    if overallScore >= DECISION_THRESHOLDS.pass then
        table.insert(recommendations, {
            type = "success",
            priority = "low",
            message = "All criteria met for Phase 1 progression. Focus on maintaining quality."
        })
    elseif overallScore >= DECISION_THRESHOLDS.conditionalPass then
        table.insert(recommendations, {
            type = "warning", 
            priority = "medium",
            message = "Conditional pass achieved. Implement 2-week improvement sprint before Phase 1."
        })
    else
        table.insert(recommendations, {
            type = "error",
            priority = "high", 
            message = "Gate criteria not met. Major improvements required before Phase 1 progression."
        })
    end
    
    return recommendations
end

function GateEvaluation:getMetricRecommendation(metricKey, rawValue, criteria, score)
    local recommendations = {
        sessionLength = function()
            if rawValue < criteria.minimum then
                return {
                    type = "improvement",
                    priority = "high",
                    metric = metricKey,
                    message = string.format("Session length %.1f minutes below minimum. Add engaging content or tutorial improvements.", rawValue/60),
                    actions = {"Enhance tutorial flow", "Add mid-session engagement hooks", "Improve core loop feedback"}
                }
            end
        end,
        
        day3Retention = function()
            if rawValue < criteria.minimum then
                return {
                    type = "improvement",
                    priority = "high", 
                    metric = metricKey,
                    message = string.format("Day 3 retention %.1f%% below target. Improve player onboarding and early experience.", rawValue*100),
                    actions = {"Enhance tutorial completion", "Add achievement system", "Improve new player progression"}
                }
            end
        end,
        
        coreLoopCompletion = function()
            if rawValue < criteria.minimum then
                return {
                    type = "improvement",
                    priority = "high",
                    metric = metricKey,
                    message = string.format("Core loop completion %.1f%% below target. Simplify progression or add guidance.", rawValue*100),
                    actions = {"Streamline crafting interface", "Add progression hints", "Reduce material requirements"}
                }
            end
        end,
        
        averageFPS = function()
            if rawValue < criteria.minimum then
                return {
                    type = "improvement",
                    priority = "medium",
                    metric = metricKey,
                    message = string.format("Frame rate %.1f FPS below target. Optimize performance.", rawValue),
                    actions = {"Reduce part count", "Optimize scripts", "Implement LOD system"}
                }
            end
        end,
        
        playerSatisfaction = function()
            if rawValue < criteria.minimum then
                return {
                    type = "improvement",
                    priority = "high",
                    metric = metricKey,
                    message = string.format("Player satisfaction %.1f/10 below target. Address player feedback.", rawValue),
                    actions = {"Review feedback themes", "Fix reported issues", "Improve user experience"}
                }
            end
        end
    }
    
    local recommendationFunc = recommendations[metricKey]
    return recommendationFunc and recommendationFunc() or nil
end

function GateEvaluation:generateCriteriaDetails(rawMetrics)
    local details = {}
    
    for categoryName, category in pairs(GATE_CRITERIA) do
        details[categoryName] = {}
        
        for metricKey, criteria in pairs(category) do
            local rawValue = rawMetrics[metricKey] or 0
            local score = self:calculateMetricScore(rawValue, criteria)
            
            details[categoryName][metricKey] = {
                name = criteria.name,
                current = rawValue,
                target = criteria.target,
                minimum = criteria.minimum,
                score = score,
                weight = criteria.weight,
                unit = criteria.unit,
                description = criteria.description,
                status = self:getMetricStatus(score)
            }
        end
    end
    
    return details
end

function GateEvaluation:getMetricStatus(score)
    if score >= 85 then
        return "excellent"
    elseif score >= 75 then
        return "good"
    elseif score >= 50 then
        return "passing"
    else
        return "failing"
    end
end

function GateEvaluation:updateTrendAnalysis()
    if #self.historicalEvaluations < 2 then return end
    
    local recentEvaluations = {}
    local currentTime = tick()
    
    -- Get evaluations from last 7 days
    for _, evaluation in ipairs(self.historicalEvaluations) do
        if currentTime - evaluation.timestamp <= 604800 then -- 7 days
            table.insert(recentEvaluations, evaluation)
        end
    end
    
    if #recentEvaluations < 2 then return end
    
    -- Calculate trend
    local firstScore = recentEvaluations[1].score
    local lastScore = recentEvaluations[#recentEvaluations].score
    local trendDirection = lastScore > firstScore and "improving" or 
                          (lastScore < firstScore and "declining" or "stable")
    
    local trendMagnitude = math.abs(lastScore - firstScore)
    
    self.trendAnalysis = {
        direction = trendDirection,
        magnitude = trendMagnitude,
        weeklyChange = lastScore - firstScore,
        dataPoints = #recentEvaluations,
        confidence = #recentEvaluations >= 7 and "high" or "medium"
    }
end

function GateEvaluation:generateComprehensiveReport()
    local report = {
        -- Executive Summary
        executiveSummary = {
            overallScore = self.currentEvaluation.overallScore,
            decision = self.currentEvaluation.decision,
            timestamp = self.currentEvaluation.timestamp,
            trend = self.trendAnalysis.direction or "unknown"
        },
        
        -- Detailed Metrics
        metrics = self.currentEvaluation.criteriaDetails,
        
        -- Recommendations
        recommendations = self.currentEvaluation.recommendations,
        
        -- Historical Context
        historicalData = {
            evaluations = self.historicalEvaluations,
            trends = self.trendAnalysis
        },
        
        -- Decision Matrix
        decisionMatrix = {
            thresholds = DECISION_THRESHOLDS,
            currentPosition = self.currentEvaluation.overallScore,
            nextMilestone = self:getNextMilestone()
        }
    }
    
    return report
end

function GateEvaluation:getNextMilestone()
    local score = self.currentEvaluation.overallScore
    
    if score < DECISION_THRESHOLDS.conditionalPass then
        return {
            target = DECISION_THRESHOLDS.conditionalPass,
            gap = DECISION_THRESHOLDS.conditionalPass - score,
            description = "Conditional Pass Threshold"
        }
    elseif score < DECISION_THRESHOLDS.pass then
        return {
            target = DECISION_THRESHOLDS.pass,
            gap = DECISION_THRESHOLDS.pass - score,
            description = "Full Pass Threshold"
        }
    else
        return {
            target = 100,
            gap = 100 - score,
            description = "Perfect Score"
        }
    end
end

function GateEvaluation:loadHistoricalData()
    spawn(function()
        local success, data = pcall(function()
            return GateEvaluationStore:GetAsync("historical_evaluations")
        end)
        
        if success and data then
            self.historicalEvaluations = data.evaluations or {}
            self.trendAnalysis = data.trends or {}
        end
    end)
end

function GateEvaluation:saveEvaluationData()
    spawn(function()
        -- Save current evaluation
        local success, error = pcall(function()
            local evaluationKey = "evaluation_" .. self.currentEvaluation.timestamp
            GateEvaluationStore:SetAsync(evaluationKey, self.currentEvaluation)
        end)
        
        if not success then
            warn("Failed to save gate evaluation:", error)
        end
        
        -- Save historical data
        local historySuccess, historyError = pcall(function()
            GateEvaluationStore:SetAsync("historical_evaluations", {
                evaluations = self.historicalEvaluations,
                trends = self.trendAnalysis,
                lastUpdate = tick()
            })
        end)
        
        if not historySuccess then
            warn("Failed to save historical evaluation data:", historyError)
        end
    end)
end

function GateEvaluation:exportReportData(format)
    local report = self:generateComprehensiveReport()
    
    if format == "json" then
        return HttpService:JSONEncode(report)
    elseif format == "summary" then
        return self:generateTextSummary(report)
    else
        return report -- Return raw data
    end
end

function GateEvaluation:generateTextSummary(report)
    local lines = {}
    
    table.insert(lines, "=== PHASE 0 GATE EVALUATION REPORT ===")
    table.insert(lines, "")
    table.insert(lines, string.format("Overall Score: %.1f%%", report.executiveSummary.overallScore))
    table.insert(lines, string.format("Decision: %s", report.executiveSummary.decision:upper()))
    table.insert(lines, string.format("Trend: %s", report.executiveSummary.trend:upper()))
    table.insert(lines, "")
    
    table.insert(lines, "QUANTITATIVE METRICS:")
    for metricKey, details in pairs(report.metrics.quantitative or {}) do
        table.insert(lines, string.format("  %s: %.2f %s (Score: %.1f%%, Status: %s)", 
            details.name, details.current, details.unit, details.score, details.status:upper()))
    end
    
    table.insert(lines, "")
    table.insert(lines, "QUALITATIVE METRICS:")
    for metricKey, details in pairs(report.metrics.qualitative or {}) do
        table.insert(lines, string.format("  %s: %.2f %s (Score: %.1f%%, Status: %s)", 
            details.name, details.current, details.unit, details.score, details.status:upper()))
    end
    
    table.insert(lines, "")
    table.insert(lines, "TOP RECOMMENDATIONS:")
    for i, rec in ipairs(report.recommendations) do
        if i <= 5 then -- Top 5 recommendations
            table.insert(lines, string.format("  %d. [%s] %s", i, rec.priority:upper(), rec.message))
        end
    end
    
    return table.concat(lines, "\n")
end

-- Public API functions
function GateEvaluation:GetCurrentEvaluation()
    return self.currentEvaluation
end

function GateEvaluation:GetHistoricalTrend()
    return self.trendAnalysis
end

function GateEvaluation:GetDecisionRecommendation()
    return {
        decision = self.currentEvaluation.decision,
        score = self.currentEvaluation.overallScore,
        nextMilestone = self:getNextMilestone(),
        topRecommendations = self:getTopRecommendations(3)
    }
end

function GateEvaluation:getTopRecommendations(count)
    local sortedRecs = {}
    
    -- Copy and sort recommendations by priority
    for _, rec in ipairs(self.currentEvaluation.recommendations or {}) do
        table.insert(sortedRecs, rec)
    end
    
    table.sort(sortedRecs, function(a, b)
        local priorityOrder = {high = 3, medium = 2, low = 1}
        return (priorityOrder[a.priority] or 0) > (priorityOrder[b.priority] or 0)
    end)
    
    -- Return top N recommendations
    local topRecs = {}
    for i = 1, math.min(count, #sortedRecs) do
        table.insert(topRecs, sortedRecs[i])
    end
    
    return topRecs
end

return GateEvaluation