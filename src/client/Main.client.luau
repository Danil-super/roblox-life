--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local JobController = require("./JobController")
local HomeController = require("./HomeController")
local ModalControls = require("./ModalControls")
local ProfileRecovery = require("./ProfileRecoveryController")
local HomeLights = require("./HomeLightsController")
local Strings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Strings"))
local Layout = require(ReplicatedStorage.Shared.HudLayout)
local Theme = require(ReplicatedStorage.Shared.Theme)
local InputConfig = require(ReplicatedStorage.Shared.InputConfig)
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("ReturnHome")
assert(remote:IsA("RemoteEvent"), "ReturnHome remote missing")
local language = if string.sub(player.LocaleId, 1, 2) == "ru" then "ru" else "en"
local dollars: IntValue? = nil
local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
local background = color(Theme.colors.ink)
local paper = color(Theme.colors.paper)
local muted = color(Theme.colors.muted)
local accent = color(Theme.colors.accent)

local screen = Instance.new("ScreenGui")
screen.Name = "NeighborhoodHUD"
screen.ResetOnSpawn = false
screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

local function round(parent: GuiObject, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end
local function text(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	fontSize: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name, label.Position, label.Size = name, position, size
	label.BackgroundTransparency = 1
	label.TextColor3 = paper
	label.Font = Enum.Font.GothamMedium
	label.TextSize, label.TextWrapped = fontSize, true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end
local function button(parent: Instance, name: string, position: UDim2, size: UDim2): TextButton
	local item = Instance.new("TextButton")
	item.Name, item.Position, item.Size = name, position, size
	item.BackgroundColor3, item.TextColor3 = accent, paper
	item.TextSize, item.Font = 16, Enum.Font.GothamMedium
	item.AutoButtonColor = true
	item.Parent = parent
	round(item, 12)
	return item
end
local function card(name: string, position: UDim2, size: UDim2): Frame
	local item = Instance.new("Frame")
	item.Name, item.Position, item.Size = name, position, size
	item.BackgroundColor3, item.BackgroundTransparency = background, 0.05
	item.Parent = screen
	round(item, 16)
	return item
end

local wallet = card("Wallet", UDim2.fromOffset(16, 12), UDim2.fromOffset(184, 76))
local title = text(wallet, "Title", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18), 10)
title.TextColor3 = muted
local balance = text(wallet, "Dollars", UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 36), 28)
local languageButton =
	button(screen, "Language", UDim2.new(1, -86, 0, 12), UDim2.fromOffset(70, 44))
local homeButton = button(screen, "Home", UDim2.new(1, -104, 1, -68), UDim2.fromOffset(88, 52))

local objective = card("Objective", UDim2.new(0, 16, 1, -172), UDim2.new(1, -136, 0, 156))
local objectiveLimit = Instance.new("UISizeConstraint")
objectiveLimit.MaxSize = Vector2.new(520, 156)
objectiveLimit.Parent = objective
local objectiveTitle =
	text(objective, "Title", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 25), 16)
local objectiveHint =
	text(objective, "Hint", UDim2.fromOffset(14, 35), UDim2.new(1, -28, 0, 48), 13)
objectiveHint.TextColor3 = muted

local panel = card("HomePanel", UDim2.fromScale(0.5, 0.5), UDim2.new(1, -32, 1, -24))
panel.AnchorPoint, panel.Visible = Vector2.new(0.5, 0.5), false
panel.ZIndex = 5
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(480, 388)
panelLimit.Parent = panel
local heading = text(panel, "Heading", UDim2.fromOffset(20, 18), UDim2.new(1, -88, 0, 36), 23)
local closeButton = button(panel, "Close", UDim2.new(1, -64, 0, 16), UDim2.fromOffset(44, 44))
closeButton.Text = "×"
local private = text(panel, "Private", UDim2.fromOffset(20, 62), UDim2.new(1, -40, 0, 38), 13)
private.TextColor3 = muted
local apps = Instance.new("ScrollingFrame")
apps.Name = "Apps"
apps.Position = UDim2.fromOffset(0, 104)
apps.Size = UDim2.new(1, 0, 1, -184)
apps.CanvasSize = UDim2.fromOffset(0, 348)
apps.BackgroundTransparency = 1
apps.BorderSizePixel = 0
apps.ScrollBarThickness = 4
apps.Parent = panel
local description =
	text(apps, "Description", UDim2.fromOffset(20, 268), UDim2.new(1, -40, 0, 38), 13)
