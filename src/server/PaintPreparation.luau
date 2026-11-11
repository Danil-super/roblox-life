--!strict
local Painting = require("./Domain/Painting")
export type API = { update: (Painting.State?, string, boolean) -> () }
local Scene = {}
function Scene.attach(
	room: Model,
	owner: Player,
	read: () -> Painting.State?,
	changed: () -> ()
): API
	local folder: Folder? = nil
	local current: Painting.State? = nil
	local parts: { Part } = {}
	local prompts: { ProximityPrompt } = {}
	local function clear(): ()
		if folder then
			folder:Destroy()
		end
		folder, current = nil, nil
		parts, prompts = {}, {}
	end
	local function allowed(actor: Player, patch: Part, work: Painting.State): boolean
		if actor ~= owner or read() ~= work or work.phase ~= "Prepare" or patch.Parent == nil then
			return false
		end
		local char = actor.Character
		if char == nil then
			return false
		end
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return false
		end
		local direction = patch.Position - root.Position
		if direction.Magnitude ~= direction.Magnitude or direction.Magnitude > 8 then
			return false
		end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { char }
		return workspace:Raycast(root.Position, direction, filter) == nil
	end
	return {
		update = function(work: Painting.State?, phase: string, available: boolean): ()
			if
				work == nil
				or phase ~= "Prepare"
				or work.preparationRequired == 0
				or not available
			then
				clear()
				return
			end
			if current ~= work then
				clear()
				local wall = room:FindFirstChild("PaintableWall")
				if wall == nil or not wall:IsA("BasePart") then
					return
				end
				local container = Instance.new("Folder")
				container.Name, container.Parent = "WallPreparation", room
				folder, current = container, work
				for i = 1, 3 do
					local patch = Instance.new("Part")
					patch.Name = "OldFinish" .. i
					patch.Size = Vector3.new(wall.Size.X * 0.22, wall.Size.Y * 0.45, 0.06)
					patch.CFrame = wall.CFrame
						* CFrame.new((i - 2) * wall.Size.X * 0.29, 0, wall.Size.Z / 2 + 0.05)
					patch.Color, patch.Material = Color3.fromRGB(117, 90, 72), Enum.Material.Slate
					patch.Anchored, patch.CanCollide, patch.CanTouch, patch.CanQuery, patch.CastShadow =
						true, false, false, false, false
					patch:SetAttribute("OwnerUserId", owner.UserId)
					patch.Parent = container
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name, prompt.ActionText, prompt.ObjectText =
						"ScrapeOldFinish",
						"Scrape / Очистить",
						"Old finish / Старая отделка"
					prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight =
						0.8, 8, true
					prompt.Parent = patch
					local character: Model? = nil
					prompt.PromptButtonHoldBegan:Connect(function(actor: Player)
						if
							Painting.beginPreparation(
								work,
								i,
								os.clock(),
								allowed(actor, patch, work)
							)
						then
							character = actor.Character
						end
					end)
					prompt.Triggered:Connect(function(actor: Player)
						if
							actor.Character == character
							and Painting.finishPreparation(
								work,
								i,
								os.clock(),
								allowed(actor, patch, work)
							)
						then
							changed()
						end
					end)
					table.insert(parts, patch)
					table.insert(prompts, prompt)
				end
			end
			for i, patch in parts do
				local cleared = work.prepared[i] == true
				patch.Transparency = if cleared then 1 else 0
				patch:SetAttribute("Cleared", cleared)
				prompts[i].Enabled = not cleared
			end
		end,
	}
end
return Scene
