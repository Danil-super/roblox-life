--!strict
local Players = game:GetService("Players")
local ProfileService = require("./ProfileService")
local Use = require("./Domain/HomeUse")
local RoomRules = require("./Domain/RoomRules")
local Lights = {}
function Lights.attach(model: Model, owner: Player, profiles: ProfileService.API): ()
	if model:GetAttribute("CatalogId") ~= "floor-lamp-v1" then
		return
	end
	local switch = model:FindFirstChild("Switch")
	local light = model:FindFirstChild("LampLight", true)
	if
		switch == nil
		or not switch:IsA("BasePart")
		or light == nil
		or not light:IsA("PointLight")
		or switch:FindFirstChild("ToggleHomeLight")
	then
		return
	end
	local function setOn(value: boolean): ()
		light.Enabled = value
		model:SetAttribute("LightOn", value)
		switch.Color = if value then Color3.fromRGB(242, 205, 111) else Color3.fromRGB(61, 72, 73)
		switch.Material = if value then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	setOn(true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ToggleHomeLight"
	prompt.ActionText, prompt.ObjectText = "Turn off", "Floor lamp"
	prompt.AutoLocalize = false
	prompt.MaxActivationDistance, prompt.HoldDuration = 8, 0
	prompt.RequiresLineOfSight, prompt.ClickablePrompt = true, true
	prompt.KeyboardKeyCode, prompt.Exclusivity =
		Enum.KeyCode.E, Enum.ProximityPromptExclusivity.OnePerButton
	local lastAt = -math.huge
	prompt.Triggered:Connect(function(actor: Player)
		if actor ~= owner or actor.Parent ~= Players then
			return
		end
		local now = os.clock()
		if now - lastAt < 0.5 then
			return
		end
		lastAt = now
		local p, home = profiles.read(actor), profiles.home(actor)
		local character = actor.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if home == nil or character == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		local folder = home.model:FindFirstChild("Furniture")
		if
			folder == nil
			or model.Parent ~= folder
			or folder:FindFirstChild(model.Name) ~= model
			or model:GetAttribute("OwnerUserId") ~= actor.UserId
			or home.model:GetAttribute("OwnerUserId") ~= actor.UserId
		then
			return
		end
		local item = if p then p.inventory[model.Name] else nil
		local position = root.Position - home.origin
		local ray = RaycastParams.new()
		ray.FilterType, ray.FilterDescendantsInstances =
			Enum.RaycastFilterType.Exclude, { character }
		local target = switch.Position - root.Position
		if target.Magnitude ~= target.Magnitude or target.Magnitude > 8 then
			return
		end
		local hit = workspace:Raycast(root.Position, target, ray)
		if
			not Use.allowed({
				ownerId = owner.UserId,
				actorId = actor.UserId,
				available = p ~= nil,
				alive = character:IsDescendantOf(workspace)
					and humanoid ~= nil
					and humanoid.Health > 0,
				inside = RoomRules.contains(position.X, position.Y, position.Z),
				owned = item ~= nil,
				placed = p ~= nil and p.housing.placements[model.Name] ~= nil,
				visible = hit == nil or hit.Instance:IsDescendantOf(model),
				distance = target.Magnitude,
				catalogId = if item then item.catalogItemId else "",
			})
		then
			return
		end
		-- Cosmetic session state only; no yielding or profile mutation.
		setOn(not light.Enabled)
	end)
	prompt.Parent = switch
end
return Lights
