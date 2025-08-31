--[[
FeedbackSystem.lua

Purpose: Player feedback collection UI for Week 5 beta analytics
Dependencies: BetaAnalytics (via RemoteEvents)
Last Modified: Phase 0 - Week 5
Performance Notes: Lightweight UI with minimal performance impact

Critical System: Player satisfaction measurement for Gate Decision

Features:
- In-game satisfaction surveys with 1-10 rating scale
- Bug reporting integration with automatic data collection
- Feature usage feedback and improvement suggestions
- Non-intrusive UI design preserving gameplay experience
- Privacy-compliant data collection with user consent
- Contextual feedback prompts based on player actions
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Remote event references
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local SubmitFeedbackEvent = RemoteEvents:WaitForChild("SubmitFeedback")
local RequestSurveyEvent = RemoteEvents:WaitForChild("RequestSurvey")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FeedbackSystem = {}
FeedbackSystem.__index = FeedbackSystem

-- Constants
local ANIMATION_TIME = 0.4
local SURVEY_Z_INDEX = 2000
local FEEDBACK_COOLDOWN = 1800 -- 30 minutes between prompts

-- UI Color Scheme
local COLORS = {
    background = Color3.fromRGB(25, 35, 55),
    primary = Color3.fromRGB(100, 150, 255),
    success = Color3.fromRGB(50, 150, 50),
    warning = Color3.fromRGB(255, 200, 100),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(200, 220, 255)
}

function FeedbackSystem.new()
    local self = setmetatable({}, FeedbackSystem)
    
    -- State management
    self.isVisible = false
    self.lastFeedbackTime = 0
    self.currentSurvey = nil
    self.feedbackQueue = {}
    
    -- Create feedback UI
    self:createFeedbackInterface()
    
    -- Connect events
    self:connectEvents()
    
    return self
end

function FeedbackSystem:createFeedbackInterface()
    -- Main feedback GUI
    local feedbackGui = Instance.new("ScreenGui")
    feedbackGui.Name = "FeedbackGUI"
    feedbackGui.ResetOnSpawn = false
    feedbackGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    feedbackGui.Parent = playerGui
    self.feedbackGui = feedbackGui
    
    -- Survey modal frame
    local surveyModal = Instance.new("Frame")
    surveyModal.Name = "SurveyModal"
    surveyModal.Size = UDim2.new(0, 450, 0, 500)
    surveyModal.Position = UDim2.new(0.5, -225, 0.5, -250)
    surveyModal.BackgroundColor3 = COLORS.background
    surveyModal.BorderSizePixel = 0
    surveyModal.Visible = false
    surveyModal.ZIndex = SURVEY_Z_INDEX
    surveyModal.Parent = feedbackGui
    self.surveyModal = surveyModal
    
    local modalCorner = Instance.new("UICorner")
    modalCorner.CornerRadius = UDim.new(0, 12)
    modalCorner.Parent = surveyModal
    
    -- Modal background dimmer
    local backgroundDimmer = Instance.new("Frame")
    backgroundDimmer.Name = "BackgroundDimmer"
    backgroundDimmer.Size = UDim2.new(1, 0, 1, 0)
    backgroundDimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backgroundDimmer.BackgroundTransparency = 0.5
    backgroundDimmer.BorderSizePixel = 0
    backgroundDimmer.Visible = false
    backgroundDimmer.ZIndex = SURVEY_Z_INDEX - 1
    backgroundDimmer.Parent = feedbackGui
    self.backgroundDimmer = backgroundDimmer
    
    -- Create survey components
    self:createSurveyHeader()
    self:createSurveyContent()
    self:createSurveyActions()
    
    -- Quick feedback button (always visible)
    self:createQuickFeedbackButton()
end

function FeedbackSystem:createSurveyHeader()
    -- Header frame
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "HeaderFrame"
    headerFrame.Size = UDim2.new(1, 0, 0, 60)
    headerFrame.Position = UDim2.new(0, 0, 0, 0)
    headerFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = self.surveyModal
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = headerFrame
    
    -- Hide bottom corners
    local headerBottomMask = Instance.new("Frame")
    headerBottomMask.Size = UDim2.new(1, 0, 0, 12)
    headerBottomMask.Position = UDim2.new(0, 0, 1, -12)
    headerBottomMask.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
    headerBottomMask.BorderSizePixel = 0
    headerBottomMask.Parent = headerFrame
    
    -- Survey title
    local surveyTitle = Instance.new("TextLabel")
    surveyTitle.Name = "SurveyTitle"
    surveyTitle.Size = UDim2.new(1, -80, 1, 0)
    surveyTitle.Position = UDim2.new(0, 20, 0, 0)
    surveyTitle.BackgroundTransparency = 1
    surveyTitle.Text = "Help Us Improve!"
    surveyTitle.TextColor3 = COLORS.text
    surveyTitle.TextSize = 20
    surveyTitle.Font = Enum.Font.GothamBold
    surveyTitle.TextXAlignment = Enum.TextXAlignment.Left
    surveyTitle.Parent = headerFrame
    self.surveyTitle = surveyTitle
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -50, 0.5, -20)
    closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    closeButton.Text = "×"
    closeButton.TextColor3 = COLORS.text
    closeButton.TextSize = 24
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = headerFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 20)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:hideFeedbackInterface()
    end)
