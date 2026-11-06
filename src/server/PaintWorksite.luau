--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.PaintConfig)
local Worksite = {}
export type API = { update: (string, string?, boolean, boolean) -> () }
function Worksite.attach(room: Model): API
	local floor, cloth = room:FindFirstChild("Floor"), room:FindFirstChild("Protection")
	assert(
		floor and floor:IsA("BasePart") and cloth and cloth:IsA("BasePart"),
		"Worksite floor/protection missing"
	)
	local frame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	local canvas, tape = Color3.fromRGB(225, 218, 197), Color3.fromRGB(202, 180, 126)
	cloth.Color, cloth.Material = canvas, Enum.Material.Fabric
	cloth.CanCollide, cloth.CanQuery, cloth.CanTouch, cloth.CastShadow = false, false, false, false
	local model: Model? = nil
	local paints: { BasePart } = {}
	local lastColor: string? = nil
	local dual: boolean? = nil
	local function clear(): ()
		if model then
			model:Destroy()
			model = nil
		end
		table.clear(paints)
		lastColor, dual = nil, nil
		if cloth.Parent then
			cloth.Transparency = 1
		end
	end
	local function build(secondary: boolean): ()
		local group = Instance.new("Model")
		group.Name = "PaintWorksite"
		local dark, metal = Color3.fromRGB(54, 71, 72), Color3.fromRGB(170, 182, 181)
		local function part(
			name: string,
			size: Vector3,
			cf: CFrame,
			color: Color3,
			material: Enum.Material?,
			cylinder: boolean?
		): Part
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
				true, false, false, false, false
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Material = material or Enum.Material.SmoothPlastic
			if cylinder then
				p.Shape = Enum.PartType.Cylinder
			end
			p.Parent = group
			return p
		end
		local function floorTape(name: string, x: number, z: number, w: number, d: number): ()
			for _, side in { -1, 1 } do
				part(
					name .. "Side" .. side,
					Vector3.new(0.14, 0.008, d + 0.14),
					frame * CFrame.new(x + side * w / 2, 0.065, z),
					tape,
					nil,
					nil
				)
				part(
					name .. "End" .. side,
					Vector3.new(w + 0.14, 0.008, 0.14),
					frame * CFrame.new(x, 0.065, z + side * d / 2),
					tape,
					nil,
					nil
				)
			end
		end
		local function wallTape(name: string): ()
			local wall = room:FindFirstChild(name)
			assert(wall and wall:IsA("BasePart"), "Prepared work wall missing")
			local bottom = math.max(
				-wall.Size.Y / 2 - 0.06,
				wall.CFrame:PointToObjectSpace(frame.Position).Y + 0.06
			)
			local top = wall.Size.Y / 2 + 0.06
			for _, side in { -1, 1 } do
				part(
					name .. "TapeSide" .. side,
					Vector3.new(0.12, top - bottom + 0.12, 0.015),
					wall.CFrame
						* CFrame.new(
							side * (wall.Size.X / 2 + 0.06),
							(top + bottom) / 2,
							wall.Size.Z / 2 + 0.02
						),
					tape,
					nil,
					nil
				)
				part(
					name .. "TapeEnd" .. side,
					Vector3.new(wall.Size.X + 0.24, 0.12, 0.015),
					wall.CFrame
						* CFrame.new(0, if side < 0 then bottom else top, wall.Size.Z / 2 + 0.02),
					tape,
					nil,
					nil
				)
			end
		end
		floorTape("FloorTape", 0, -8.5, 14, 5)
		for i = 1, 3 do
			part(
				"ClothFold" .. i,
				Vector3.new(1.3, 0.01, 0.08),
				frame
					* CFrame.new(-5.7 + (i - 1) * 0.3, 0.062, -6.6 - (i - 1) * 0.2)
					* CFrame.Angles(0, -0.5, 0),
				Color3.fromRGB(206, 198, 177),
				Enum.Material.Fabric,
				nil
			)
		end
		wallTape("PaintableWall")
		local tray = frame * CFrame.new(-4.2, 0.12, -8.4)
		part("TrayBase", Vector3.new(2.8, 0.2, 1.9), tray, dark, nil, nil)
		for _, side in { -1, 1 } do
			part(
				"TraySide" .. side,
				Vector3.new(0.12, 0.27, 1.9),
				tray * CFrame.new(side * 1.34, 0.12, 0),
				dark,
				nil,
				nil
			)
			part(
				"TrayEnd" .. side,
				Vector3.new(2.8, 0.27, 0.12),
				tray * CFrame.new(0, 0.12, side * 0.89),
				dark,
				nil,
				nil
			)
		end
		table.insert(
			paints,
			part(
				"TrayPaint",
				Vector3.new(2.5, 0.025, 1.6),
				tray * CFrame.new(0, 0.12, 0),
				canvas,
				nil,
				nil
			)
		)
		local bucket = frame * CFrame.new(5.2, 0, -8.7)
		part(
			"BucketBody",
			Vector3.new(0.9, 1.1, 1.1),
			bucket * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			canvas,
			nil,
			true
		)
		part(
			"BucketRim",
			Vector3.new(0.06, 1.17, 1.17),
			bucket * CFrame.new(0, 0.96, 0) * CFrame.Angles(0, 0, math.pi / 2),
			metal,
			Enum.Material.Metal,
			true
		)
		table.insert(
			paints,
			part(
				"BucketPaint",
				Vector3.new(0.04, 0.94, 0.94),
				bucket * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2),
				canvas,
				nil,
				true
			)
		)
		for _, side in { -1, 1 } do
			part(
				"BucketHandle" .. side,
				Vector3.new(0.05, 0.52, 0.05),
				bucket * CFrame.new(side * 0.58, 1.14, 0),
				metal,
				Enum.Material.Metal,
				nil
			)
		end
		part(
			"BucketHandleTop",
			Vector3.new(1.21, 0.05, 0.05),
			bucket * CFrame.new(0, 1.4, 0),
			metal,
			Enum.Material.Metal,
			nil
		)
		part(
			"BucketLabel",
			Vector3.new(0.5, 0.3, 0.025),
			bucket * CFrame.new(0, 0.5, 0.55),
			tape,
			nil,
			nil
		)
		if secondary then
			part(
				"SideCloth",
				Vector3.new(5, 0.03, 14),
				frame * CFrame.new(11.3, 0.04, 0),
				canvas,
				Enum.Material.Fabric,
				nil
			)
			floorTape("SideFloorTape", 11.3, 0, 5, 14)
			wallTape("PaintableWallB")
		end
		group.Parent = room
		model, dual = group, secondary
	end
	return {
		update = function(
			phase: string,
			colorId: string?,
			available: boolean,
			secondary: boolean
		): ()
			local color = if colorId then Config.palette[colorId] else nil
			local prepared = phase == "ChooseMaterial"
				or phase == "Painting"
				or phase == "SurfaceReady"
				or phase == "Ready"
			if
				not available
				or not prepared
				or color == nil
				or not room.Parent
				or not floor.Parent
				or not cloth.Parent
			then
				clear()
				return
			end
			if model == nil or model.Parent == nil or dual ~= secondary then
				clear()
				build(secondary)
			end
			cloth.Transparency = 0.16
			if lastColor ~= colorId then
				local tint = Color3.new(table.unpack(color))
				for _, p in paints do
					p.Color = tint
				end
				lastColor = colorId
			end
		end,
	}
end
return table.freeze(Worksite)
