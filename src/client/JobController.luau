--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Strings = require(ReplicatedStorage.Shared.Strings)
local Config = require(ReplicatedStorage.Shared.PaintConfig)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local PaintController = require("./PaintController")
local Navigation = require("./JobNavigation")
local MapController = require("./MapController")
local JobOffers = require("./JobOffersController")
local ClientInteraction = require("./ClientInteractionController")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	homePanel: Frame,
	language: () -> string,
	homeAction: (string) -> (),
	hideHousing: () -> ()
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
		Ready = "handoverClient",
		Completed = "openJobs",
	}
	local phaseKeys = {
		Inspect = "jobInspect",
		Prepare = "jobPrepare",
		ChooseMaterial = "jobColor",
		Painting = "jobPaint",
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
	resultBody.CanvasSize = UDim2.fromOffset(0, 240)
	local resultClose = button(results, "Close", 12)
	resultClose.Position = UDim2.new(1, -60, 0, 12)
	resultClose.Size = UDim2.fromOffset(44, 44)
	resultClose.Text = "×"
	local before = text(resultBody, "Before", 0, 48, 13)
	before.Size = UDim2.new(0.5, -20, 0, 48)
	before.BackgroundTransparency = 0
	before.BackgroundColor3 = Color3.fromRGB(145, 148, 140)
	before.TextColor3 = Color3.fromRGB(26, 43, 43)
	local after = text(resultBody, "After", 0, 48, 13)
	after.Position = UDim2.new(0.5, 4, 0, 0)
	after.Size = UDim2.new(0.5, -20, 0, 48)
	after.BackgroundTransparency = 0
	after.BackgroundColor3 = Color3.new(table.unpack(Config.color))
	after.TextColor3 = Color3.fromRGB(26, 43, 43)
	local resultMoney = text(resultBody, "Dollars", 56, 32, 24)
	local resultXP = text(resultBody, "XP", 92, 28, 16)
	local resultQuality = text(resultBody, "Quality", 124, 44, 13)
	local resultHint = text(resultBody, "Hint", 176, 56, 13)
	local shownOperation: string? = nil
	resultClose.Activated:Connect(function()
		results.Visible = false
	end)
	resultContinue.Activated:Connect(function()
		results.Visible = false
		local step = player:GetAttribute("OnboardingStep")
		if step == "BUY" or step == "PLACE" then
			homeAction(if step == "BUY" then "Shop" else "Furniture")
		end
	end)
	local function send(actionName: string, fields: { [string]: unknown }?): ()
		local data: { [string]: unknown } = fields or {}
		data.action = actionName
		local s = state
		if s then
			data.jobId = s.jobId
			data.workId = s.workId
		end
		command:FireServer(data)
	end
	local offers = JobOffers.start(jobs, jobBody, back, language, function(id: string)
		local fields: { [string]: unknown } = { offerId = id }
		send("accept", fields)
	end)
	local painter = PaintController.start(screen, send, language)
	local interaction: ClientInteraction.API
	local function hidePanels(): ()
		jobs.Visible = false
		map.hide()
		results.Visible = false
		interaction.hide()
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
		local wall = if room then room:FindFirstChild("PaintableWall") else nil
		return if wall and wall:IsA("BasePart") then wall else nil
	end
	local function activate(): ()
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
			local a = ({ Inspect = "talk", Prepare = "prepare", Ready = "talk" })[s.phase]
			if a then
				send(a, nil)
			end
		end
	end
	interaction = ClientInteraction.start(screen, language, function()
		hideHousing()
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
			return t("offerHint")
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
			Ready = "handoverClientHint",
		}
		return t(hints[phase] or "jobRouteHint")
	end
	local function render(): ()
		local s = state
		interaction.render(s)
		local phase = if s then s.phase else "Offer"
		heading.Text = t("jobs")
		back.Text = t("backHome")
		description.Text = t(phaseKeys[phase] or "jobOffer")
		if phase == "ChooseMaterial" then
			description.Text ..= "\n" .. stepHint(phase)
		end
		progress.Text = if phase == "Offer"
			then "$" .. (if s then s.reward else 0)
			elseif phase == "Completed" then "+$" .. (if s then s.reward else 0)
			else string.format(
				"%d%%",
				math.floor((if s then s.count else 0) / (Config.columns * Config.rows) * 100)
			)
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
		colors.Visible = phase == "ChooseMaterial"
		action.Visible = not colors.Visible
		action.Text = t(actions[phase] or "acceptJob")
		action.Active = s ~= nil and s.available
		action.AutoButtonColor = action.Active
		for index, b in swatches do
			b.Text = t(({ "rose", "warmWhite", "mint" })[index])
			b.Active = s ~= nil and s.available
		end
		map.render(s)
		offers.render(s)
		painter.render()
		local onboarding = player:GetAttribute("OnboardingStep")
		local nextKey = if phase == "Completed" and onboarding == "BUY"
			then "shopTitle"
			elseif phase == "Completed" and onboarding == "PLACE" then "furnitureApp"
			else actions[phase] or "openJobs"
		navigation.render(
			t(if s and s.destination and not nearWall then "openMap" else nextKey),
			s ~= nil and s.available
		)
		action.Text = t(nextKey)
		resultHeading.Text = t("resultTitle")
		before.Text, after.Text = t("resultBefore"), t("resultAfter")
		local receipt = if s then s.result else nil
		resultMoney.Text = if receipt then string.format("+$%d", receipt.dollars) else ""
		resultXP.Text = if receipt then string.format(t("resultXP"), receipt.xp) else ""
		resultQuality.Text = t("resultAccepted")
		resultHint.Text = t("resultNext")
		if
			receipt
			and s
			and s.paintingXP
			and s.paintingXP >= Config.wideRollerXP
			and s.paintingXP - receipt.xp < Config.wideRollerXP
		then
			resultHint.Text = t("wideUnlockedResult") .. "\n" .. resultHint.Text
		end
		local required = if s then s.requiredColorId or Config.colorId else Config.colorId
		after.BackgroundColor3 = Color3.new(table.unpack(Config.palette[required] or Config.color))
		resultContinue.Text = t(
			if onboarding == "BUY"
				then "shopTitle"
				elseif onboarding == "PLACE" then "furnitureApp"
				else "resultContinue"
		)
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
					if s
							and s.destination
							and not nearWall
						then "goToClient"
						else phaseKeys[phase] or "jobOffer"
				)
			end
			if detail and detail:IsA("TextLabel") then
				detail.Text = stepHint(phase)
			end
		end
	end
	action.Activated:Connect(activate)
	cancel.Activated:Connect(function()
		send("cancel", nil)
		painter.stop()
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
			results.Visible = true
			shownOperation = result.operationId
		elseif result == nil then
			results.Visible = false
		end
		render()
		if old == nil or old.phase ~= s.phase then
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
		local destination = if s then s.destination else nil
		local navigating = s ~= nil
			and destination ~= nil
			and s.phase ~= "Offer"
			and s.phase ~= "Completed"
			and not painter.isActive()
			and not screen:GetAttribute("Building")
			and not interaction.isVisible()
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
		navigation.update(s, target, rootPart, navigating, nearWall, t)
		local home = player:GetAttribute("HomePosition")
		map.update(rootPart, if typeof(home) == "Vector3" then home else nil, s)
		interaction.step(painter.isActive() or screen:GetAttribute("Building") == true)
		if
			(navigating or jobs.Visible or map.isVisible() or interaction.isVisible())
			and os.clock() - syncAt > 0.75
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
		suspend = function(): ()
			painter.stop()
			hidePanels()
		end,
		hide = hidePanels,
		show = function(tab: string): ()
			homePanel.Visible = false
			hidePanels()
			jobs.Visible = tab == "Jobs"
			if tab == "Jobs" then
				offers.show()
			end
			if tab == "Map" then
				map.show()
			end
			send("sync", nil)
			render()
		end,
	}
end
return Controller
