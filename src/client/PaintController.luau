--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.PaintConfig)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local Strings = require(ReplicatedStorage.Shared.Strings)
type Point = { u: number, v: number }
type Segment = { points: { Point }, starts: boolean }
local View = require(ReplicatedStorage.Shared.PaintView)
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	send: (string, { [string]: unknown }?) -> (),
	language: () -> string
)
	local player = Players.LocalPlayer
	local active = false
	local wall: BasePart? = nil
	local snapshot: Types.Snapshot? = nil
	local previousCameraType: Enum.CameraType? = nil
	local previousSubject: Instance? = nil
	local previousFrame = CFrame.identity
	local previousFov = 70
	local altered: { [BasePart]: number } = {}
	local surface: SurfaceGui? = nil
	local cells: { Frame } = {}
	local strokes: { UIStroke } = {}
	local roller: Model? = nil
	local cylinder: Part? = nil
	local handle: Part? = nil
	local sound: Sound? = nil
	local held = false
	local touch: InputObject? = nil
	local pointer = Vector2.zero
	local queue: { Segment } = {}
	local current: Segment? = nil
	local sequence = 0
	local inflight: number? = nil
	local sentAt = 0
	local lastSample = 0
	local lastHit = 0
	local predictions: { [number]: number } = {}
	local inspectPending = false
	local missing = false
	local toolbar = Instance.new("Frame")
	toolbar.Name = "PaintToolbar"
	toolbar.AnchorPoint = Vector2.new(0.5, 1)
	toolbar.Position = UDim2.new(0.5, 0, 1, -12)
	toolbar.Size = UDim2.new(1, -24, 0, 116)
	toolbar.BackgroundColor3 = Color3.fromRGB(26, 43, 43)
	toolbar.Visible = false
	toolbar.ZIndex = 20
	toolbar.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(580, 116)
	limit.Parent = toolbar
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(244, 239, 224)
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 15
	title.TextWrapped = true
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -24, 0, 42)
	title.ZIndex = 21
	title.Parent = toolbar
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new(x, 8, 1, -60)
		b.Size = UDim2.new(0.5, -16, 0, 48)
		b.BackgroundColor3 = Color3.fromRGB(55, 120, 102)
		b.TextColor3 = Color3.fromRGB(244, 239, 224)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.ZIndex = 21
		b.Parent = toolbar
		return b
	end
	local review = button("Review", 0)
	local leave = button("Leave", 0.5)
	local function stop(): ()
		if not active then
			return
		end
		active = false
		held = false
		touch = nil
		queue = {}
		current = nil
		inflight = nil
		inspectPending = false
		toolbar.Visible = false
		CAS:UnbindAction("PaintMovement")
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = previousCameraType or Enum.CameraType.Custom
			if previousSubject and previousSubject.Parent then
				camera.CameraSubject = previousSubject
			end
			camera.CFrame = previousFrame
			camera.FieldOfView = previousFov
		end
		for part, value in altered do
			if part.Parent then
				part.LocalTransparencyModifier = value
			end
		end
		altered = {}
		if surface then
			surface:Destroy()
			surface = nil
		end
		if roller then
			roller:Destroy()
			roller = nil
		end
		cylinder = nil
		handle = nil
		sound = nil
		cells = {}
		strokes = {}
		predictions = {}
		for _, name in { "Objective", "Home", "Wallet", "Language" } do
			local gui = screen:FindFirstChild(name)
			if gui and gui:IsA("GuiObject") then
				gui.Visible = true
			end
		end
	end
	local function flush(): ()
		if not active or inflight then
			return
		end
		local segment = queue[1]
		if segment then
			local points: { Point } = {}
			for _ = 1, math.min(#segment.points, Config.maxPoints) do
				local point = table.remove(segment.points, 1)
				if point then
					table.insert(points, point)
				end
			end
			if #points == 0 then
				if segment ~= current then
					table.remove(queue, 1)
				end
				return
			end
			sequence += 1
			inflight = sequence
			sentAt = os.clock()
			local packet: { [string]: unknown } = {
				sequence = sequence,
				points = points,
				starts = segment.starts,
				wallId = Config.wallId,
			}
			send("stroke", packet)
			segment.starts = false
			if #segment.points == 0 and segment ~= current then
				table.remove(queue, 1)
			end
		elseif inspectPending then
			inspectPending = false
			send("review", nil)
		end
	end
	local function render(): ()
		local s = snapshot
		if s == nil then
			return
		end
		local t = function(k: string): string
			return Strings.text(language(), k)
		end
		title.Text = string.format(
			"%s · %d%%",
			t(if missing then "paintMissing" else "paintDrag"),
			math.floor(s.count / (Config.columns * Config.rows) * 100)
		)
		review.Text = t("inspectResult")
		leave.Text = t("leaveWork")
		for i, cell in cells do
			local confirmed = string.sub(s.mask, i, i) == "1"
			cell.BackgroundTransparency = if confirmed
				then 0
				elseif predictions[i] and os.clock() - predictions[i] < 0.45 then 0.25
				else 1
			strokes[i].Enabled = missing and not confirmed
		end
	end
	local function enter(target: BasePart, s: Types.Snapshot): ()
		if active then
			return
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		active = true
		wall = target
		snapshot = s
		sequence = s.sequence
		previousCameraType = camera.CameraType
		previousSubject = camera.CameraSubject
		previousFrame = camera.CFrame
		previousFov = camera.FieldOfView
		missing = false
		toolbar.Visible = true
		for _, container in { target.Parent, player.Character } do
			if container then
				for _, part in container:GetDescendants() do
					if part:IsA("BasePart") and part ~= target then
						altered[part] = part.LocalTransparencyModifier
						part.LocalTransparencyModifier = 1
					end
				end
			end
		end
		CAS:BindAction(
			"PaintMovement",
			function(): Enum.ContextActionResult
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump
		)
		for _, name in
			{ "Objective", "Home", "Wallet", "Language", "HomePanel", "JobsPanel", "MapPanel" }
		do
			local gui = screen:FindFirstChild(name)
			if gui and gui:IsA("GuiObject") then
				gui.Visible = false
			end
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LocalPaint"
		gui.Adornee = target
		gui.Face = Enum.NormalId.Back
		gui.CanvasSize = Vector2.new(720, 480)
		gui.LightInfluence = 0
		gui.Parent = player.PlayerGui
		surface = gui
		for row = 0, Config.rows - 1 do
			for col = 0, Config.columns - 1 do
				local cell = Instance.new("Frame")
				cell.BorderSizePixel = 0
				cell.Position = UDim2.fromScale(col / Config.columns, row / Config.rows)
				cell.Size = UDim2.fromScale(1 / Config.columns + 0.001, 1 / Config.rows + 0.001)
				cell.BackgroundColor3 = Color3.new(table.unpack(Config.color))
				cell.BackgroundTransparency = 1
				cell.Parent = gui
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(245, 187, 82)
				stroke.Thickness = 2
				stroke.Enabled = false
				stroke.Parent = cell
				table.insert(cells, cell)
				table.insert(strokes, stroke)
			end
		end
		local model = Instance.new("Model")
		model.Name = "LocalRoller"
		model.Parent = camera
		roller = model
		local function part(size: Vector3, color: Color3): Part
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.Size = size
			p.Color = color
			p.Parent = model
			return p
		end
		local roll = part(Vector3.new(1.1, 0.38, 0.38), Color3.new(table.unpack(Config.color)))
		roll.Shape = Enum.PartType.Cylinder
		cylinder = roll
		handle = part(Vector3.new(0.12, 1.1, 0.12), Color3.fromRGB(65, 91, 91))
		local contact = Instance.new("Sound")
		sound = contact
		contact.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
		contact.Volume = 0.12
		contact.PlaybackSpeed = 0.65
		contact.Looped = true
		contact.Parent = camera
		-- Keep audio owned by the roller so every exit destroys it.
		contact.Parent = cylinder
		render()
	end
	review.Activated:Connect(function()
		held = false
		current = nil
		inspectPending = true
		flush()
	end)
	leave.Activated:Connect(stop)
	player.CharacterRemoving:Connect(stop)
	UIS.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			stop()
			return
		end
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or (input.UserInputType == Enum.UserInputType.Touch and touch == nil)
		then
			if #queue >= 4 then
				return
			end
			held = true
			touch = if input.UserInputType == Enum.UserInputType.Touch then input else nil
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			local segment: Segment = { points = {}, starts = true }
			current = segment
			table.insert(queue, segment)
		end
	end)
	UIS.InputChanged:Connect(function(input: InputObject)
		if input == touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input: InputObject)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held = false
			touch = nil
			current = nil
			flush()
		end
	end)
	RunService:BindToRenderStep("PaintingView", Enum.RenderPriority.Camera.Value + 1, function()
		if not active then
			return
		end
		local target, camera, s = wall, workspace.CurrentCamera, snapshot
		if target == nil or not target.Parent or camera == nil or s == nil then
			stop()
			return
		end
		local root = if player.Character
			then player.Character:FindFirstChild("HumanoidRootPart")
			else nil
		if
			root == nil
			or not root:IsA("BasePart")
			or (root.Position - target.Position).Magnitude > Config.maxDistance
		then
			stop()
			return
		end
		local inset = GuiService:GetGuiInset()
		local viewport = camera.ViewportSize
		local distance, offset = View.fit(
			target.Size.X,
			target.Size.Y,
			viewport.X,
			viewport.Y,
			inset.Y + 12,
			toolbar.AbsolutePosition.Y + inset.Y - 12
		)
		local center = target.Position
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(
			target.CFrame:PointToWorldSpace(Vector3.new(0, 0, distance)),
			center
		) * CFrame.new(0, offset, 0)
		camera.Focus = CFrame.new(center)
		if inflight and os.clock() - sentAt > 2 then
			inflight = nil
			sequence = s.sequence
		end
		if held and os.clock() - lastSample >= 0.03 then
			lastSample = os.clock()
			local pos = if touch then pointer else UIS:GetMouseLocation()
			if touch then
				pos += inset
			end
			local ray = camera:ViewportPointToRay(pos.X, pos.Y)
			local filter = RaycastParams.new()
			filter.FilterType = Enum.RaycastFilterType.Include
			filter.FilterDescendantsInstances = { target }
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 150, filter)
			if hit then
				local localPoint = target.CFrame:PointToObjectSpace(hit.Position)
				local p = {
					u = math.clamp(localPoint.X / target.Size.X + 0.5, 0, 1),
					v = math.clamp(0.5 - localPoint.Y / target.Size.Y, 0, 1),
				}
				local segment = current
				if segment and #segment.points < 24 then
					local last = segment.points[#segment.points]
					if last == nil or (p.u - last.u) ^ 2 + (p.v - last.v) ^ 2 > 0.0001 then
						table.insert(segment.points, p)
						local col = math.min(Config.columns - 1, math.floor(p.u * Config.columns))
						local row = math.min(Config.rows - 1, math.floor(p.v * Config.rows))
						predictions[row * Config.columns + col + 1] = os.clock()
						if surface then
							local stamp = Instance.new("Frame")
							stamp.AnchorPoint = Vector2.new(0.5, 0.5)
							stamp.Position = UDim2.fromScale(p.u, p.v)
							stamp.Size = UDim2.fromScale(1.3 / Config.columns, 1.3 / Config.rows)
							stamp.BackgroundColor3 = Color3.new(table.unpack(Config.color))
							stamp.BackgroundTransparency = 0.15
							stamp.BorderSizePixel = 0
							stamp.Parent = surface
							local corner = Instance.new("UICorner")
							corner.CornerRadius = UDim.new(0.5, 0)
							corner.Parent = stamp
							task.delay(0.35, function()
								stamp:Destroy()
							end)
						end
					end
				end
				lastHit = os.clock()
				if cylinder and handle then
					cylinder.CFrame = target.CFrame
						* CFrame.new(localPoint.X, localPoint.Y, 0.4)
						* CFrame.Angles(os.clock() * 4, 0, 0)
					handle.CFrame = target.CFrame
						* CFrame.new(localPoint.X, localPoint.Y - 0.6, 0.55)
				end
			end
		end
		if sound then
			sound.Playing = held and os.clock() - lastHit < 0.15
		end
		if os.clock() - sentAt >= Config.sendInterval then
			flush()
		end
		render()
	end)
	return {
		enter = enter,
		stop = stop,
		render = render,
		isActive = function(): boolean
			return active
		end,
		update = function(s: Types.Snapshot): ()
			local previous = snapshot
			snapshot = s
			if inflight and (s.sequence >= inflight or s.error ~= nil) then
				inflight = nil
				sequence = s.sequence
			end
			if s.error == "Coverage" then
				missing = true
			end
			if
				active
				and (s.phase ~= "Painting" or (previous ~= nil and s.workId ~= previous.workId))
			then
				stop()
			end
			render()
		end,
	}
end
return Controller