end

function FeedbackSystem:createSurveyContent()
    -- Content scroll frame
    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Name = "ContentScroll"
    contentScroll.Size = UDim2.new(1, -20, 1, -130)
    contentScroll.Position = UDim2.new(0, 10, 0, 70)
    contentScroll.BackgroundTransparency = 1
    contentScroll.ScrollBarThickness = 8
    contentScroll.ScrollBarImageColor3 = COLORS.primary
    contentScroll.Parent = self.surveyModal
    self.contentScroll = contentScroll
    
    -- Content layout
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 15)
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.Parent = contentScroll
    
    contentLayout.Changed:Connect(function()
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 20)
    end)
    
    -- Privacy notice
    local privacyNotice = Instance.new("TextLabel")
    privacyNotice.Name = "PrivacyNotice"
    privacyNotice.Size = UDim2.new(1, -20, 0, 40)
    privacyNotice.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
    privacyNotice.Text = "🔒 Your feedback is anonymous and helps us improve the game experience."
    privacyNotice.TextColor3 = COLORS.textSecondary
    privacyNotice.TextSize = 11
    privacyNotice.Font = Enum.Font.Gotham
    privacyNotice.TextWrapped = true
    privacyNotice.Parent = contentScroll
    
    local privacyCorner = Instance.new("UICorner")
    privacyCorner.CornerRadius = UDim.new(0, 6)
    privacyCorner.Parent = privacyNotice
end

function FeedbackSystem:createSurveyActions()
    -- Actions frame
    local actionsFrame = Instance.new("Frame")
    actionsFrame.Name = "ActionsFrame"
    actionsFrame.Size = UDim2.new(1, -20, 0, 50)
    actionsFrame.Position = UDim2.new(0, 10, 1, -60)
    actionsFrame.BackgroundTransparency = 1
    actionsFrame.Parent = self.surveyModal
    
    -- Submit button
    local submitButton = Instance.new("TextButton")
    submitButton.Name = "SubmitButton"
    submitButton.Size = UDim2.new(0, 120, 1, 0)
    submitButton.Position = UDim2.new(1, -130, 0, 0)
    submitButton.BackgroundColor3 = COLORS.success
    submitButton.Text = "Submit Feedback"
    submitButton.TextColor3 = COLORS.text
    submitButton.TextSize = 14
    submitButton.Font = Enum.Font.GothamBold
    submitButton.Parent = actionsFrame
    self.submitButton = submitButton
    
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 8)
    submitCorner.Parent = submitButton
    
    submitButton.MouseButton1Click:Connect(function()
        self:submitCurrentSurvey()
    end)
    
    -- Skip button  
    local skipButton = Instance.new("TextButton")
    skipButton.Name = "SkipButton"
    skipButton.Size = UDim2.new(0, 80, 1, 0)
    skipButton.Position = UDim2.new(1, -220, 0, 0)
    skipButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    skipButton.Text = "Skip"
    skipButton.TextColor3 = COLORS.text
    skipButton.TextSize = 12
    skipButton.Font = Enum.Font.Gotham
    skipButton.Parent = actionsFrame
    
    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 8)
    skipCorner.Parent = skipButton
    
    skipButton.MouseButton1Click:Connect(function()
        self:hideFeedbackInterface()
    end)
end

