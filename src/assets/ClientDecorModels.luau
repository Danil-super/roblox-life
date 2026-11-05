--!strict
local Models = {}
export type Bounds = { width: number, depth: number, height: number, parts: number }
local bounds: { [string]: Bounds } = {
	planter = table.freeze({ width = 3.2, depth = 1.6, height = 2.1, parts = 6 }),
	easel = table.freeze({ width = 3, depth = 2.6, height = 4.5, parts = 11 }),
	books = table.freeze({ width = 1.8, depth = 1.2, height = 0.75, parts = 10 }),
}
Models.bounds = table.freeze(bounds)
function Models.create(kind: string): Model?
	if Models.bounds[kind] == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("DecorKind", kind)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
			true, false, false, false, false
		p.Material, p.TopSurface, p.BottomSurface =
			Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local wood, cream = Color3.fromRGB(154, 110, 77), Color3.fromRGB(236, 225, 194)
	local mint, rose = Color3.fromRGB(143, 186, 163), Color3.fromRGB(212, 161, 158)
	local pivot = part("Pivot", Vector3.new(0.1, 0.1, 0.1), CFrame.identity, wood)
	pivot.Transparency, model.PrimaryPart = 1, pivot
	if kind == "planter" then
		part("Box", Vector3.new(3.2, 0.8, 1.6), CFrame.new(0, 0.4, 0), wood)
		part("Soil", Vector3.new(3, 0.08, 1.4), CFrame.new(0, 0.82, 0), Color3.fromRGB(89, 69, 48))
		for i = -1, 1 do
			local leaf = part(
				"Leaf" .. i,
				Vector3.new(0.9, 1.3, 0.9),
				CFrame.new(i * 0.9, 1.4, 0),
				Color3.fromRGB(70 + i * 8, 136, 87)
			)
			leaf.Shape = Enum.PartType.Ball
		end
	elseif kind == "books" then
		for i, color in { mint, rose, wood } do
			local y = (i - 1) * 0.24
			part("CoverBottom" .. i, Vector3.new(1.8, 0.04, 1.2), CFrame.new(0, y + 0.02, 0), color)
			part("Pages" .. i, Vector3.new(1.72, 0.14, 1.12), CFrame.new(0, y + 0.11, 0), cream)
			part("CoverTop" .. i, Vector3.new(1.8, 0.04, 1.2), CFrame.new(0, y + 0.2, 0), color)
		end
	else
		for _, x in { -0.8, 0.8 } do
			part(
				"Leg",
				Vector3.new(0.18, 4, 0.18),
				CFrame.new(x, 2, 0) * CFrame.Angles(0, 0, math.rad(if x < 0 then -12 else 12)),
				wood
			)
		end
		part(
			"BackLeg",
			Vector3.new(0.18, 3.8, 0.18),
			CFrame.new(0, 1.9, 0.55) * CFrame.Angles(math.rad(20), 0, 0),
			wood
		)
		part("Ledge", Vector3.new(2.6, 0.18, 0.5), CFrame.new(0, 1.85, -0.1), wood)
		part("Frame", Vector3.new(2.4, 2.1, 0.16), CFrame.new(0, 2.95, -0.1), wood)
		part("Canvas", Vector3.new(2.15, 1.85, 0.04), CFrame.new(0, 2.95, -0.21), cream)
		for i, color in { mint, rose, wood } do
			part(
				"Paint" .. i,
				Vector3.new(0.48, 0.6 + i * 0.1, 0.02),
				CFrame.new((i - 2) * 0.55, 2.9, -0.245),
				color
			)
		end
		part("BrushRest", Vector3.new(1.2, 0.08, 0.1), CFrame.new(0.4, 1.99, -0.25), mint)
	end
	return model
end
return Models
