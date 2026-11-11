--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local Input = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local Strings = require(RS.Shared.Strings)
local Tool = require("./PreparationTool")
local Controller = {}
function Controller.start(screen: ScreenGui, language: () -> string): { render: () -> () }
	local player = Players.LocalPlayer
	local homes = workspace:WaitForChild("Homes")
	local tracked: { [ProximityPrompt]: BasePart } = {}
	local cleared: { [ProximityPrompt]: RBXScriptConnection } = {}
	local disposed = false
	local active: ProximityPrompt? = nil
	local tool: Tool.API? = nil
	local death: RBXScriptConnection? = nil
	local function stop(): ()
		active = nil
		if death then
			death:Disconnect()
			death = nil
		end
		if tool then
			tool.destroy()
			tool = nil
		end
	end
	local function motion(): boolean
		return screen:GetAttribute("LightPaintEffects") ~= true and not Gui.ReducedMotionEnabled
	end
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
		if active and (not active.Enabled or active.Parent ~= tracked[active]) then
			stop()
		elseif tool and not motion() then
			tool.freeze()
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
				if instance == active then
					stop()
				end
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
		screen:GetAttributeChangedSignal("LightPaintEffects"):Connect(render),
		Gui:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(render),
		Input.WindowFocusReleased:Connect(stop),
		player.CharacterRemoving:Connect(stop),
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(stop),
		Prompts.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, actor: Player)
			local patch: BasePart? = tracked[prompt]
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if
				disposed
				or actor ~= player
				or patch == nil
				or not prompt.Enabled
				or prompt.Parent ~= patch
				or prompt == active
				or workspace.CurrentCamera == nil
				or character == nil
				or not character:IsDescendantOf(workspace)
				or humanoid == nil
				or humanoid.Health <= 0
			then
				return
			end
			stop()
			active = prompt
			tool = Tool.new(workspace.CurrentCamera, patch, motion())
			death = humanoid.Died:Connect(stop)
		end),
		Prompts.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, actor: Player)
			if prompt == active and actor == player then
				stop()
			end
		end),
		Prompts.PromptTriggered:Connect(function(prompt: ProximityPrompt, actor: Player)
			if prompt == active and actor == player then
				stop()
			end
		end),
		Prompts.PromptHidden:Connect(function(prompt: ProximityPrompt)
			if prompt == active then
				stop()
			end
		end),
	}
	for _, instance in homes:GetDescendants() do
		track(instance)
	end
	screen.Destroying:Once(function()
		disposed = true
		stop()
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