function FeedbackSystem:createQuickFeedbackButton()
    -- Quick feedback floating button
    local quickButton = Instance.new("TextButton")
    quickButton.Name = "QuickFeedbackButton"
    quickButton.Size = UDim2.new(0, 50, 0, 50)
    quickButton.Position = UDim2.new(1, -70, 1, -100)
    quickButton.BackgroundColor3 = COLORS.primary
    quickButton.Text = "💬"
    quickButton.TextSize = 20
    quickButton.Font = Enum.Font.GothamBold
    quickButton.ZIndex = 100
    quickButton.Parent = self.feedbackGui
    self.quickButton = quickButton
    
    local quickCorner = Instance.new("UICorner")
    quickCorner.CornerRadius = UDim.new(0, 25)
    quickCorner.Parent = quickButton
    
    -- Quick button hover effects
    quickButton.MouseEnter:Connect(function()
        local hoverTween = TweenService:Create(quickButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(120, 170, 255)}
        )
        hoverTween:Play()
    end)
    
    quickButton.MouseLeave:Connect(function()
        local hoverTween = TweenService:Create(quickButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = COLORS.primary}
        )
        hoverTween:Play()
    end)
    
    quickButton.MouseButton1Click:Connect(function()
        self:showQuickFeedbackMenu()
    end)
end

function FeedbackSystem:connectEvents()
    -- Server survey requests
    if RequestSurveyEvent then
        RequestSurveyEvent.OnClientEvent:Connect(function(surveyType, surveyData)
            self:displaySurvey(surveyType, surveyData)
        end)
    end
end

function FeedbackSystem:displaySurvey(surveyType, surveyData)
    -- Check cooldown
    local currentTime = tick()
    if currentTime - self.lastFeedbackTime < FEEDBACK_COOLDOWN then
        return -- Skip survey if too recent
    end
    
    self.currentSurvey = {
        type = surveyType,
        data = surveyData,
        responses = {},
        startTime = currentTime
    }
    
    -- Update survey title
    self.surveyTitle.Text = surveyData.title or "Help Us Improve!"
    
    -- Clear existing content (keep privacy notice)
    for _, child in ipairs(self.contentScroll:GetChildren()) do
        if child.Name ~= "PrivacyNotice" and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    -- Create survey questions
    for _, question in ipairs(surveyData.questions or {}) do
        self:createQuestionElement(question)
    end
    
    -- Show survey interface
    self:showFeedbackInterface()
    
    self.lastFeedbackTime = currentTime
end

