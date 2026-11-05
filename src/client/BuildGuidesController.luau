--!strict
local RS = game:GetService("ReplicatedStorage")
local Layout = require(RS.Shared.FurnitureLayout)
local Strings = require(RS.Shared.Strings)
export type API = {
	update: (number, number, number, string, boolean, string) -> (),
	destroy: () -> (),
}
local Controller = {}
function Controller.start(
	base: BasePart,
	spec: { width: number, depth: number },
	layout: Layout.Plan,
	language: () -> string
): API
	local root = Instance.new("Folder")
	root.Name, root.Parent = "FurnitureGuides", workspace
	local origin = base.Position + Vector3.new(0, base.Size.Y / 2 + 0.04, 0)
	local paper = Color3.fromRGB(244, 239, 224)
	local amber = Color3.fromRGB(232, 190, 94)
	local function part(
		name: string,
		x: number,
		z: number,
		w: number,
		d: number,
		color: Color3,
		alpha: number
	): Part
		local p = Instance.new("Part")
		p.Name, p.Size = name, Vector3.new(w, 0.02, d)
		p.CFrame = CFrame.new(origin + Vector3.new(x, 0, z))
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
			true, false, false, false, false
		p.Material, p.TopSurface, p.BottomSurface =
			Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Color, p.Transparency, p.Parent = color, alpha, root
		return p
	end
	local grid: { Part } = {}
	for x = -15, 15 do
		table.insert(grid, part("GridX" .. x, x, 0, 0.035, layout.halfDepth * 2, paper, 0.72))
	end
	for z = -11, 11 do
		table.insert(grid, part("GridZ" .. z, 0, z, layout.halfWidth * 2, 0.035, paper, 0.72))
	end
	for side = -1, 1, 2 do
		part(
			"BoundaryX" .. side,
			side * layout.halfWidth,
			0,
			0.09,
			layout.halfDepth * 2,
			paper,
			0.15
		)
		part(
			"BoundaryZ" .. side,
			0,
			side * layout.halfDepth,
			layout.halfWidth * 2,
			0.09,
			paper,
			0.15
		)
	end
	local labels: { [string]: TextLabel } = {}
	for _, region in layout.fixed do
		local area = part(region.id, region.x, region.z, region.w, region.d, amber, 0.8)
		local key = region.labelKey
		if key then
			local gui = Instance.new("BillboardGui")
			gui.Name, gui.Size, gui.AlwaysOnTop, gui.MaxDistance =
				"Label", UDim2.fromOffset(124, 22), true, 200
			gui.Parent = area
			local label = Instance.new("TextLabel")
			label.Name, label.Size, label.BackgroundTransparency =
				region.id .. "Label", UDim2.fromScale(1, 1), 0.15
			label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(26, 43, 43), paper
			label.Font, label.TextSize, label.Parent = Enum.Font.GothamBold, 12, gui
			labels[key] = label
		end
	end
	local footprint: { Part } = {}
	for i = 1, 4 do
		table.insert(footprint, part("Footprint" .. i, 0, 0, 0.06, 0.06, amber, 0))
	end
	local closed = false
	local lastX, lastZ, lastAngle: number? = nil, nil, nil
	local lastMode, lastStatus, lastLanguage = "", "", ""
	local function update(
		x: number,
		z: number,
		angle: number,
		mode: string,
		valid: boolean,
		reason: string
	): ()
		if closed then
			return
		end
		if x ~= lastX or z ~= lastZ or angle ~= lastAngle then
			lastX, lastZ, lastAngle = x, z, angle
			local pose = CFrame.new(origin + Vector3.new(x, 0.035, z))
				* CFrame.Angles(0, math.rad(angle), 0)
			for i, line in footprint do
				local horizontal = i <= 2
				local side = if i % 2 == 1 then -1 else 1
				line.Size = if horizontal
					then Vector3.new(spec.width, 0.02, 0.06)
					else Vector3.new(0.06, 0.02, spec.depth)
				line.CFrame = pose
					* CFrame.new(
						if horizontal then 0 else side * spec.width / 2,
						0,
						if horizontal then side * spec.depth / 2 else 0
					)
			end
		end
		if mode ~= lastMode then
			lastMode = mode
			for _, line in grid do
				line.Transparency = if mode == "Grid" then 0.72 else 1
			end
		end
		local status = if valid
			then "Valid"
			elseif reason == "Checking" then "Checking"
			else "Refused"
		if status ~= lastStatus then
			lastStatus = status
			local color = if valid
				then Color3.fromRGB(103, 193, 130)
				elseif status == "Checking" then amber
				else Color3.fromRGB(213, 105, 92)
			for _, line in footprint do
				line.Color = color
			end
		end
		local locale = language()
		if locale ~= lastLanguage then
			lastLanguage = locale
			for key, label in labels do
				label.Text = Strings.text(locale, key)
			end
		end
	end
	return {
		update = update,
		destroy = function(): ()
			if closed then
				return
			end
			closed = true
			root:Destroy()
		end,
	}
end
return Controller
