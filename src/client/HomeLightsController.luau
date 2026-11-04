--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Controller = {}
function Controller.start(screen: ScreenGui, language: () -> string): { render: () -> () }
	local player = Players.LocalPlayer
	local homes = workspace:WaitForChild("Homes")
	local prompts: { [ProximityPrompt]: Model } = {}
	local records: { [ProximityPrompt]: { RBXScriptConnection } } = {}
	local connections: { RBXScriptConnection } = {}
	local death: RBXScriptConnection? = nil
	local stopped = false
	local function render(): ()
		if stopped then
			return
		end
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local ready = screen.Enabled
			and screen:GetAttribute("ModalOpen") ~= true
			and player:GetAttribute("ProfileStatus") == "Ready"
			and char ~= nil
			and char:IsDescendantOf(workspace)
			and hum ~= nil
			and hum.Health > 0
		for prompt, model in prompts do
			prompt.Enabled = ready and model:GetAttribute("OwnerUserId") == player.UserId
			prompt.ObjectText = Strings.text(language(), "floor-lamp-v1")
			prompt.ActionText = Strings.text(
				language(),
				if model:GetAttribute("LightOn") == true then "lightOff" else "lightOn"
			)
		end
	end
	local function track(instance: Instance): ()
		if
			not instance:IsA("ProximityPrompt")
			or instance.Name ~= "ToggleHomeLight"
			or prompts[instance]
		then
			return
		end
		local model = instance:FindFirstAncestorOfClass("Model")
		if model == nil then
			return
		end
		prompts[instance] = model
		records[instance] = {
			model:GetAttributeChangedSignal("LightOn"):Connect(render),
			model:GetAttributeChangedSignal("OwnerUserId"):Connect(render),
			instance.AncestryChanged:Connect(function()
				if not instance:IsDescendantOf(homes) then
					prompts[instance] = nil
					local bound = records[instance]
					records[instance] = nil
					if bound then
						for _, c in bound do
							c:Disconnect()
						end
					end
				end
			end),
		}
		render()
	end
	local function characterAdded(char: Model): ()
		if death then
			death:Disconnect()
			death = nil
		end
		local hum = char:WaitForChild("Humanoid", 10)
		if not stopped and player.Character == char and hum and hum:IsA("Humanoid") then
			death = hum.Died:Connect(render)
			render()
		end
	end
	table.insert(connections, homes.DescendantAdded:Connect(track))
	table.insert(connections, player:GetAttributeChangedSignal("ProfileStatus"):Connect(render))
	table.insert(connections, screen:GetAttributeChangedSignal("ModalOpen"):Connect(render))
	table.insert(connections, screen:GetPropertyChangedSignal("Enabled"):Connect(render))
	table.insert(connections, player.CharacterAdded:Connect(characterAdded))
	for _, instance in homes:GetDescendants() do
		track(instance)
	end
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
	screen.Destroying:Once(function()
		stopped = true
		if death then
			death:Disconnect()
		end
		for _, c in connections do
			c:Disconnect()
		end
		for prompt, bound in records do
			prompt.Enabled = false
			for _, c in bound do
				c:Disconnect()
			end
		end
	end)
	return { render = render }
end
return Controller