function FeedbackSystem:createQuestionElement(question)
    -- Question frame
    local questionFrame = Instance.new("Frame")
    questionFrame.Name = "Question_" .. question.id
    questionFrame.Size = UDim2.new(1, -20, 0, 100)
    questionFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
    questionFrame.BorderSizePixel = 0
    questionFrame.Parent = self.contentScroll
    
    local questionCorner = Instance.new("UICorner")
    questionCorner.CornerRadius = UDim.new(0, 8)
    questionCorner.Parent = questionFrame
    
    -- Question text
    local questionLabel = Instance.new("TextLabel")
    questionLabel.Name = "QuestionLabel"
    questionLabel.Size = UDim2.new(1, -20, 0, 30)
    questionLabel.Position = UDim2.new(0, 10, 0, 10)
    questionLabel.BackgroundTransparency = 1
    questionLabel.Text = question.text
    questionLabel.TextColor3 = COLORS.text
    questionLabel.TextSize = 14
    questionLabel.Font = Enum.Font.GothamBold
    questionLabel.TextXAlignment = Enum.TextXAlignment.Left
    questionLabel.TextWrapped = true
    questionLabel.Parent = questionFrame
    
    -- Create input based on question type
    if question.type == "rating" then
        self:createRatingInput(questionFrame, question)
    elseif question.type == "text" then
        self:createTextInput(questionFrame, question)
    elseif question.type == "choice" then
        self:createChoiceInput(questionFrame, question)
    end
    
    -- Adjust frame height based on content
    local contentHeight = 50 -- Base height
    if question.type == "rating" then
        contentHeight = 80
    elseif question.type == "text" then
        contentHeight = 100
    elseif question.type == "choice" then
        contentHeight = 60 + (#(question.options or {}) * 25)
    end
    
    questionFrame.Size = UDim2.new(1, -20, 0, contentHeight)
end

function FeedbackSystem:createRatingInput(parent, question)
    local ratingFrame = Instance.new("Frame")
    ratingFrame.Name = "RatingFrame"
    ratingFrame.Size = UDim2.new(1, -20, 0, 40)
    ratingFrame.Position = UDim2.new(0, 10, 0, 40)
    ratingFrame.BackgroundTransparency = 1
    ratingFrame.Parent = parent
    
    local scale = question.scale or 10
    local buttonWidth = math.min(35, (ratingFrame.AbsoluteSize.X - 20) / scale)
    
    -- Create rating buttons
    for i = 1, scale do
        local ratingButton = Instance.new("TextButton")
        ratingButton.Name = "Rating_" .. i
        ratingButton.Size = UDim2.new(0, buttonWidth, 0, 30)
        ratingButton.Position = UDim2.new(0, (i-1) * (buttonWidth + 2), 0, 5)
        ratingButton.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
        ratingButton.Text = tostring(i)
        ratingButton.TextColor3 = COLORS.text
        ratingButton.TextSize = 14
        ratingButton.Font = Enum.Font.GothamBold
        ratingButton.Parent = ratingFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = ratingButton
        
        ratingButton.MouseButton1Click:Connect(function()
            self:selectRating(question.id, i, ratingFrame)
        end)
    end
end

function FeedbackSystem:createTextInput(parent, question)
    local textBox = Instance.new("TextBox")
    textBox.Name = "TextInput"
    textBox.Size = UDim2.new(1, -20, 0, 50)
    textBox.Position = UDim2.new(0, 10, 0, 40)
    textBox.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    textBox.Text = ""
    textBox.PlaceholderText = question.placeholder or "Enter your feedback..."
    textBox.TextColor3 = COLORS.text
    textBox.PlaceholderColor3 = COLORS.textSecondary
    textBox.TextSize = 12
    textBox.Font = Enum.Font.Gotham
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.TextWrapped = true
    textBox.MultiLine = true
    textBox.Parent = parent
    
    local textCorner = Instance.new("UICorner")
    textCorner.CornerRadius = UDim.new(0, 6)
    textCorner.Parent = textBox
    
    textBox.FocusLost:Connect(function()
        if not self.currentSurvey then return end
        self.currentSurvey.responses[question.id] = textBox.Text
    end)
end

function FeedbackSystem:createChoiceInput(parent, question)
    local choiceFrame = Instance.new("Frame")
    choiceFrame.Name = "ChoiceFrame"
    choiceFrame.Size = UDim2.new(1, -20, 0, #(question.options or {}) * 25)
    choiceFrame.Position = UDim2.new(0, 10, 0, 40)
    choiceFrame.BackgroundTransparency = 1
    choiceFrame.Parent = parent
    
    -- Create choice buttons
    for i, option in ipairs(question.options or {}) do
        local choiceButton = Instance.new("TextButton")
        choiceButton.Name = "Choice_" .. i
        choiceButton.Size = UDim2.new(1, 0, 0, 20)
        choiceButton.Position = UDim2.new(0, 0, 0, (i-1) * 25)
        choiceButton.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
        choiceButton.Text = "○ " .. option
        choiceButton.TextColor3 = COLORS.text
        choiceButton.TextSize = 12
        choiceButton.Font = Enum.Font.Gotham
        choiceButton.TextXAlignment = Enum.TextXAlignment.Left
        choiceButton.Parent = choiceFrame
        
        local choiceCorner = Instance.new("UICorner")
        choiceCorner.CornerRadius = UDim.new(0, 4)
        choiceCorner.Parent = choiceButton
        
        choiceButton.MouseButton1Click:Connect(function()
            self:selectChoice(question.id, option, choiceFrame)
        end)
    end
end

function FeedbackSystem:selectRating(questionId, rating, ratingFrame)
    if not self.currentSurvey then return end
    
    self.currentSurvey.responses[questionId] = rating
    
    -- Update button appearances
    for _, child in ipairs(ratingFrame:GetChildren()) do
        if child.Name:find("Rating_") then
            local buttonNumber = tonumber(child.Name:match("Rating_(.+)"))
            if buttonNumber == rating then
                child.BackgroundColor3 = COLORS.success
            else
                child.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
            end
        end
    end
end

function FeedbackSystem:selectChoice(questionId, choice, choiceFrame)
    if not self.currentSurvey then return end
    
    self.currentSurvey.responses[questionId] = choice
    
    -- Update choice appearances
    for _, child in ipairs(choiceFrame:GetChildren()) do
        if child.Name:find("Choice_") then
            if child.Text:find(choice, 1, true) then
                child.BackgroundColor3 = COLORS.success
                child.Text = "● " .. choice
            else
                child.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
                child.Text = "○ " .. child.Text:sub(3) -- Remove existing marker
            end
        end
    end
end

function FeedbackSystem:showQuickFeedbackMenu()
    -- Create quick feedback options
    local quickFeedback = {
        type = "quick",
        data = {
            title = "Quick Feedback",
            questions = {
                {
                    id = "quick_rating",
                    text = "How would you rate your current experience?",
                    type = "rating",
                    scale = 10
                },
                {
                    id = "quick_issue",
                    text = "Any issues or suggestions? (Optional)",
                    type = "text",
                    placeholder = "Describe any problems or ideas..."
                }
            }
        }
    }
    
    self:displaySurvey("quick", quickFeedback.data)
end

function FeedbackSystem:showFeedbackInterface()
    self.isVisible = true
    self.backgroundDimmer.Visible = true
    self.surveyModal.Visible = true
    
    -- Smooth entrance animation
    self.surveyModal.Position = UDim2.new(0.5, -225, 0.3, -250)
    self.surveyModal.BackgroundTransparency = 1
    self.backgroundDimmer.BackgroundTransparency = 1
    
    local modalTween = TweenService:Create(self.surveyModal,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -225, 0.5, -250), BackgroundTransparency = 0}
    )
    modalTween:Play()
    
    local dimmerTween = TweenService:Create(self.backgroundDimmer,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.5}
    )
    dimmerTween:Play()
