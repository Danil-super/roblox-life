--!strict
local RS = game:GetService("ReplicatedStorage")
local Models = require(RS.Assets.FurnitureModels)
local Styles = require("./Domain/ClientRoomConfig")
export type API = {
	resident: Model,
	root: BasePart,
	prompt: ProximityPrompt,
	apply: (string, string) -> (),
}
local Scene = {}
-- The second surface faces into the room, clear of the doorway and resident.
function Scene.configureWalls(room: Model, secondary: boolean): { BasePart }
	local first, floor = room:FindFirstChild("PaintableWall"), room:FindFirstChild("Floor")
	assert(
		first and first:IsA("BasePart") and floor and floor:IsA("BasePart"),
		"Work wall/floor missing"
	)
	local walls: { BasePart } = { first }
	local second = room:FindFirstChild("PaintableWallB")
	if secondary then
		if second == nil then
			local wall = Instance.new("Part")
			wall.Name, wall.Size = "PaintableWallB", Vector3.new(12, 8, 0.3)
			wall.CFrame = floor.CFrame * CFrame.new(14, 4.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
			wall.Anchored, wall.Material = true, Enum.Material.SmoothPlastic
			wall.TopSurface, wall.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			wall.Color, wall.Parent = Color3.fromRGB(145, 148, 140), room
			second = wall
		end
		assert(second and second:IsA("BasePart"), "Invalid second wall")
		table.insert(walls, second)
	elseif second then
		second:Destroy()
	end
	return walls
end
function Scene.create(room: Model, ownerId: number): API
	local floor = room:FindFirstChild("Floor")
	assert(floor and floor:IsA("BasePart"), "Client room has no floor")
	local frame = floor.CFrame * CFrame.new(0, 0.5, 0)
	local decor = Instance.new("Folder")
	decor.Name, decor.Parent = "ClientDecor", room
	local resident = Instance.new("Model")
	resident.Name = "Resident"
	resident:SetAttribute("OwnerUserId", ownerId)
	local base = frame * CFrame.new(8.5, 0, -6.5) * CFrame.Angles(0, math.pi, 0)
	local function body(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		colour: Color3,
		group: string?
	): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, base * localFrame
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material, p.Color = Enum.Material.SmoothPlastic, colour
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p:SetAttribute("RestLocal", localFrame)
		if group then
			p:SetAttribute("GestureGroup", group)
		end
		p.Parent = resident
		return p
	end
	local skin, dark = Color3.fromRGB(220, 177, 140), Color3.fromRGB(44, 51, 57)
	local pivot = body("Pivot", Vector3.new(0.1, 0.1, 0.1), CFrame.identity, dark, nil)
	pivot.Transparency = 1
	resident.PrimaryPart = pivot
	for _, x in { -0.5, 0.5 } do
		body("Leg", Vector3.new(0.8, 1.8, 0.85), CFrame.new(x, 0.9, 0), dark, nil)
	end
	local torso = body("Torso", Vector3.new(2, 2, 0.95), CFrame.new(0, 2.8, 0), dark, nil)
	body("LeftArm", Vector3.new(0.65, 1.8, 0.7), CFrame.new(-1.35, 2.7, 0), skin, nil)
	body("RightArm", Vector3.new(0.65, 1.8, 0.7), CFrame.new(1.35, 2.7, 0), skin, "arm")
	local head = body("Head", Vector3.new(1.4, 1.4, 1.2), CFrame.new(0, 4.5, 0), skin, "head")
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.26, 0.26 } do
		body("Eye", Vector3.new(0.12, 0.15, 0.08), CFrame.new(x, 4.65, -0.57), dark, "head")
	end
	body("Smile", Vector3.new(0.4, 0.08, 0.08), CFrame.new(0, 4.2, -0.57), dark, "head")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText =
		"TalkPrompt", "Talk / Поговорить", "Client / Заказчик"
	prompt:SetAttribute("OwnerUserId", ownerId)
	prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 8, 0, true
	prompt.Enabled, prompt.Parent = false, torso
	resident.Parent = room
	local current = ""
	local function apply(styleId: string, speakerKey: string): ()
		resident:SetAttribute("SpeakerKey", speakerKey)
		if current == styleId then
			return
		end
		local style = Styles[styleId]
		assert(style, "Unknown client room style")
		current = styleId
		decor:ClearAllChildren()
		torso.Color = Color3.new(table.unpack(style.shirt))
		for index, item in style.furniture do
			local m = Models.create(item.id)
			assert(m, "Missing client furniture")
			m.Name = "Decor" .. index
			m:PivotTo(
				frame * CFrame.new(item.x, 0, item.z) * CFrame.Angles(0, math.rad(item.yaw), 0)
			)
			m.Parent = decor
		end
		local function part(name: string, size: Vector3, position: Vector3, colour: Color3): ()
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = name, size, frame * CFrame.new(position)
			p.Anchored, p.Color, p.Material = true, colour, Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface, p.Parent =
				Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, decor
		end
		local accent = Color3.new(table.unpack(style.accent))
		part("SidePicture", Vector3.new(0.12, 3, 4), Vector3.new(-15.4, 5, 2), accent)
		if style.bed then
			part(
				"BedBase",
				Vector3.new(5, 0.6, 7),
				Vector3.new(-10, 0.5, -4),
				Color3.fromRGB(148, 111, 79)
			)
			part("BedCover", Vector3.new(4.8, 0.4, 6.8), Vector3.new(-10, 1, -4), accent)
			part(
				"Pillow",
				Vector3.new(3, 0.4, 1.4),
				Vector3.new(-10, 1.4, -6.4),
				Color3.fromRGB(238, 232, 216)
			)
		end
		room:SetAttribute("ClientStyle", styleId)
	end
	return { resident = resident, root = torso, prompt = prompt, apply = apply }
end
return Scene
