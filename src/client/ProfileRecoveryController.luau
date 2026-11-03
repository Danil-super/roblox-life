--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	language: () -> string,
	suspend: () -> (),
	toggleLanguage: () -> ()
)
	local player = Players.LocalPlayer
	local command = RS:WaitForChild("ProfileCommand")
	assert(command:IsA("RemoteEvent"), "ProfileCommand missing")
	local seenError, awaiting, exiting, epoch = false, false, false, 0
	local cameraPending = false
	local panel = Instance.new("Frame")
	panel.Name, panel.Size = "ProfilePanel", UDim2.fromScale(1, 1)
	panel.BackgroundColor3, panel.BackgroundTransparency = Color3.fromRGB(12, 24, 24), 0.12
	panel.BorderSizePixel, panel.Active, panel.Visible, panel.ZIndex = 0, true, false, 30
	panel.Parent = screen
	local card = Instance.new("Frame")
	card.Name, card.AnchorPoint = "Card", Vector2.new(0.5, 0.5)
	card.Position, card.Size = UDim2.fromScale(0.5, 0.5), UDim2.new(1, -24, 1, -24)
	card.BackgroundColor3, card.ZIndex, card.Parent = Color3.fromRGB(26, 43, 43), 31, panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(480, 340), card
	local function label(name: string, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name, l.BackgroundTransparency, l.TextWrapped = name, 1, true
		l.Font, l.TextSize, l.TextColor3 =
			Enum.Font.GothamMedium, size, Color3.fromRGB(244, 239, 224)
		l.ZIndex, l.Parent = 32, card
		return l
	end
	local heading, message = label("Heading", 18), label("Message", 15)
	heading.Position, heading.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -100, 0, 48)
	message.Position, message.Size = UDim2.fromOffset(16, 68), UDim2.new(1, -32, 1, -140)
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size = name, UDim2.new(x, 12, 1, -60), UDim2.new(0.5, -24, 0, 48)
		b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamBold, 15, true
		b.BackgroundColor3, b.TextColor3 =
			Color3.fromRGB(55, 120, 102), Color3.fromRGB(244, 239, 224)
		b.ZIndex, b.Parent = 32, card
		return b
	end
	local retry, exit = button("Retry", 0), button("Exit", 0.5)
	local lang = button("Language", 0)
	lang.Position, lang.Size = UDim2.new(1, -60, 0, 12), UDim2.fromOffset(48, 44)
	lang.Activated:Connect(toggleLanguage)
	local function restoreCamera(): ()
		if not cameraPending or player:GetAttribute("ProfileStatus") ~= "Ready" then
			return
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local paint = screen:FindFirstChild("PaintToolbar")
		if
			humanoid == nil
			or humanoid.Health <= 0
			or screen:GetAttribute("Building")
			or (paint and paint:IsA("GuiObject") and paint.Visible)
		then
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, humanoid
			cameraPending = false
		end
	end
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function render(): ()
		local status = player:GetAttribute("ProfileStatus")
		lang.Text = if language() == "ru" then "EN" else "RU"
		if status == "Error" then
			seenError = true
		end
		local visible = status == "Error" or (seenError and status == "Loading")
		if visible and not panel.Visible then
			suspend()
		end
		panel.Visible = visible
		if not visible then
			if seenError and status == "Ready" then
				cameraPending = true
			end
			seenError, awaiting, exiting = false, false, false
		end
		restoreCamera()
		local loading = status == "Loading" or awaiting
		local allowed = player:GetAttribute("ProfileRecoveryAllowed") == true
		heading.Text = t(if loading then "profileRecoveringTitle" else "profileErrorTitle")
		local rawCode = player:GetAttribute("ProfileErrorCode")
		local code = if type(rawCode) == "string" then rawCode else "Unavailable"
		message.Text = t(if loading then "profileRecovering" else "profileReason" .. code)
		retry.Text = t(
			if loading
				then "profileRetrying"
				elseif not allowed then "profileNoRetry"
				elseif player:GetAttribute("ProfileCanRetry") ~= true then "profileRetryWait"
				else "profileRetry"
		)
		retry.Active = status == "Error"
			and not awaiting
			and allowed
			and player:GetAttribute("ProfileCanRetry") == true
		retry.AutoButtonColor, retry.BackgroundTransparency =
			retry.Active, if retry.Active then 0 else 0.6
		exit.Text, exit.Active = t("profileExit"), not exiting
	end
	retry.Activated:Connect(function()
		if not retry.Active then
			return
		end
		awaiting, epoch = true, epoch + 1
		local attempt = epoch
		render()
		command:FireServer("retry")
		task.delay(10, function()
			if epoch == attempt and screen.Parent ~= nil then
				awaiting = false
				render()
			end
		end)
	end)
	exit.Activated:Connect(function()
		if exiting then
			return
		end
		exiting = true
		render()
		command:FireServer("exit")
	end)
	player:GetAttributeChangedSignal("ProfileStatus"):Connect(function()
		if player:GetAttribute("ProfileStatus") ~= "Loading" then
			awaiting = false
		end
		render()
	end)
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("Humanoid", 15)
		if player.Character == character and screen.Parent ~= nil then
			restoreCamera()
		end
	end)
	for _, name in { "ProfileErrorCode", "ProfileRecoveryAllowed", "ProfileCanRetry" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	render()
	return { render = render }
end
return Controller
