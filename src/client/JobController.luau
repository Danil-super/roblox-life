--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Strings = require(ReplicatedStorage.Shared.Strings)
local Config = require(ReplicatedStorage.Shared.PaintConfig)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local PaintController = require("./PaintController")
local Navigation = require("./JobNavigation")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	homePanel: Frame,
	language: () -> string,
	homeAction: (string) -> ()
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
		Offer = "acceptJob",
		Inspect = "inspectWall",
		Prepare = "protectFloor",
		ChooseMaterial = "choosePaint",
		Painting = "useRoller",
		Ready = "submitJob",
		Completed = "anotherJob",
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
		b.BackgroundColor3 = if colorId == "rose"
			then Color3.fromRGB(211, 160, 158)
			elseif colorId == "mint" then Color3.fromRGB(144, 185, 164)
			else Color3.new(table.unpack(Config.color))
		b.Parent = colors
		table.insert(swatches, b)
	end
	local map, mapHeading, mapBack, mapBody = panel("MapPanel")
	local canvas = Instance.new("Frame")
	canvas.Name = "Block"
	canvas.Position = UDim2.fromOffset(16, 6)
	canvas.Size = UDim2.new(1, -32, 0, 212)
	canvas.BackgroundColor3 = Color3.fromRGB(91, 112, 90)
	canvas.Parent = mapBody
	local road = Instance.new("Frame")
	road.Position = UDim2.fromScale(0, 0.35)
	road.Size = UDim2.fromScale(1, 0.18)
	road.BorderSizePixel = 0
	road.BackgroundColor3 = Color3.fromRGB(70, 77, 78)
	road.Parent = canvas
	local homeMarker = text(canvas, "Home", 155, 32, 14)
	local jobMarker = text(canvas, "Client", 2, 32, 14)
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(12, 12)
	dot.BackgroundColor3 = Color3.fromRGB(245, 197, 98)
	dot.Parent = canvas
	local mapHint = text(mapBody, "Hint", 226, 38, 14)
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
	local painter = PaintController.start(screen, send, language)
	local function hidePanels(): ()
		jobs.Visible = false
		map.Visible = false
	end
	local function returnPhone(): ()
		hidePanels()
		homePanel.Visible = true
	end
	back.Activated:Connect(returnPhone)
	mapBack.Activated:Connect(returnPhone)
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
			send("accept", nil)
		elseif not nearWall then
			homePanel.Visible, jobs.Visible, map.Visible = false, false, true
		elseif s.phase == "ChooseMaterial" then
			homePanel.Visible, map.Visible, jobs.Visible = false, false, true
		elseif s.phase == "Painting" then
			local wall = currentWall()
			if wall then
				hidePanels()
				homePanel.Visible = false
				painter.enter(wall, s)
			end
		else
			local a = ({ Inspect = "inspect", Prepare = "prepare", Ready = "submit" })[s.phase]
			if a then
				send(a, nil)
			end
		end
	end
	local navigation = Navigation.start(screen, activate)
	local function stepHint(phase: string): string
		if lastError and os.clock() < errorUntil then
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
		local hints = {
			Inspect = "inspectHint",
			Prepare = "prepareHint",
			ChooseMaterial = "colorHint",
			Painting = "paintHint",
			Ready = "readyHint",
		}
		return t(hints[phase] or "jobRouteHint")
	end
	local function render(): ()
		local s = state
		local phase = if s then s.phase else "Offer"
		heading.Text = t("jobs")
		mapHeading.Text = t("map")
		back.Text = t("backHome")
		mapBack.Text = t("backHome")
		description.Text = t(phaseKeys[phase] or "jobOffer")
		progress.Text = if phase == "Offer"
			then "$" .. (if s then s.reward else 0)
			elseif phase == "Completed" then "+$" .. (if s then s.reward else 0)
			else string.format(
				"%d%%",
				math.floor((if s then s.count else 0) / (Config.columns * Config.rows) * 100)
			)
		hint.Text = stepHint(phase)
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
		homeMarker.Text = "⌂ " .. t("home")
		jobMarker.Text = if s and s.destination
			then "◆ " .. t("clientApartment")
			else t("noActiveRoute")
		mapHint.Text = t("mapHint")
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
	stateEvent.OnClientEvent:Connect(function(s: Types.Snapshot)
		local old = state
		if old == nil or old.phase ~= s.phase then
			lastError = nil
		end
		if s.error then
			lastError, errorUntil = s.error, os.clock() + 4
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
		render()
	end)
	for _, rootPanel in { jobs, map } do
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
		local wall = currentWall()
		local rootPart = if root and root:IsA("BasePart") then root else nil
		local close = s ~= nil
			and s.near
			and wall ~= nil
			and rootPart ~= nil
			and (wall.Position - rootPart.Position).Magnitude <= Config.maxDistance
		if close ~= nearWall then
			nearWall = close
			render()
		end
		navigation.update(s, wall, rootPart, navigating, nearWall, t)
		if root and root:IsA("BasePart") then
			local home = player:GetAttribute("HomePosition")
			if typeof(home) == "Vector3" then
				dot.Position = UDim2.fromScale(
					math.clamp(0.5 + (root.Position.X - home.X) / 60, 0.03, 0.97),
					math.clamp(0.8 - (root.Position.Z - home.Z) / 100, 0.03, 0.97)
				)
			end
		end
		if (navigating or jobs.Visible) and os.clock() - syncAt > 0.75 then
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
		hide = hidePanels,
		show = function(tab: string): ()
			homePanel.Visible = false
			hidePanels()
			jobs.Visible = tab == "Jobs"
			map.Visible = tab == "Map"
			send("sync", nil)
			render()
		end,
	}
end
return Controller
