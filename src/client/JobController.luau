--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Strings = require(ReplicatedStorage.Shared.Strings)
local Config = require(ReplicatedStorage.Shared.PaintConfig)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local Goals = require(ReplicatedStorage.Shared.NavigationGoal)
local Mastery = require(ReplicatedStorage.Shared.PaintingMastery)
local Abandon = require("./JobAbandonController")
local PaintController = require("./PaintController")
local Navigation = require("./JobNavigation")
local MapController = require("./MapController")
local JobOffers = require("./JobOffersController")
local ClientInteraction = require("./ClientInteractionController")
local FirstSteps = require("./FirstStepsController")
local WorkPlan = require("./JobWorkPlanController")
local Finish = require(ReplicatedStorage.Shared.PaintFinish)
local ResultScene = require("./PaintResultScene")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	homePanel: Frame,
	language: () -> string,
	homeAction: (string) -> (),
	hideHousing: () -> (),
	travelGoal: () -> Goals.Goal?,
	stopTravel: () -> ()
)
	local player = Players.LocalPlayer
	local command = ReplicatedStorage:WaitForChild("JobCommand")
	local stateEvent = ReplicatedStorage:WaitForChild("JobState")
	assert(command:IsA("RemoteEvent") and stateEvent:IsA("RemoteEvent"), "Job remotes missing")
	local state: Types.Snapshot? = nil
	local nearWall = false
	local lastError: string? = nil
	local errorUntil = 0
	local actions = {
		Offer = "openJobs",
		Inspect = "meetClient",
		Prepare = "protectFloor",
		ChooseMaterial = "choosePaint",
		Painting = "useRoller",
		SurfaceReady = "nextSurface",
		Ready = "handoverClient",
		Completed = "openJobs",
	}
	local phaseKeys = {
		Inspect = "jobInspect",
		Prepare = "jobPrepare",
		ChooseMaterial = "jobColor",
		Painting = "jobPaint",
		SurfaceReady = "jobSurfaceReady",
		Ready = "jobReady",
		Completed = "jobDone",
		Offer = "jobOffer",
	}
	local function t(k: string): string
		return Strings.text(language(), k)
	end
	local function text(
		parent: Instance,
		name: string,
		y: number,
		height: number,
		size: number
	): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromOffset(16, y)
		l.Size = UDim2.new(1, -32, 0, height)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(244, 239, 224)
		l.Font = Enum.Font.GothamMedium
		l.TextSize = size
		l.TextWrapped = true
		l.Parent = parent
		return l
	end
	local function button(parent: Instance, name: string, y: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(1, -32, 0, 44)
		b.Position = UDim2.fromOffset(16, y)
		b.BackgroundColor3 = Color3.fromRGB(55, 120, 102)
		b.TextColor3 = Color3.fromRGB(244, 239, 224)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 15
		b.Parent = parent
		return b
	end
	local function panel(name: string): (Frame, TextLabel, TextButton, ScrollingFrame)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.new(1, -24, 1, -24)
		f.BackgroundColor3 = Color3.fromRGB(26, 43, 43)
		f.Visible = false
		f.ZIndex = 8
		f.Parent = screen
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(480, 388)
		limit.Parent = f
		local h = text(f, "Heading", 12, 32, 22)
		local back = button(f, "Back", 332)
		back.Position = UDim2.new(0, 16, 1, -56)
		local body = Instance.new("ScrollingFrame")
		body.Name = "Body"
		body.Position = UDim2.fromOffset(0, 54)
		body.Size = UDim2.new(1, 0, 1, -122)
		body.CanvasSize = UDim2.fromOffset(0, 274)
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.ScrollBarThickness = 4
		body.Parent = f
		return f, h, back, body
	end
	local jobs, heading, back, jobBody = panel("JobsPanel")
	local description = text(jobBody, "Description", 0, 70, 17)
	local progress = text(jobBody, "Progress", 74, 36, 15)
	local hint = text(jobBody, "Hint", 116, 44, 14)
	local action = button(jobBody, "Action", 168)
	local cancel = button(jobBody, "Cancel", 224)
	local workPlan = WorkPlan.start(jobBody, language)
	local colors = Instance.new("Frame")
	colors.Name = "Colors"
	colors.BackgroundTransparency = 1
	colors.Size = UDim2.new(1, -32, 0, 44)
	colors.Position = UDim2.fromOffset(16, 168)
	colors.Visible = false
	colors.Parent = jobBody
	local tools = Instance.new("Frame")
	tools.Name, tools.Position, tools.Size =
		"Tools", UDim2.fromOffset(16, 116), UDim2.new(1, -32, 0, 44)
	tools.BackgroundTransparency, tools.Visible, tools.Parent = 1, false, jobBody
	local toolButtons: { TextButton } = {}
	for index, id in { "basic", "wide" } do
		local b = button(tools, id, 0)
		b.Position, b.Size = UDim2.new((index - 1) / 2, 2, 0, 0), UDim2.new(0.5, -4, 1, 0)
		b.TextSize = 13
		table.insert(toolButtons, b)
	end
	local swatches: { TextButton } = {}
	for index, colorId in { "rose", Config.colorId, "mint" } do
		local b = Instance.new("TextButton")
		b.Name = if colorId == Config.colorId
			then "WarmWhite"
			elseif colorId == "rose" then "Rose"
			else "Mint"
		b.Position = UDim2.new((index - 1) / 3, 2, 0, 0)
		b.Size = UDim2.new(1 / 3, -4, 1, 0)
		b.TextSize = 13
		b.Font = Enum.Font.GothamMedium
		b.TextColor3 = Color3.fromRGB(26, 43, 43)
		b.BackgroundColor3 = Color3.new(table.unpack(Config.palette[colorId] or Config.color))
		b.Parent = colors
		table.insert(swatches, b)
	end
	local map = MapController.start(screen, homePanel, language)
	local results, resultHeading, resultContinue, resultBody = panel("ResultsPanel")
	resultContinue.Name = "Continue"
	resultHeading.Size = UDim2.new(1, -90, 0, 36)
	resultBody.CanvasSize = UDim2.fromOffset(0, 388)
	local resultLimit = results:FindFirstChildOfClass("UISizeConstraint")
	assert(resultLimit, "Result size constraint missing")
	resultLimit.MaxSize = Vector2.new(520, 488)
	local comparison = ResultScene.start(resultBody)
	results:GetPropertyChangedSignal("Visible"):Connect(function()
		if not results.Visible then
			comparison.render(nil, "")
		end
	end)
	local resultClose = button(results, "Close", 12)
	resultClose.Position = UDim2.new(1, -60, 0, 12)
	resultClose.Size = UDim2.fromOffset(44, 44)
	resultClose.Text = "×"
	local before = text(resultBody, "Before", 92, 24, 13)
	before.Size = UDim2.new(0.5, -20, 0, 24)
	before.BackgroundTransparency = 0
	before.BackgroundColor3 = Color3.fromRGB(145, 148, 140)
	before.TextColor3 = Color3.fromRGB(26, 43, 43)
	local after = text(resultBody, "After", 92, 24, 13)
	after.Position = UDim2.new(0.5, 4, 0, 92)
	after.Size = UDim2.new(0.5, -20, 0, 24)
	after.BackgroundTransparency = 0
	after.BackgroundColor3 = Color3.new(table.unpack(Config.color))
	after.TextColor3 = Color3.fromRGB(26, 43, 43)
	local afterGradient = Instance.new("UIGradient")
	afterGradient.Enabled, afterGradient.Parent = false, after
	local resultMoney = text(resultBody, "Dollars", 0, 36, 24)
	resultMoney.Size = UDim2.new(0.5, -20, 0, 36)
	local resultXP = text(resultBody, "XP", 0, 36, 14)
	resultXP.Position, resultXP.Size = UDim2.new(0.5, 4, 0, 0), UDim2.new(0.5, -20, 0, 36)
	local resultQuality = text(resultBody, "Quality", 40, 44, 13)
	local resultHint = text(resultBody, "Hint", 264, 112, 13)
	local shownOperation: string? = nil
	resultClose.Activated:Connect(function()
		results.Visible = false
	end)

	local abandon: Abandon.API? = nil
	local acceptancePending: () -> boolean = function(): boolean
		return false
	end
	local function send(actionName: string, fields: { [string]: unknown }?): ()
		if ((abandon and abandon.pending()) or acceptancePending()) and actionName ~= "sync" then
			return
		end
		local data: { [string]: unknown } = fields or {}
		data.action = actionName
		local s = state
		if s then
			data.jobId = s.jobId
			data.workId = s.workId
		end
		command:FireServer(data)
	end
	local offers = JobOffers.start(
		jobs,
		jobBody,
		back,
		language,
		function(id: string, previousJobId: string, requestId: string)
			stopTravel()
			-- Retry must retain the original baseline, rather than taking IDs from newer UI state.
			command:FireServer({
				action = "accept",
				offerId = id,
				jobId = previousJobId,
				requestId = requestId,
			})
		end,
		function(): boolean
			return player:GetAttribute("ProfileStatus") == "Ready"
		end
	)
	acceptancePending = offers.pending
	local painter = PaintController.start(screen, send, language)
	local interaction: ClientInteraction.API
	local guide: FirstSteps.API
	local function hidePanels(): ()
		if abandon then
			abandon.hide()
		end
		jobs.Visible = false
		map.hide()
		results.Visible = false
		interaction.hide()
		guide.hide()
	end
	local function returnPhone(): ()
		if offers.back() then
			return
		end
		hidePanels()
		homePanel.Visible = true
	end
	back.Activated:Connect(returnPhone)
	local function currentWall(): BasePart?
		local s = state
		if s == nil or s.location == nil then
			return nil
		end
		local folder = workspace:FindFirstChild("Homes")
		local room = if folder then folder:FindFirstChild(s.location) else nil
		local wall = if room then room:FindFirstChild(s.wallName or "PaintableWall") else nil
		return if wall and wall:IsA("BasePart") then wall else nil
	end
	local function activate(): ()
		if acceptancePending() then
			hideHousing()
			hidePanels()
			homePanel.Visible, jobs.Visible = false, true
			offers.show()
			send("sync", nil)
			return
		end
		if abandon and abandon.pending() then
			hideHousing()
			hidePanels()
			homePanel.Visible = false
			abandon.resume()
			return
		end
		local travel = travelGoal()
		if travel then
			if travel.available and player:GetAttribute("ProfileStatus") == "Ready" then
				if travel.near then
					homeAction("Shop")
				else
					jobs.Visible = false
					map.show()
				end
			end
			return
		end
		local s = state
		if s == nil or not s.available then
			return
		end
		if
			s.phase == "Completed"
			and (
				player:GetAttribute("OnboardingStep") == "BUY"
				or player:GetAttribute("OnboardingStep") == "PLACE"
			)
		then
			homeAction(
				if player:GetAttribute("OnboardingStep") == "BUY" then "Shop" else "Furniture"
			)
		elseif s.phase == "Offer" or s.phase == "Completed" then
			homePanel.Visible, jobs.Visible = false, true
			map.hide()
			offers.show()
			send("sync", nil)
		elseif not nearWall then
			jobs.Visible = false
			map.show()
		elseif s.phase == "ChooseMaterial" then
			homePanel.Visible, jobs.Visible = false, true
			map.hide()
		elseif s.phase == "Painting" then
			local wall = currentWall()
			if wall then
				hidePanels()
				homePanel.Visible = false
				painter.enter(wall, s)
			end
		else
			local a = ({
				Inspect = "talk",
				Prepare = "prepare",
				SurfaceReady = "nextSurface",
				Ready = "talk",
			})[s.phase]
			if a then
				send(a, nil)
			end
		end
	end
	interaction = ClientInteraction.start(screen, language, function()
		stopTravel()
		hideHousing()
		guide.hide()
		painter.stop()
		jobs.Visible, results.Visible, homePanel.Visible = false, false, false
		map.hide()
	end, function(a: string)
		if a == "palette" or a == "paint" then
			activate()
		else
			send(a, nil)
		end
	end)
	guide = FirstSteps.start(screen, language, function()
		hideHousing()
		painter.stop()
		interaction.hide()
		jobs.Visible, results.Visible, homePanel.Visible = false, false, false
		map.hide()
	end, function(target: string)
		if target == "Jobs" then
			stopTravel()
			homePanel.Visible, jobs.Visible = false, true
			offers.show()
			send("sync", nil)
		elseif target == "Phone" then
			homePanel.Visible = true
		elseif target == "Current" then
			stopTravel()
			activate()
		else
			homeAction(target)
		end
	end)
	local navigation = Navigation.start(screen, activate)
	local function revealActions(): ()
		if jobs.Visible then
			local phase = if state then state.phase else "Offer"
			local bottom = if phase == "Offer"
					or phase == "Completed"
					or phase == "ChooseMaterial"
				then 212
				else 268
			jobBody.CanvasPosition = Vector2.new(0, math.max(0, bottom - jobBody.AbsoluteSize.Y))
		end
	end
	jobs:GetPropertyChangedSignal("Visible"):Connect(revealActions)
	jobBody:GetPropertyChangedSignal("AbsoluteSize"):Connect(revealActions)
	local function stepHint(phase: string): string
		if lastError and os.clock() < errorUntil then
			if lastError == "Color" then
				local id = if state then state.requiredColorId or Config.colorId else Config.colorId
				return string.format(t("contractMaterial"), t(Config.colorKeys[id] or "warmWhite"))
					.. " · "
					.. t("colorRetry")
			end
			return t("jobError" .. lastError)
		end
		if phase == "Offer" then
			return t(if acceptancePending() then "acceptPendingStatus" else "offerHint")
		end
		if phase == "Completed" then
			return t(
				if player:GetAttribute("OnboardingStep") == "BUY"
					then "firstPurchaseHint"
					elseif
						player:GetAttribute("OnboardingStep") == "PLACE"
					then "firstPlacementHint"
					else "doneHint"
			)
		end
		if not nearWall then
			return t("jobRouteHint")
		end
		if phase == "ChooseMaterial" then
			local id = if state then state.requiredColorId or Config.colorId else Config.colorId
			return string.format(t("contractMaterial"), t(Config.colorKeys[id] or "warmWhite"))
		end
		local hints = {
			Inspect = "meetClientHint",
			Prepare = "prepareHint",
			ChooseMaterial = "colorHint",
			Painting = "paintHint",
			SurfaceReady = "nextSurfaceHint",
			Ready = "handoverClientHint",
		}
		return t(hints[phase] or "jobRouteHint")
	end
	local function render(): ()
		local s = state
		if abandon then
			abandon.render(s)
		end
		offers.render(s)
		interaction.render(s)
		guide.render(s)
		local phase = if s then s.phase else "Offer"
		heading.Text = t("jobs")
		back.Text = t("backHome")
		local planCaption = workPlan.render(s, player:GetAttribute("ProfileStatus") == "Ready")
		description.Text = t(phaseKeys[phase] or "jobOffer")
		if phase == "ChooseMaterial" then
			description.Text ..= "\n" .. stepHint(phase)
		end
		progress.Text = if planCaption
			then planCaption
			elseif phase == "Offer" then "$" .. (if s then s.reward else 0)
			elseif phase == "Completed" then "+$" .. (if s then s.reward else 0)
			else string.format(
				"%d%%",
				math.floor((if s then s.count else 0) / (Config.columns * Config.rows) * 100)
			)
		if
			not planCaption
			and s
			and (s.surfaceTotal or 1) > 1
			and phase ~= "Completed"
			and phase ~= "Offer"
		then
			progress.Text = string.format(
				t("surfaceProgress"),
				s.surfaceIndex or 1,
				s.surfaceTotal or 1
			) .. " · " .. progress.Text
		end
		hint.Text = stepHint(phase)
		hint.Visible = phase ~= "ChooseMaterial"
		tools.Visible = phase == "ChooseMaterial"
		for index, b in toolButtons do
			local id = if index == 1 then "basic" else "wide"
			local xp = if s then s.paintingXP or 0 else 0
			b.Text = t(if id == "basic" then "basicRoller" else "wideRoller")
				.. (
					if s and s.toolId == id
						then " " .. t("toolSelected")
						elseif id == "wide" and xp < Config.wideRollerXP then " · "
							.. Config.wideRollerXP
							.. " XP"
						else ""
				)
			b.Active = s ~= nil
				and s.available
				and phase == "ChooseMaterial"
				and (id == "basic" or xp >= Config.wideRollerXP)
			b.AutoButtonColor, b.BackgroundTransparency = b.Active, if b.Active then 0 else 0.6
		end
		cancel.Text = t("cancelJob")
		cancel.Visible = phase ~= "Offer" and phase ~= "Completed"
		cancel.Active = s ~= nil
			and s.available
			and player:GetAttribute("ProfileStatus") == "Ready"
			and not (abandon and abandon.pending())
			and not acceptancePending()
		cancel.AutoButtonColor = cancel.Active
		colors.Visible = phase == "ChooseMaterial"
		action.Visible = not colors.Visible
		action.Text = t(actions[phase] or "acceptJob")
		action.Active = s ~= nil and s.available and not (abandon and abandon.pending())
		action.AutoButtonColor = action.Active
		for index, b in swatches do
			b.Text = t(({ "rose", "warmWhite", "mint" })[index])
			b.Active = s ~= nil and s.available
		end
		map.render()
		painter.render()
		local travel = travelGoal()
		local onboarding = player:GetAttribute("OnboardingStep")
		local nextKey = if phase == "Completed" and onboarding == "BUY"
			then "shopTitle"
			elseif phase == "Completed" and onboarding == "PLACE" then "furnitureApp"
			else actions[phase] or "openJobs"
		navigation.render(
			t(
				if travel
					then (if travel.near then "openShop" else "openMap")
					elseif s and s.destination and not nearWall then "openMap"
					else nextKey
			),
			if travel then travel.available else s ~= nil and s.available
		)
		action.Text = t(nextKey)
		resultHeading.Text = t("resultTitle")
		before.Text, after.Text = t("resultBefore"), t("resultAfter")
		local receipt = if s then s.result else nil
		resultMoney.Text = if receipt then string.format("+$%d", receipt.dollars) else ""
		resultXP.Text = if receipt then string.format(t("resultXP"), receipt.xp) else ""
		resultQuality.Text = t("resultAccepted")
		local mastery = Mastery.evaluate(
			if s then s.paintingXP else nil,
			if s then s.offers else nil,
			s ~= nil and s.available,
			if receipt then receipt.xp else nil
		)
		local firstHome = onboarding == "BUY" or onboarding == "PLACE"
		resultHint.Text = if firstHome
			then t("resultNext")
			elseif mastery.ready then (if mastery.nextId
				then Mastery.goalText(mastery, language())
				else t("masteryRepeatHint"))
			else t("offerWaiting")
		for _, opened in mastery.opened do
			resultHint.Text = string.format(t("masteryOpened"), t(opened.titleKey))
				.. "\n"
				.. resultHint.Text
		end
		if mastery.wideJustUnlocked then
			resultHint.Text = t("wideUnlockedResult") .. "\n" .. resultHint.Text
		end
		local required = if receipt and receipt.primaryColorId
			then receipt.primaryColorId
			elseif s then s.requiredColorId or Config.colorId
			else Config.colorId
		local secondary = if receipt then receipt.secondaryColorId else nil
		local primary = Color3.new(table.unpack(Config.palette[required] or Config.color))
		afterGradient.Enabled = secondary ~= nil
		after.BackgroundColor3 = if secondary then Color3.new(1, 1, 1) else primary
		if secondary then
			afterGradient.Color = ColorSequence.new(
				primary,
				Color3.new(table.unpack(Config.palette[secondary] or Config.color))
			)
			after.Text, resultQuality.Text = t("resultAfterDuo"), t("resultAcceptedDuo")
		end
		local quality = Finish.evaluate(if receipt then receipt.finish else nil)
		if quality then
			resultQuality.Text = string.format(t("finish" .. quality.grade), quality.percent)
				.. "\n"
				.. (
					if #quality.surfaces == 2
						then string.format(
							t("finishWalls"),
							quality.surfaces[1],
							quality.surfaces[2]
						)
						else t("finishPaid")
				)
		end
		comparison.render(
			if results.Visible and s and s.available then receipt else nil,
			t("finishLegacy")
		)
		resultContinue.Text = t(
			if onboarding == "BUY"
				then "shopTitle"
				elseif onboarding == "PLACE" then "furnitureApp"
				elseif mastery.ready and mastery.recommendedId then "masteryView"
				else "openJobs"
		)
		resultContinue.Active = s ~= nil
			and not acceptancePending()
			and s.available
			and s.phase == "Completed"
			and receipt ~= nil
			and player:GetAttribute("ProfileStatus") == "Ready"
		resultContinue.AutoButtonColor = resultContinue.Active
		screen:SetAttribute("JobHintError", lastError ~= nil and os.clock() < errorUntil)
		local objective = screen:FindFirstChild("Objective")
		if
			objective
			and objective:IsA("Frame")
			and player:GetAttribute("ProfileStatus") == "Ready"
		then
			local label = objective:FindFirstChild("Title")
			local detail = objective:FindFirstChild("Hint")
			if label and label:IsA("TextLabel") then
				label.Text = t(
					if travel
						then (if travel.near then "arrivedShop" else "goToShop")
						elseif s and s.destination and not nearWall then "goToClient"
						else phaseKeys[phase] or "jobOffer"
				)
			end
			if detail and detail:IsA("TextLabel") then
				detail.Text = if travel
					then t(if travel.near then "shopArrivalHint" else "shopRouteHint")
					else stepHint(phase)
			end
		end
	end
	action.Activated:Connect(activate)
	resultContinue.Activated:Connect(function()
		local s = state
		if
			not results.Visible
			or acceptancePending()
			or s == nil
			or not s.available
			or s.phase ~= "Completed"
			or s.result == nil
			or player:GetAttribute("ProfileStatus") ~= "Ready"
		then
			return
		end
		results.Visible = false
		local step = player:GetAttribute("OnboardingStep")
		if step == "BUY" or step == "PLACE" then
			homeAction(if step == "BUY" then "Shop" else "Furniture")
		else
			local mastery = Mastery.evaluate(s.paintingXP, s.offers, s.available, s.result.xp)
			stopTravel()
			hideHousing()
			hidePanels()
			homePanel.Visible, jobs.Visible = false, true
			offers.show(mastery.recommendedId)
			render()
		end
	end)
	abandon = Abandon.start(screen, language, function(jobId: string, workId: string)
		command:FireServer({ action = "cancel", jobId = jobId, workId = workId })
	end, function(waiting: boolean)
		jobs.Visible, homePanel.Visible = not waiting, waiting
	end)
	cancel.Activated:Connect(function()
		if
			not jobs.Visible
			or not cancel.Active
			or state == nil
			or state.phase == "Offer"
			or state.phase == "Completed"
		then
			return
		end
		hideHousing()
		hidePanels()
		homePanel.Visible = false
		painter.stop()
		if abandon then
			abandon.ask(state)
		end
	end)
	for index, b in swatches do
		b.Activated:Connect(function()
			local fields: { [string]: unknown } =
				{ color = ({ "rose", Config.colorId, "mint" })[index] }
			send("choose", fields)
		end)
	end
	for index, b in toolButtons do
		b.Activated:Connect(function()
			if b.Active then
				local fields: { [string]: unknown } =
					{ toolId = if index == 1 then "basic" else "wide" }
				send("tool", fields)
			end
		end)
	end
	stateEvent.OnClientEvent:Connect(function(s: Types.Snapshot)
		local old = state
		if old == nil or old.phase ~= s.phase then
			lastError = nil
		end
		if s.error then
			lastError, errorUntil = s.error, os.clock() + 4
			local deadline = errorUntil
			task.delay(4, function()
				if errorUntil == deadline and screen.Parent ~= nil then
					render()
				end
			end)
		end
		state = s
		painter.update(s)
		if s.phase == "Inspect" and old and (old.phase == "Offer" or old.phase == "Completed") then
			hidePanels()
			homePanel.Visible = false
		end
		if s.phase == "ChooseMaterial" and old and old.phase == "SurfaceReady" then
			hidePanels()
			homePanel.Visible = false
			if s.near then
				jobs.Visible = true
			else
				map.show()
			end
		end
		if s.phase == "Painting" and old and old.phase == "ChooseMaterial" then
			local wall = currentWall()
			if wall and s.near then
				hidePanels()
				homePanel.Visible = false
				painter.enter(wall, s)
			end
		end
		local result = s.result
		if result and s.available and result.operationId ~= shownOperation then
			hidePanels()
			homePanel.Visible = false
			resultBody.CanvasPosition = Vector2.zero
			results.Visible = true
			shownOperation = result.operationId
		elseif result == nil then
			results.Visible = false
		end
		render()
		if old == nil or old.phase ~= s.phase or old.workId ~= s.workId then
			revealActions()
		end
	end)
	for _, rootPanel in { jobs, results } do
		for _, item in rootPanel:GetDescendants() do
			if item:IsA("GuiObject") then
				item.ZIndex = 9
			end
		end
	end
	local syncAt = 0
	RunService.RenderStepped:Connect(function()
		local s = state
		local root = if player.Character
			then player.Character:FindFirstChild("HumanoidRootPart")
			else nil
		local travel = travelGoal()
		local goal = travel or Goals.job(s, nearWall)
		local navigating = goal ~= nil
			and player:GetAttribute("ProfileStatus") == "Ready"
			and not painter.isActive()
			and not screen:GetAttribute("Building")
			and not interaction.isVisible()
			and not (abandon and (abandon.isVisible() or abandon.pending()))
		local wall = currentWall()
		local rootPart = if root and root:IsA("BasePart") then root else nil
		local close = s ~= nil
			and s.near
			and wall ~= nil
			and rootPart ~= nil
			and (wall.Position - rootPart.Position).Magnitude <= Config.maxDistance
		if close and s and (s.phase == "Inspect" or s.phase == "Ready") then
			close = s.canTalk == true
		end
		if close ~= nearWall then
			nearWall = close
			render()
		end
		local target = wall
		if wall and s and (s.phase == "Inspect" or s.phase == "Ready") then
			local room = wall.Parent
			local resident = if room then room:FindFirstChild("Resident") else nil
			local torso = if resident then resident:FindFirstChild("Torso") else nil
			if torso and torso:IsA("BasePart") then
				target = torso
			end
		end
		if travel then
			local shop = workspace:FindFirstChild("NeighborhoodShop")
			local counter = if shop then shop:FindFirstChild("Counter") else nil
			target = if counter and counter:IsA("BasePart") then counter else nil
		else
			goal = Goals.job(s, nearWall)
		end
		navigation.update(goal, target, rootPart, navigating, t)
		local home = player:GetAttribute("HomePosition")
		local routePoints, routeIndex = navigation.route()
		map.update(
			rootPart,
			if typeof(home) == "Vector3" then home else nil,
			goal,
			routePoints,
			routeIndex
		)
		interaction.step(painter.isActive() or screen:GetAttribute("Building") == true)
		guide.step(painter.isActive() or screen:GetAttribute("Building") == true)
		if
			(
				navigating
				or jobs.Visible
				or map.isVisible()
				or interaction.isVisible()
				or (abandon and abandon.pending())
				or acceptancePending()
			) and os.clock() - syncAt > 0.75
		then
			syncAt = os.clock()
			send("sync", nil)
			render()
		end
	end)
	player:GetAttributeChangedSignal("ProfileStatus"):Connect(function()
		if player:GetAttribute("ProfileStatus") == "Ready" then
			send("sync", nil)
			render()
		end
	end)
	send("sync", nil)
	return {
		render = render,
		isWorking = painter.isActive,
		suspend = function(): ()
			painter.stop()
			hidePanels()
		end,
		hide = hidePanels,
		show = function(tab: string): ()
			homePanel.Visible = false
			hidePanels()
			if tab == "Jobs" and abandon and abandon.pending() then
				abandon.resume()
				send("sync", nil)
				render()
				return
			end
			jobs.Visible = tab == "Jobs"
			if tab == "Jobs" then
				stopTravel()
				offers.show()
			end
			if tab == "Map" then
				map.show()
			end
			if tab == "Guide" then
				guide.show()
			end
			send("sync", nil)
			render()
		end,
	}
end
return Controller