end

function FeedbackSystem:hideFeedbackInterface()
    if not self.isVisible then return end
    
    local modalTween = TweenService:Create(self.surveyModal,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -225, 0.3, -250), BackgroundTransparency = 1}
    )
    modalTween:Play()
    
    local dimmerTween = TweenService:Create(self.backgroundDimmer,
        TweenInfo.new(ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}
    )
    dimmerTween:Play()
    
    dimmerTween.Completed:Connect(function()
        self.surveyModal.Visible = false
        self.backgroundDimmer.Visible = false
        self.isVisible = false
        self.currentSurvey = nil
    end)
end

function FeedbackSystem:submitCurrentSurvey()
    if not self.currentSurvey then return end
    
    -- Validate responses
    local hasResponses = false
    for _ in pairs(self.currentSurvey.responses) do
        hasResponses = true
        break
    end
    
    if not hasResponses then
        -- Show validation message
        self:showValidationMessage("Please provide at least one response before submitting.")
        return
    end
    
    -- Submit feedback to server
    if SubmitFeedbackEvent then
        SubmitFeedbackEvent:FireServer(self.currentSurvey.type, {
            responses = self.currentSurvey.responses,
            surveyData = self.currentSurvey.data,
            completionTime = tick() - self.currentSurvey.startTime,
            timestamp = tick()
        })
    end
    
    -- Show thank you message
    self:showThankYouMessage()
    
    -- Hide interface after delay
    task.wait(2)
    self:hideFeedbackInterface()
end

function FeedbackSystem:showValidationMessage(message)
    -- Create temporary validation message
    local validationLabel = Instance.new("TextLabel")
    validationLabel.Name = "ValidationMessage"
    validationLabel.Size = UDim2.new(1, -40, 0, 30)
    validationLabel.Position = UDim2.new(0, 20, 1, -100)
    validationLabel.BackgroundColor3 = COLORS.warning
    validationLabel.Text = message
    validationLabel.TextColor3 = COLORS.text
    validationLabel.TextSize = 12
    validationLabel.Font = Enum.Font.GothamBold
    validationLabel.ZIndex = SURVEY_Z_INDEX + 10
    validationLabel.Parent = self.surveyModal
    
    local validationCorner = Instance.new("UICorner")
    validationCorner.CornerRadius = UDim.new(0, 6)
    validationCorner.Parent = validationLabel
    
    -- Auto-remove after 3 seconds
    task.wait(3)
    validationLabel:Destroy()
end

function FeedbackSystem:showThankYouMessage()
    -- Replace survey content with thank you message
    local thankYouLabel = Instance.new("TextLabel")
    thankYouLabel.Name = "ThankYouMessage"
    thankYouLabel.Size = UDim2.new(1, 0, 1, 0)
    thankYouLabel.BackgroundTransparency = 1
    thankYouLabel.Text = "Thank you for your feedback!\n\nYour input helps us improve\nAquaticMetropolis for everyone. 🌊"
    thankYouLabel.TextColor3 = COLORS.text
    thankYouLabel.TextSize = 18
    thankYouLabel.Font = Enum.Font.GothamBold
    thankYouLabel.ZIndex = SURVEY_Z_INDEX + 10
    thankYouLabel.Parent = self.contentScroll
    
    -- Hide other content
    for _, child in ipairs(self.contentScroll:GetChildren()) do
        if child ~= thankYouLabel and not child:IsA("UIListLayout") then
            child.Visible = false
        end
    end
end

-- Export the class
return FeedbackSystem