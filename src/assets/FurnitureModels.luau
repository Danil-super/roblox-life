--!strict
local Decor = require(script.Parent.ClientDecorModels)
local Models = {}
function Models.create(id: string): Model?
	if id == "floor-easel-v1" or id == "floor-planter-v1" then
		local model = Decor.create(if id == "floor-easel-v1" then "easel" else "planter")
		assert(model, "Missing creative furniture model")
		model.Name = id
		return model
	end
	if
		id ~= "floor-plant-v1"
		and id ~= "side-table-v1"
		and id ~= "floor-lamp-v1"
		and id ~= "reading-chair-v1"
		and id ~= "bookcase-v1"
		and id ~= "cozy-sofa-v1"
	then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	local function part(
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, CFrame.new(position)
		p.Anchored, p.CanCollide = true, true
		p.Material, p.Color = Enum.Material.SmoothPlastic, color
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local pivot = part("Pivot", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new())
	pivot.Transparency, pivot.CanCollide, pivot.CanQuery = 1, false, false
	model.PrimaryPart = pivot
	local wood, green, cream =
		Color3.fromRGB(154, 110, 77), Color3.fromRGB(62, 126, 83), Color3.fromRGB(226, 216, 188)
	if id == "floor-plant-v1" then
		part("Pot", Vector3.new(1.3, 1.1, 1.3), Vector3.new(0, 0.55, 0), wood)
		part("Soil", Vector3.new(1.1, 0.1, 1.1), Vector3.new(0, 1.1, 0), Color3.fromRGB(69, 52, 39))
		part("Stem", Vector3.new(0.16, 2.3, 0.16), Vector3.new(0, 2.15, 0), green)
		for index = 1, 3 do
			local leaf = part(
				"Leaves" .. index,
				Vector3.new(1.8, 1.2, 1.8),
				Vector3.new(0, 1.8 + (index - 1) * 0.5, 0),
				green,
				Enum.PartType.Ball
			)
			leaf.CanCollide = false
		end
	elseif id == "side-table-v1" then
		part("Top", Vector3.new(3, 0.25, 2), Vector3.new(0, 2.375, 0), wood)
		for _, x in { -1.2, 1.2 } do
			for _, z in { -0.7, 0.7 } do
				part("Leg", Vector3.new(0.25, 2.25, 0.25), Vector3.new(x, 1.125, z), wood)
			end
		end
	elseif id == "reading-chair-v1" then
		local fabric = Color3.fromRGB(70, 115, 115)
		for _, x in { -1.4, 1.4 } do
			for _, z in { -1.4, 1.4 } do
				part("Foot", Vector3.new(0.35, 0.4, 0.35), Vector3.new(x, 0.2, z), wood)
			end
		end
		part("Base", Vector3.new(3.8, 0.6, 3.8), Vector3.new(0, 0.65, 0), wood)
		part("Back", Vector3.new(3.8, 2.7, 0.5), Vector3.new(0, 2.45, -1.65), fabric)
		for _, x in { -1.65, 1.65 } do
			part("Arm", Vector3.new(0.5, 1.5, 3.8), Vector3.new(x, 1.75, 0), fabric)
		end
		local seat = Instance.new("Seat")
		seat.Name, seat.Size = "Seat", Vector3.new(2.8, 0.5, 2.8)
		seat.CFrame = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.pi, 0)
		seat.Anchored, seat.Disabled, seat.Color, seat.Material =
			true, true, fabric, Enum.Material.Fabric
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Parent = model
	elseif id == "cozy-sofa-v1" then
		local fabric = Color3.fromRGB(70, 115, 115)
		for _, x in { -2.5, 2.5 } do
			for _, z in { -1.35, 1.35 } do
				part("Foot", Vector3.new(0.35, 0.4, 0.35), Vector3.new(x, 0.2, z), wood)
			end
		end
		part("Base", Vector3.new(6, 0.6, 3.8), Vector3.new(0, 0.7, 0), wood)
		part("Back", Vector3.new(6, 2.4, 0.45), Vector3.new(0, 2.3, -1.675), fabric)
		for _, x in { -2.775, 2.775 } do
			part("Arm", Vector3.new(0.45, 1.5, 3.8), Vector3.new(x, 1.8, 0), fabric)
		end
		for _, x in { -1.25, 1.25 } do
			part("Cushion", Vector3.new(2.4, 0.4, 2.9), Vector3.new(x, 1.2, 0.2), fabric)
		end
		for _, x in { -1.7, 1.7 } do
			part("Pillow", Vector3.new(1.1, 0.9, 0.3), Vector3.new(x, 2, -1.25), cream)
		end
		local seat = Instance.new("Seat")
		seat.Name, seat.Size = "Seat", Vector3.new(4.8, 0.1, 2.6)
		seat.CFrame = CFrame.new(0, 1.4, 0.15) * CFrame.Angles(0, math.pi, 0)
		seat.Anchored, seat.Disabled, seat.Transparency = true, true, 1
		seat.CastShadow, seat.Parent = false, model
	elseif id == "bookcase-v1" then
		part("Back", Vector3.new(4, 6, 0.15), Vector3.new(0, 3, -0.675), wood)
		for _, x in { -1.85, 1.85 } do
			part("Side", Vector3.new(0.3, 6, 1.5), Vector3.new(x, 3, 0), wood)
		end
		for shelf = 0, 4 do
			part("Shelf", Vector3.new(4, 0.2, 1.5), Vector3.new(0, 0.1 + shelf * 1.45, 0), wood)
			if shelf < 4 then
				for book = 1, 4 do
					part(
						"Book",
						Vector3.new(0.4, 1, 0.9),
						Vector3.new(-1.3 + book * 0.55, 0.7 + shelf * 1.45, 0),
						if book % 2 == 0 then green else cream
					)
				end
			end
		end
	else
		part(
			"Base",
			Vector3.new(1.7, 0.25, 1.7),
			Vector3.new(0, 0.125, 0),
			Color3.fromRGB(51, 72, 73)
		)
		part(
			"Pole",
			Vector3.new(0.15, 4.6, 0.15),
			Vector3.new(0, 2.5, 0),
			Color3.fromRGB(51, 72, 73)
		)
		local shade = part("Shade", Vector3.new(2, 1.2, 2), Vector3.new(0, 5.4, 0), cream)
		local light = Instance.new("PointLight")
		light.Name = "LampLight"
		light.Color = cream
		light.Range = 12
		light.Brightness = 0.6
		light.Parent = shade
		part(
			"Switch",
			Vector3.new(0.3, 0.45, 0.2),
			Vector3.new(0, 3.2, 0.2),
			Color3.fromRGB(61, 72, 73)
		)
	end
	return model
end
return Models
