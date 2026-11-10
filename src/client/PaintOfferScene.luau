--!strict
local RS = game:GetService("ReplicatedStorage")
local Types = require(RS.Shared.JobTypes)
local Geometry = require(RS.Shared.PaintGeometry)
local Config = require(RS.Shared.PaintConfig)
local Decor = require(RS.Assets.ClientDecorModels)
export type API = { render: (Types.Offer?) -> boolean }
local Scene = {}
function Scene.start(parent: GuiObject): API
	local view = Instance.new("ViewportFrame")
	view.Name, view.Position, view.Size =
		"PlanPreview", UDim2.fromOffset(16, 108), UDim2.new(1, -32, 0, 136)
	view.BackgroundColor3, view.Ambient, view.LightColor =
		Color3.fromRGB(36, 55, 53), Color3.fromRGB(180, 180, 170), Color3.fromRGB(245, 228, 198)
	view.LightDirection, view.Active, view.Visible, view.ZIndex =
		Vector3.new(-1, -1, -1), false, false, 10
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView, camera.Parent, view.CurrentCamera = 40, view, camera
	local world: WorldModel? = nil
	local key = ""
	local disposed = false
	local function clear(): ()
		if world then
			world:Destroy()
			world = nil
		end
		key = ""
	end
	local function part(name: string, cf: CFrame, size: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name, p.CFrame, p.Size, p.Color = name, cf, size, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
			true, false, false, false, false
		p.Material, p.TopSurface, p.BottomSurface =
			Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = world
		return p
	end
	view.Destroying:Once(function()
		disposed = true
		clear()
	end)
	return {
		render = function(offer: Types.Offer?): boolean
			if disposed then
				return false
			end
			local sizes = if offer then Geometry.layout(offer.id) else nil
			local primary = if offer then Config.palette[offer.colorId] else nil
			local secondary = if offer and offer.secondaryColorId
				then Config.palette[offer.secondaryColorId]
				else nil
			if
				offer == nil
				or sizes == nil
				or primary == nil
				or (#sizes == 2) ~= (offer.secondaryColorId ~= nil)
				or (#sizes == 2 and secondary == nil)
			then
				view.Visible = false
				clear()
				return false
			end
			view.Visible = true
			local nextKey = offer.id
				.. ":"
				.. offer.colorId
				.. ":"
				.. (offer.secondaryColorId or "")
			if key == nextKey then
				return true
			end
			clear()
			local room = Instance.new("WorldModel")
			room.Name, room.Parent, world = "Plan", view, room
			local width = sizes[1].width
			local depth = if sizes[2] then sizes[2].width else math.max(6, width / 2)
			local height = sizes[1].height
			local floor = part(
				"Floor",
				CFrame.new(0, -0.125, depth / 2),
				Vector3.new(width + 0.4, 0.25, depth + 0.4),
				Color3.fromRGB(173, 131, 89)
			)
			floor.Material = Enum.Material.WoodPlanks
			for index, size in sizes do
				height = math.max(height, size.height)
				local cf = if index == 1
					then CFrame.new(0, size.height / 2, 0)
					else CFrame.new(-width / 2, size.height / 2, depth / 2) * CFrame.Angles(
						0,
						math.pi / 2,
						0
					)
				local values = if index == 1 then primary else secondary or primary
				part(
					"Wall" .. index,
					cf,
					Vector3.new(size.width, size.height, 0.2),
					Color3.new(table.unpack(values))
				)
				part(
					"Trim" .. index,
					cf * CFrame.new(0, -size.height / 2 + 0.1, 0.15),
					Vector3.new(size.width, 0.18, 0.12),
					Color3.fromRGB(244, 239, 224)
				)
			end
			local plant = Decor.create("planter")
			if plant then
				plant:PivotTo(CFrame.new(width / 2 - 2, 0, depth - 1.4))
				plant.Parent = room
			end
			local distance = math.max(width, depth, height) * 1.3
			camera.CFrame = CFrame.lookAt(
				Vector3.new(distance, height * 0.4 + distance * 0.7, depth * 0.4 + distance * 1.2),
				Vector3.new(0, height * 0.4, depth * 0.4)
			)
			key = nextKey
			return true
		end,
	}
end
return Scene
