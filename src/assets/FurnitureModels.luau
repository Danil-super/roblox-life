--!strict
local Models = {}
function Models.create(id: string): Model?
	if id ~= "floor-plant-v1" and id ~= "side-table-v1" and id ~= "floor-lamp-v1" then
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
		light.Color = cream
		light.Range = 12
		light.Brightness = 0.6
		light.Parent = shade
	end
	return model
end
return Models
