--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RouteMath = require(ReplicatedStorage.Shared.RouteMath)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local Navigation = {}
local ink = Color3.fromRGB(26, 43, 43)
local gold = Color3.fromRGB(245, 197, 98)
local paper = Color3.fromRGB(244, 239, 224)
local function round(parent: GuiObject): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = parent
end
local function label(parent: Instance, name: string, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name, l.Size = name, size
	l.BackgroundTransparency = 1
	l.Font, l.TextSize = Enum.Font.GothamBold, 15
	l.TextColor3, l.TextWrapped = paper, true
	l.Parent = parent
	return l
end
function Navigation.start(screen: ScreenGui, activate: () -> ())
	local chip = Instance.new("Frame")
	chip.Name = "JobNavigation"
	chip.Position, chip.Size = UDim2.fromOffset(16, 100), UDim2.fromOffset(242, 64)
	chip.BackgroundColor3, chip.BorderSizePixel = ink, 0
	chip.Visible, chip.Parent = false, screen
	round(chip)
	local disc = Instance.new("Frame")
	disc.Position, disc.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(48, 48)
	disc.BackgroundColor3, disc.BorderSizePixel = gold, 0
	disc.Parent = chip
	round(disc)
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position, arrow.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(36, 36)
	arrow.BackgroundTransparency, arrow.Parent = 1, disc
	for _, part in
		{
			{ x = 18, y = 20, w = 6, h = 24, angle = 0 },
			{ x = 12, y = 12, w = 20, h = 6, angle = -45 },
			{ x = 24, y = 12, w = 20, h = 6, angle = 45 },
		}
	do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position, f.Size = UDim2.fromOffset(part.x, part.y), UDim2.fromOffset(part.w, part.h)
		f.Rotation, f.BackgroundColor3, f.BorderSizePixel = part.angle, ink, 0
		f.Parent = arrow
	end
	local distance = label(chip, "Distance", UDim2.fromOffset(170, 28))
	distance.Position, distance.TextXAlignment = UDim2.fromOffset(64, 4), Enum.TextXAlignment.Left
	local destination = label(chip, "Destination", UDim2.fromOffset(170, 26))
	destination.Position, destination.TextXAlignment =
		UDim2.fromOffset(64, 32), Enum.TextXAlignment.Left
	destination.TextSize = 13
	local marker = Instance.new("BillboardGui")
	marker.Name = "WorkWallMarker"
	marker.Size, marker.StudsOffsetWorldSpace = UDim2.fromOffset(204, 54), Vector3.new(0, 5.5, 0)
	marker.AlwaysOnTop, marker.MaxDistance = true, 140
	marker.Enabled, marker.Parent = false, screen
	local badge = label(marker, "Target", UDim2.fromScale(1, 1))
	badge.BackgroundTransparency, badge.BackgroundColor3, badge.TextColor3 = 0, gold, ink
	round(badge)
	local objective = screen:WaitForChild("Objective")
	assert(objective:IsA("Frame"))
	local action = Instance.new("TextButton")
	action.Name = "NextAction"
	action.Position, action.Size = UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 48)
	action.BackgroundColor3, action.TextColor3 = gold, ink
	action.Font, action.TextSize, action.TextWrapped = Enum.Font.GothamBold, 15, true
	action.Parent = objective
	round(action)
	action.Activated:Connect(activate)
	return {
		render = function(actionText: string, available: boolean): ()
			action.Text, action.Active, action.AutoButtonColor = actionText, available, available
			action.BackgroundTransparency = if available then 0 else 0.5
		end,
		update = function(
			s: Types.Snapshot?,
			target: BasePart?,
			root: BasePart?,
			active: boolean,
			near: boolean,
			t: (string) -> string
		): ()
			chip.Visible = active
			marker.Enabled = active and target ~= nil
			if target then
				marker.Adornee = target
			end
			if not active or s == nil or root == nil or s.destination == nil then
				return
			end
			local d = s.destination
			local delta = Vector3.new(d[1], d[2], d[3]) - root.Position
			distance.Text = if near
				then t("arrived")
				else string.format(t("routeDistance"), math.ceil(delta.Magnitude))
			local meeting = s.phase == "Inspect" or s.phase == "Ready"
			local nameKey = if meeting then s.clientKey or "clientResident" else "workWall"
			destination.Text = if near then t(nameKey) else t("clientApartment")
			badge.Text = t(nameKey)
				.. "\n"
				.. t(if near then "useActionBelow" else "clientApartment")
			local camera = workspace.CurrentCamera
			if camera then
				local look = camera.CFrame.LookVector
				arrow.Rotation = RouteMath.bearing(delta.X, delta.Z, look.X, look.Z)
			end
		end,
	}
end
return Navigation