local status = text(apps, "Storage", UDim2.fromOffset(20, 310), UDim2.new(1, -40, 0, 36), 13)
status.TextColor3 = muted
local returnButton = button(panel, "ReturnHome", UDim2.new(0, 20, 1, -72), UDim2.new(1, -40, 0, 52))
local jobsButton = button(apps, "Jobs", UDim2.fromOffset(20, 0), UDim2.new(0.5, -24, 0, 44))
local mapButton = button(apps, "Map", UDim2.new(0.5, 4, 0, 0), UDim2.new(0.5, -24, 0, 44))
local shopButton = button(apps, "Shop", UDim2.fromOffset(20, 52), UDim2.new(0.5, -24, 0, 44))
local furnitureButton =
	button(apps, "Furniture", UDim2.new(0.5, 4, 0, 52), UDim2.new(0.5, -24, 0, 44))
local roomButton = button(apps, "RoomPlan", UDim2.fromOffset(20, 104), UDim2.new(1, -40, 0, 44))
local guideButton = button(apps, "Guide", UDim2.fromOffset(20, 156), UDim2.new(1, -40, 0, 44))
local hintsButton = button(apps, "Hints", UDim2.fromOffset(20, 208), UDim2.new(1, -40, 0, 44))
local openHousing: (string) -> () = function(_tab: string): () end
local hideHousing: () -> () = function(): () end
local jobs = JobController.start(screen, panel, function(): string
	return language
end, function(tab: string): ()
	openHousing(tab)
end, function()
	hideHousing()
end)
local housing = HomeController.start(screen, panel, function(): string
	return language
end, jobs.hide)
openHousing = function(tab: string): ()
	housing.show(tab)
end
hideHousing = function(): ()
	housing.hide()
end
local toggleLanguage: () -> () = function(): () end
local recovery = ProfileRecovery.start(screen, function(): string
	return language
end, function()
	jobs.suspend()
	housing.hide()
	panel.Visible = false
end, function()
	toggleLanguage()
end)
ModalControls.start(screen)
local homeLights = HomeLights.start(screen, function(): string
	return language
end)
jobsButton.Activated:Connect(function()
	housing.hide()
	jobs.show("Jobs")
end)
mapButton.Activated:Connect(function()
	housing.hide()
	jobs.show("Map")
end)
shopButton.Activated:Connect(function()
	housing.show("Shop")
end)
furnitureButton.Activated:Connect(function()
	housing.show("Furniture")
end)
roomButton.Activated:Connect(function()
	housing.show("Room")
end)
guideButton.Activated:Connect(function()
	housing.hide()
	jobs.show("Guide")
end)
for _, child in panel:GetDescendants() do
	if child:IsA("GuiObject") then
		child.ZIndex = 6
	end
end

local function phoneCaption(): string
	return Strings.text(language, "home")
		.. (if UIS.TouchEnabled then "" else " [" .. InputConfig.phoneKey .. "]")
end
local function render(): ()
	local state = player:GetAttribute("ProfileStatus")
	local ready = state == "Ready"
	local function t(key: string): string
		return Strings.text(language, key)
	end
	title.Text, heading.Text, private.Text = t("title"), t("room"), t("private")
	balance.Text = if dollars ~= nil and (ready or state == "Saving")
		then string.format("$%d", dollars.Value)
		else "$—"
	languageButton.Text = if language == "ru" then "EN" else "RU"
	homeButton.Text, returnButton.Text = phoneCaption(), t("returnHome")
	description.Text = if ready
		then t("roomInfo")
		elseif state == "Error" then t("error")
		else t("loading")
	status.Text =
		t(if player:GetAttribute("StorageMode") == "Preview" then "preview" else "persistent")
	objectiveTitle.Text = if ready
		then t("objective")
		elseif state == "Error" then t("error")
		else t("loading")
	objectiveHint.Text = if ready then t("hint") else status.Text
	returnButton.Active, returnButton.AutoButtonColor = ready, ready
	returnButton.BackgroundTransparency = if ready then 0 else 0.6
	jobsButton.Text, mapButton.Text = t("jobs"), t("map")
	jobs.render()
	shopButton.Text, furnitureButton.Text = t("shopTitle"), t("furnitureApp")
	roomButton.Text = t("roomPlan")
	guideButton.Text = t("firstSteps")
	hintsButton.Text =
		t(if screen:GetAttribute("ShowHints") == false then "showHints" else "hideHints")
	housing.render()
	recovery.render()
	homeLights.render()
end
local function togglePhone(): ()
	if
		player:GetAttribute("ProfileStatus") ~= "Ready"
		or screen:GetAttribute("Building") == true
		or jobs.isWorking()
	then
		return
	end
	jobs.hide()
	housing.hide()
	panel.Visible = not panel.Visible
