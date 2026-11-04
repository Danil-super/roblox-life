--!strict
local RS = game:GetService("ReplicatedStorage")
local Layout = require(RS.Shared.StreetLayout)
local Scenery = {}
local wood, green, cream =
	Color3.fromRGB(143, 102, 70), Color3.fromRGB(55, 120, 102), Color3.fromRGB(244, 239, 224)
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	solid: boolean,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, solid, solid, false
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function sign(board: BasePart, key: string, owner: number?): ()
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.Adornee = face.Name .. "Sign", face, board
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize =
			Vector2.new(math.max(240, math.floor(board.Size.X / board.Size.Y * 80)), 80)
		gui.LightInfluence, gui.MaxDistance, gui.AlwaysOnTop = 0, 60, false
		local label = Instance.new("TextLabel")
		label.Name = "WorldLabel"
		label:SetAttribute("SignKey", key)
		if owner then
			label:SetAttribute("SignOwnerId", owner)
		end
		label.Position, label.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -16)
		label.BackgroundTransparency, label.TextColor3, label.Font =
			1, cream, Enum.Font.GothamMedium
		label.TextSize, label.TextWrapped, label.AutoLocalize = 32, true, false
		label.Text = ""
		label.Parent = gui
		gui.Parent = board
	end
end
function Scenery.start(): Model
	local neighborhood = workspace:WaitForChild("Neighborhood")
	local existing = neighborhood:FindFirstChild("StreetDetails")
	if existing then
		assert(existing:IsA("Model"))
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "StreetDetails"
	local plan = Layout.create()
	for i, site in plan.crossings do
		part(
			model,
			"Crossing" .. i,
			Vector3.new(8, 0.025, 1.25),
			CFrame.new(site.x, -0.11, site.z),
			cream,
			false
		)
	end
	for i, site in plan.dashes do
		part(
			model,
			"Lane" .. i,
			Vector3.new(8, 0.025, 0.25),
			CFrame.new(site.x, -0.13, site.z),
			Color3.fromRGB(238, 201, 115),
			false
		)
	end
	for i, site in plan.trees do
		local base = CFrame.new(site.x, 0, site.z)
		part(
			model,
			"Trunk" .. i,
			Vector3.new(0.7, 5, 0.7),
			base * CFrame.new(0, 2.5, 0),
			wood,
			true,
			Enum.Material.Wood
		)
		for tier = 1, 2 do
			local leaves = part(
				model,
				"Crown" .. i .. "_" .. tier,
				Vector3.new(8 - tier, 4, 8 - tier),
				base * CFrame.new(0, 4.5 + tier, 0),
				Color3.fromRGB(52 + tier * 12, 105 + tier * 12, 68 + tier * 7),
				false,
				Enum.Material.Grass
			)
			leaves.Shape = Enum.PartType.Ball
		end
	end
	for i, site in plan.benches do
		local bench = Instance.new("Model")
		bench.Name = "Bench" .. i
		local base = CFrame.new(site.x, 0, site.z)
		for _, x in { -2.2, 2.2 } do
			part(
				bench,
				"Leg",
				Vector3.new(0.3, 1.2, 1.4),
				base * CFrame.new(x, 0.6, 0),
				green,
				true
			)
		end
		part(
			bench,
			"Plank",
			Vector3.new(5.6, 0.3, 1.7),
			base * CFrame.new(0, 1.2, 0),
			wood,
			true,
			Enum.Material.WoodPlanks
		)
		part(
			bench,
			"Back",
			Vector3.new(5.6, 1.5, 0.25),
			base * CFrame.new(0, 2.2, 1),
			wood,
			true,
			Enum.Material.WoodPlanks
		)
		local seat = Instance.new("Seat")
		seat.Name, seat.Size, seat.CFrame =
			"Seat", Vector3.new(4.8, 0.25, 1.25), base * CFrame.new(0, 1.48, 0)
		seat.Anchored, seat.Disabled, seat.Color = true, false, green
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Parent = bench
		bench.Parent = model
	end
	for i, site in plan.lamps do
		local base = CFrame.new(site.x, 0, site.z)
		part(
			model,
			"LampBase" .. i,
			Vector3.new(1.1, 0.25, 1.1),
			base * CFrame.new(0, 0.125, 0),
			green,
			true
		)
		part(
			model,
			"LampPole" .. i,
			Vector3.new(0.25, 7, 0.25),
			base * CFrame.new(0, 3.5, 0),
			green,
			true
		)
		local head = part(
			model,
			"LampHead" .. i,
			Vector3.new(2, 0.45, 2),
			base * CFrame.new(0, 7.1, 0),
			cream,
			false,
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Shadows = 12, 0.75, cream, false
		light.Parent = head
	end
	for i, site in plan.signs do
		part(
			model,
			"SignPost" .. i,
			Vector3.new(0.3, 4.5, 0.3),
			CFrame.new(site.x, 2.25, site.z),
			green,
			true
		)
		local board = part(
			model,
			"SignBoard" .. i,
			Vector3.new(6, 1.6, 0.25),
			CFrame.new(site.x, 4.6, site.z),
			green,
			false
		)
		sign(board, site.key, nil)
	end
	local shop = workspace:WaitForChild("NeighborhoodShop")
	for _, x in { 22.5, 41.5 } do
		part(model, "ShopPost", Vector3.new(0.3, 8, 0.3), CFrame.new(x, 4, 12.5), green, true)
	end
	part(model, "ShopAwning", Vector3.new(20, 0.3, 3), CFrame.new(32, 8, 11.5), green, false)
	local fascia = shop:WaitForChild("Sign")
	assert(fascia:IsA("BasePart"), "Shop sign missing")
	local legacy = fascia:FindFirstChild("Label")
	if legacy then
		legacy:Destroy()
	end
	fascia.Size, fascia.CFrame = Vector3.new(20, 1.2, 0.25), CFrame.new(32, 7.2, 13)
	fascia.Color, fascia.CanCollide, fascia.CanQuery, fascia.CanTouch = green, false, false, false
	sign(fascia, "streetShop", nil)
	model.Parent = neighborhood
	return model
end
function Scenery.decorateRoom(
	model: Model,
	origin: Vector3,
	rotation: number,
	client: boolean,
	owner: number
): ()
	local base = CFrame.new(origin) * CFrame.Angles(0, rotation, 0)
	local color = if client then Color3.fromRGB(164, 111, 78) else green
	part(
		model,
		"EntryCanopy",
		Vector3.new(6.5, 0.25, 2.2),
		base * CFrame.new(0, 8.25, 12.7),
		color,
		false
	)
	for _, x in { -2.4, 2.4 } do
		part(
			model,
			"EntryTrim",
			Vector3.new(0.25, 7, 0.2),
			base * CFrame.new(x, 3.5, 12.55),
			color,
			false
		)
	end
	local plate = part(
		model,
		"EntryPlate",
		Vector3.new(6, 1.2, 0.2),
		base * CFrame.new(0, 7.5, 12.6),
		color,
		false
	)
	sign(plate, if client then "streetClientDoor" else "streetHomeDoor", owner)
end
return Scenery
