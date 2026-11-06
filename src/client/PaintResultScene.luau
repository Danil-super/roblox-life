--!strict
local RS = game:GetService("ReplicatedStorage")
local Types = require(RS.Shared.JobTypes)
local Finish = require(RS.Shared.PaintFinish)
local Config = require(RS.Shared.PaintConfig)
export type API = { render: (Types.Result?, string) -> () }
local Scene = {}
function Scene.start(parent: GuiObject): API
	local root = Instance.new("Frame")
	root.Name, root.Position, root.Size =
		"Comparison", UDim2.fromOffset(0, 120), UDim2.new(1, 0, 0, 128)
	root.BackgroundTransparency, root.Visible, root.Parent = 1, false, parent
	local views: { ViewportFrame } = {}
	for index, name in { "Before", "After" } do
		local v = Instance.new("ViewportFrame")
		v.Name, v.Position, v.Size =
			name,
			UDim2.new((index - 1) / 2, if index == 1 then 16 else 4, 0, 0),
			UDim2.new(0.5, -20, 1, 0)
		v.BackgroundColor3, v.Ambient, v.LightColor =
			Color3.fromRGB(36, 55, 53), Color3.fromRGB(180, 180, 170), Color3.fromRGB(245, 228, 198)
		v.LightDirection, v.Parent = Vector3.new(-1, -1, -1), root
		local camera = Instance.new("Camera")
		camera.FieldOfView, camera.CFrame =
			45, CFrame.lookAt(Vector3.new(14, 11, 20), Vector3.new(0, 2.5, 3))
		camera.Parent, v.CurrentCamera = v, camera
		table.insert(views, v)
	end
	local legacy = Instance.new("TextLabel")
	legacy.Name, legacy.Position, legacy.Size =
		"Legacy", UDim2.fromOffset(16, 0), UDim2.new(1, -32, 1, 0)
	legacy.BackgroundTransparency, legacy.TextWrapped, legacy.TextSize = 1, true, 14
	legacy.TextColor3, legacy.Font, legacy.Parent =
		Color3.fromRGB(181, 198, 187), Enum.Font.GothamMedium, root
	local key = ""
	local disposed = false
	local function clear(): ()
		for _, view in views do
			for _, child in view:GetChildren() do
				if child:IsA("WorldModel") then
					child:Destroy()
				end
			end
		end
		key = ""
	end
	local function part(
		world: WorldModel,
		name: string,
		cf: CFrame,
		size: Vector3,
		color: Color3
	): Part
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.Size, p.CFrame, p.Color = name, true, size, cf, color
		p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface, p.Material =
			Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, Enum.Material.SmoothPlastic
		p.Parent = world
		return p
	end
	local function build(
		view: ViewportFrame,
		data: Finish.Data,
		before: boolean,
		receipt: Types.Result
	): ()
		local world = Instance.new("WorldModel")
		world.Name, world.Parent = "Room", view
		local layout = receipt.sizes
		local firstWidth = if layout then layout[1].width * 0.65 else 10
		local depth = if layout and layout[2]
			then layout[2].width * 0.65
			else (if layout then 6 else 8)
		part(
			world,
			"Floor",
			CFrame.new(0, -0.1, depth / 2),
			Vector3.new(firstWidth + 0.4, 0.2, depth + 0.4),
			Color3.fromRGB(173, 131, 89)
		)
		for index, mask in data.masks do
			local size = if layout then layout[index] else nil
			local width = if size then size.width * 0.65 else (if index == 1 then 10 else 8)
			local height = if size then size.height * 0.65 else 6
			local cf = if index == 1
				then CFrame.new(0, height / 2, 0)
				else CFrame.new(-firstWidth / 2, height / 2, width / 2) * CFrame.Angles(
					0,
					math.pi / 2,
					0
				)
			local id = if index == 1 then receipt.primaryColorId else receipt.secondaryColorId
			local color = Color3.new(table.unpack(Config.palette[id or ""] or Config.color))
			local wall = part(
				world,
				"Wall" .. index,
				cf,
				Vector3.new(width, height, 0.2),
				Color3.fromRGB(145, 148, 140)
			)
			if before then
				for stain = 1, 4 do
					part(
						world,
						"Mark" .. index .. "_" .. stain,
						cf
							* CFrame.new(
								(stain - 2.5) * width / 5,
								if stain % 2 == 0 then 0.8 else -0.7,
								0.12
							),
						Vector3.new(width / 7, 0.5, 0.05),
						Color3.fromRGB(123, 128, 117)
					)
				end
			elseif not string.find(mask, "0", 1, true) then
				wall.Color = color
			else
				for row = 0, data.rows - 1 do
					local col = 0
					while col < data.columns do
						local first = col
						while
							col < data.columns
							and mask:sub(
									row * data.columns + col + 1,
									row * data.columns + col + 1
								)
								== "1"
						do
							col += 1
						end
						if col > first then
							part(
								world,
								"Paint" .. index .. "_" .. row .. "_" .. first,
								cf
									* CFrame.new(
										((first + col) / 2 / data.columns - 0.5) * width,
										(0.5 - (row + 0.5) / data.rows) * height,
										0.12
									),
								Vector3.new(
									(col - first) * width / data.columns,
									height / data.rows,
									0.05
								),
								color
							)
						else
							col += 1
						end
					end
				end
			end
		end
	end
	root.Destroying:Once(function()
		disposed = true
		clear()
	end)
	return {
		render = function(receipt: Types.Result?, emptyText: string): ()
			if disposed then
				return
			end
			root.Visible, legacy.Text = receipt ~= nil, emptyText
			local data = if receipt then Finish.preview(receipt.finish) else nil
			legacy.Visible = receipt ~= nil and data == nil
			for _, view in views do
				view.Visible = data ~= nil
			end
			if receipt == nil or data == nil then
				clear()
				return
			end
			local shapeKey = ""
			local sizes = receipt.sizes
			if sizes then
				for _, size in sizes do
					shapeKey ..= ":" .. size.width .. "x" .. size.height
				end
			end
			local nextKey = receipt.operationId
				.. shapeKey
				.. (receipt.primaryColorId or "")
				.. (receipt.secondaryColorId or "")
				.. data.columns
				.. ":"
				.. data.rows
				.. table.concat(data.masks, ":")
			if key == nextKey then
				return
			end
			clear()
			build(views[1], data, true, receipt)
			build(views[2], data, false, receipt)
			key = nextKey
		end,
	}
end
return Scene
