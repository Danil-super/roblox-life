--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Math = require(RS.Shared.MapMath)
local Types = require(RS.Shared.JobTypes)
export type API = {
	show: () -> (),
	hide: () -> (),
	isVisible: () -> boolean,
	render: (Types.Snapshot?) -> (),
	update: (BasePart?, Vector3?, Types.Snapshot?, { Vector3 }, number) -> (),
}
local Controller = {}
function Controller.start(screen: ScreenGui, phone: Frame, language: () -> string): API
	local ink, paper = Color3.fromRGB(26, 43, 43), Color3.fromRGB(244, 239, 224)
	local accent = Color3.fromRGB(55, 120, 102)
	local state: Types.Snapshot? = nil
	local root: BasePart? = nil
	local home: Vector3? = nil
	local width, height = 400, 150
	local routePoints: { Vector3 } = {}
	local routeIndex = 1
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint = "MapPanel", Vector2.new(0.5, 0.5)
	panel.Position, panel.Size = UDim2.fromScale(0.5, 0.5), UDim2.new(1, -24, 1, -24)
	panel.BackgroundColor3, panel.Visible, panel.ZIndex = ink, false, 8
	panel.Active = true
	panel.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(480, 388), panel
	local function label(parent: Instance, name: string, fontSize: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name, l.BackgroundTransparency = name, 1
		l.TextColor3, l.Font, l.TextSize = paper, Enum.Font.GothamMedium, fontSize
		l.TextWrapped, l.ZIndex, l.Parent = true, 9, parent
		return l
	end
	local heading = label(panel, "Heading", 22)
	heading.Position, heading.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 32)
	local body = Instance.new("Frame")
	body.Name, body.BackgroundTransparency = "Body", 1
	body.Position, body.Size = UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -122)
	body.ZIndex, body.Parent = 9, panel
	local board = Instance.new("Frame")
	board.Name, board.Position = "Block", UDim2.fromOffset(16, 6)
	board.BackgroundColor3, board.BorderSizePixel = Color3.fromRGB(91, 112, 90), 0
	board.ZIndex, board.Parent = 9, body
	local road = Instance.new("Frame")
	road.Name, road.BackgroundColor3, road.BorderSizePixel = "Road", Color3.fromRGB(70, 77, 78), 0
	road.ZIndex, road.Parent = 9, board
	local lines: { Frame } = {}
	for i = 1, 128 do
		local line = Instance.new("Frame")
		line.Name, line.AnchorPoint = "Route" .. i, Vector2.new(0.5, 0.5)
		line.BackgroundColor3, line.BorderSizePixel = Color3.fromRGB(245, 197, 98), 0
		line.ZIndex, line.Visible, line.Parent = 9, false, board
		table.insert(lines, line)
	end
	local function marker(name: string, size: number, color: Color3, round: boolean): Frame
		local f = Instance.new("Frame")
		f.Name, f.AnchorPoint, f.Size = name, Vector2.new(0.5, 0.5), UDim2.fromOffset(size, size)
		f.BackgroundColor3, f.BorderSizePixel, f.ZIndex, f.Parent = color, 0, 10, board
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius, corner.Parent = UDim.new(1, 0), f
		end
		return f
	end
	local house = marker("Home", 16, Color3.fromRGB(114, 185, 206), true)
	house.BackgroundTransparency = 1
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Parent = house.BackgroundColor3, 2, house
	local target = marker("Client", 14, paper, false)
	target.Rotation = 45
	local playerDot = marker("Player", 8, Color3.fromRGB(245, 197, 98), true)
	playerDot.ZIndex = 11
	local youLabel = label(body, "YouLegend", 12)
	local homeLabel = label(body, "HomeLegend", 12)
	local clientLabel = label(body, "ClientLegend", 12)
	local playerIcon, homeIcon, clientIcon = playerDot:Clone(), house:Clone(), target:Clone()
	playerIcon.Name, homeIcon.Name, clientIcon.Name = "PlayerIcon", "HomeIcon", "ClientIcon"
	for _, icon in { playerIcon, homeIcon, clientIcon } do
		icon.Size, icon.Parent = UDim2.fromOffset(10, 10), body
	end
	local hint = label(body, "Hint", 12)
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size = name, UDim2.new(x, 12, 1, -56), UDim2.new(0.5, -24, 0, 44)
		b.BackgroundColor3, b.TextColor3 = accent, paper
		b.TextSize, b.TextWrapped, b.Font = 14, true, Enum.Font.GothamMedium
		b.ZIndex, b.Parent = 9, panel
		return b
	end
	local back, follow = button("Back", 0), button("Follow", 0.5)
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function draw(): ()
		local s, base = state, home
		for _, line in lines do
			line.Visible = false
		end
		local remaining: number? = nil
		local d = if s then s.destination else nil
		target.Visible = d ~= nil and base ~= nil
		house.Visible, playerDot.Visible = base ~= nil, base ~= nil and root ~= nil
		if base then
			local bounds =
				Math.bounds(base.X, base.Z, if d then d[1] else nil, if d then d[3] else nil)
			local current = root
			if current then
				bounds = Math.include(bounds, current.Position.X, current.Position.Z)
			end
			for i = routeIndex, #routePoints do
				local point = routePoints[i]
				bounds = Math.include(bounds, point.X, point.Z)
			end
			local hx, hy = Math.pixel(base.X, base.Z, bounds, width, height)
			house.Position = UDim2.fromOffset(hx, hy)
			if d then
				local tx, ty = Math.pixel(d[1], d[3], bounds, width, height)
				target.Position = UDim2.fromOffset(tx, ty)
			end
			if current then
				local x, y =
					Math.pixel(current.Position.X, current.Position.Z, bounds, width, height)
				playerDot.Position = UDim2.fromOffset(x, y)
				if d and #routePoints > 0 then
					local routeLength = 0
					local from = current.Position
					for i = routeIndex, #routePoints do
						local to = routePoints[i]
						local dx, dz = to.X - from.X, to.Z - from.Z
						routeLength += math.sqrt(dx * dx + dz * dz)
						local line = lines[i - routeIndex + 1]
						if line then
							local ax, ay = Math.pixel(from.X, from.Z, bounds, width, height)
							local bx, by = Math.pixel(to.X, to.Z, bounds, width, height)
							line.Position, line.Size =
								UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
								UDim2.fromOffset(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2), 2)
							line.Rotation, line.Visible =
								math.deg(math.atan2(by - ay, bx - ax)), true
						end
						from = to
					end
					remaining = routeLength
				end
			end
			-- P0 streets repeat every room row, 38 studs north of its home origin.
			local _, y = Math.pixel(base.X, base.Z + 38, bounds, width, height)
			local roadHeight = math.max(4, 16 / (bounds.front - bounds.back) * (height - 20))
			road.Position, road.Size =
				UDim2.fromOffset(0, y - roadHeight / 2), UDim2.new(1, 0, 0, roadHeight)
		end
		local available = s ~= nil
			and s.available
			and d ~= nil
			and Players.LocalPlayer:GetAttribute("ProfileStatus") == "Ready"
		follow.Active, follow.AutoButtonColor = available, available
		follow.BackgroundTransparency = if available then 0 else 0.6
		heading.Text, back.Text, follow.Text = t("map"), t("backHome"), t("followRoute")
		youLabel.Text, homeLabel.Text, clientLabel.Text =
			t("mapYou"), t("home"), t("clientApartment")
		clientLabel.Visible = d ~= nil
		clientIcon.Visible = d ~= nil
		local current = root
		hint.Text = if s == nil or not s.available
			then t("mapUnavailable")
			elseif d and current then string.format(
				t("routeDistance"),
				math.ceil(remaining or (Vector3.new(d[1], d[2], d[3]) - current.Position).Magnitude)
			)
			else t("mapNoJob")
	end
	local function resize(): ()
		local layout = Math.layout(body.AbsoluteSize.X, body.AbsoluteSize.Y)
		width, height = layout.width, layout.height
		board.Size = UDim2.fromOffset(width, height)
		for index, l in { youLabel, homeLabel, clientLabel } do
			l.Position, l.Size =
				UDim2.new((index - 1) / 3, 24, 0, layout.legendY), UDim2.new(1 / 3, -28, 0, 18)
		end
		for index, icon in { playerIcon, homeIcon, clientIcon } do
			icon.Position = UDim2.new((index - 1) / 3, 12, 0, layout.legendY + 9)
		end
		hint.Position, hint.Size = UDim2.fromOffset(12, layout.hintY), UDim2.new(1, -24, 0, 28)
		draw()
	end
	back.Activated:Connect(function()
		panel.Visible = false
		phone.Visible = true
	end)
	follow.Activated:Connect(function()
		if follow.Active then
			panel.Visible = false
			phone.Visible = false
		end
	end)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return {
		show = function(): ()
			phone.Visible = false
			panel.Visible = true
			resize()
		end,
		hide = function(): ()
			panel.Visible = false
		end,
		isVisible = function(): boolean
			return panel.Visible
		end,
		render = function(s: Types.Snapshot?): ()
			state = s
			draw()
		end,
		update = function(
			part: BasePart?,
			origin: Vector3?,
			s: Types.Snapshot?,
			points: { Vector3 },
			index: number
		): ()
			routePoints, routeIndex = points, index
			root, home, state = part, origin, s
			if panel.Visible then
				draw()
			end
		end,
	}
end
return Controller
