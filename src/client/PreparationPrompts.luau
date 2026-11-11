--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Controller = {}
function Controller.start(screen: ScreenGui, language: () -> string): { render: () -> () }
	local player = Players.LocalPlayer
	local homes = workspace:WaitForChild("Homes")
	local tracked: { [ProximityPrompt]: BasePart } = {}
	local cleared: { [ProximityPrompt]: RBXScriptConnection } = {}
	local disposed = false
	local function render(): ()
		if disposed then
			return
		end
		for prompt, part in tracked do
			prompt.Enabled = screen.Enabled
				and screen:GetAttribute("ModalOpen") ~= true
				and player:GetAttribute("ProfileStatus") == "Ready"
				and part:GetAttribute("OwnerUserId") == player.UserId
				and part:GetAttribute("Cleared") ~= true
			prompt.ActionText, prompt.ObjectText =
				Strings.text(language(), "scrapeAction"), Strings.text(language(), "oldFinish")
		end
	end
	local function track(instance: Instance): ()
		if
			instance:IsA("ProximityPrompt")
			and instance.Name == "ScrapeOldFinish"
			and not tracked[instance]
		then
			local part = instance.Parent
			if part and part:IsA("BasePart") then
				tracked[instance] = part
				cleared[instance] = part.AttributeChanged:Connect(render)
				render()
			end
		end
	end
	local connections = {
		homes.DescendantAdded:Connect(track),
		homes.DescendantRemoving:Connect(function(instance: Instance)
			if instance:IsA("ProximityPrompt") then
				tracked[instance] = nil
				local connection = cleared[instance]
				if connection then
					connection:Disconnect()
					cleared[instance] = nil
				end
			end
		end),
		screen:GetAttributeChangedSignal("ModalOpen"):Connect(render),
		screen:GetPropertyChangedSignal("Enabled"):Connect(render),
		player:GetAttributeChangedSignal("ProfileStatus"):Connect(render),
	}
	for _, instance in homes:GetDescendants() do
		track(instance)
	end
	screen.Destroying:Once(function()
		disposed = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, connection in cleared do
			connection:Disconnect()
		end
		cleared = {}
		tracked = {}
	end)
	return { render = render }
end
return Controller