end
homeButton.Activated:Connect(togglePhone)
UIS.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or UIS:GetFocusedTextBox() ~= nil then
		return
	end
	if input.KeyCode.Name == InputConfig.phoneKey then
		togglePhone()
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
toggleLanguage = function(): ()
	language = if language == "ru" then "en" else "ru"
	render()
end
languageButton.Activated:Connect(toggleLanguage)
local lastReturn = -math.huge
returnButton.Activated:Connect(function()
	if player:GetAttribute("ProfileStatus") ~= "Ready" or os.clock() - lastReturn < 2 then
		return
	end
	lastReturn = os.clock()
	remote:FireServer()
	panel.Visible = false
end)
local function place(gui: GuiObject, rect: Layout.Rect): ()
	gui.AnchorPoint = Vector2.zero
	gui.Position = UDim2.fromOffset(rect.x, rect.y)
	gui.Size = UDim2.fromOffset(rect.w, rect.h)
end
local function resize(): ()
	local size = screen.AbsoluteSize
	if size.X < 280 or size.Y < 240 then
		return
	end
	local touch = UIS.TouchEnabled
	homeButton.Text = phoneCaption()
	local ready = player:GetAttribute("ProfileStatus") == "Ready"
	local hints = screen:GetAttribute("ShowHints") ~= false
		or screen:GetAttribute("JobHintError") == true
	local layout = Layout.compute(size.X, size.Y, touch, ready, hints)
	place(wallet, layout.wallet)
	place(languageButton, layout.language)
	place(homeButton, layout.home)
	objectiveLimit.MaxSize = Vector2.new(layout.objective.w, layout.objective.h)
	place(objective, layout.objective)
	title.Visible = not touch
	balance.Position = UDim2.fromOffset(14, if touch then 8 else 28)
	balance.Size = if touch then UDim2.new(1, -28, 1, -16) else UDim2.new(1, -28, 0, 36)
	balance.TextSize = if touch then 24 else 28
	objectiveTitle.Visible = not layout.minimal
	objectiveTitle.TextSize = if layout.compact then 14 else 16
	objectiveTitle.Size =
		UDim2.new(1, -28, 0, if not ready then 100 elseif layout.compact then 36 else 25)
	objectiveHint.Visible = layout.hintVisible
	local action = objective:FindFirstChild("NextAction")
	if action and action:IsA("GuiObject") then
		action.Visible = ready
		action.Position =
			UDim2.fromOffset(14, if layout.minimal then 8 elseif layout.compact then 48 else 92)
		action.Size = UDim2.new(1, -28, 0, if layout.compact then Theme.touchTarget else 48)
	end
	local routes: { [string]: Layout.Rect } =
		{ JobNavigation = layout.navigation, ShopRoute = layout.shopRoute }
	for name, rect in routes do
		local gui = screen:FindFirstChild(name)
		if gui and gui:IsA("GuiObject") then
			place(gui, rect)
		end
	end
end
screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
hintsButton.Activated:Connect(function()
	screen:SetAttribute("ShowHints", screen:GetAttribute("ShowHints") == false)
	render()
	resize()
end)
screen:GetAttributeChangedSignal("JobHintError"):Connect(resize)
UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(resize)
resize()
player:GetAttributeChangedSignal("ProfileStatus"):Connect(render)
player:GetAttributeChangedSignal("ProfileStatus"):Connect(resize)
player:GetAttributeChangedSignal("StorageMode"):Connect(render)
render()
-- A rejected profile deliberately has no leaderstats. Observe optional replication
-- without leaving a waiting coroutine behind on the error screen.
local dollarsChanged: RBXScriptConnection? = nil
local function bindDollars(value: Instance): ()
	if value.Name ~= "Dollars" or not value:IsA("IntValue") or dollars == value then
		return
	end
	if dollarsChanged then
		dollarsChanged:Disconnect()
	end
	dollars = value
	dollarsChanged = value:GetPropertyChangedSignal("Value"):Connect(render)
	render()
end
local function bindStats(stats: Instance): ()
	if stats.Name ~= "leaderstats" or not stats:IsA("Folder") then
		return
	end
	stats.ChildAdded:Connect(bindDollars)
	local value = stats:FindFirstChild("Dollars")
	if value then
		bindDollars(value)
	end
end
player.ChildAdded:Connect(bindStats)
local stats = player:FindFirstChild("leaderstats")
if stats then
	bindStats(stats)
end
