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
local Aim = require(ReplicatedStorage.Shared.PaintAim)
local PaintSurface = require("./PaintSurfaceController")
local PaintRoller = require("./PaintRoller")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	send: (string, { [string]: unknown }?) -> (),
	language: () -> string
)
	local player = Players.LocalPlayer
	local active = false
	local disposed = false
	local wall: BasePart? = nil
	local snapshot: Types.Snapshot? = nil
	local function paintColor(): Color3
		local id = if snapshot then snapshot.requiredColorId or Config.colorId else Config.colorId
		return Color3.new(table.unpack(Config.palette[id] or Config.color))
	end
	local function brushScale(): number
		return if snapshot and snapshot.toolId == "wide"
			then Config.wideRollerRadius / Config.rollerRadius
			else 1
	end
	local previousCameraType: Enum.CameraType? = nil
	local previousSubject: Instance? = nil
	local previousFrame = CFrame.identity
	local previousFov = 70
	local altered: { [BasePart]: number } = {}
	local surface: SurfaceGui? = nil
	local ink: PaintSurface.API? = nil
	local strokes: { UIStroke } = {}
	local roller: PaintRoller.API? = nil
	local sound: Sound? = nil
	local held = false
	local touch: InputObject? = nil
	local deathConnection: RBXScriptConnection? = nil
	local pointer = Vector2.zero
	local queue: { Segment } = {}
	local current: Segment? = nil
	local sequence = 0
	local inflight: number? = nil
	local sentAt = 0
	local lastSample = 0
	local lastHit = 0
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
	local progress = Instance.new("Frame")
	progress.Name, progress.BorderSizePixel = "Progress", 0
	progress.Position, progress.Size = UDim2.fromOffset(12, 49), UDim2.new(1, -24, 0, 5)
	progress.BackgroundColor3, progress.ZIndex, progress.Parent =
		Color3.fromRGB(79, 97, 91), 21, toolbar
	local fill = Instance.new("Frame")
	fill.Name, fill.BorderSizePixel = "Confirmed", 0
	fill.Size, fill.BackgroundColor3 = UDim2.fromScale(0, 1), Color3.fromRGB(110, 200, 151)
	fill.ZIndex, fill.Parent = 22, progress
	local threshold = Instance.new("Frame")
	threshold.Name, threshold.BorderSizePixel = "Target", 0
	threshold.AnchorPoint, threshold.Position =
		Vector2.new(0.5, 0.5), UDim2.fromScale(Config.threshold, 0.5)
	threshold.Size, threshold.BackgroundColor3 =
		UDim2.fromOffset(2, 9), Color3.fromRGB(244, 239, 224)
	threshold.ZIndex, threshold.Parent = 23, progress
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new(x, 8, 1, -60)
		b.Size = UDim2.new(0.5, -16, 0, 48)
		b.BackgroundColor3 = Color3.fromRGB(55, 120, 102)
		b.TextColor3 = Color3.fromRGB(244, 239, 224)
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.TextWrapped = true
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
		if deathConnection then
			deathConnection:Disconnect()
			deathConnection = nil
		end
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
		if ink then
			ink.destroy()
			ink = nil
		end
		if surface then
			surface:Destroy()
			surface = nil
		end
		if roller then
			roller.destroy()
			roller = nil
		end
		sound = nil
		strokes = {}
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
				wallId = if snapshot then snapshot.wallId or Config.wallId else Config.wallId,
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
		if s == nil or disposed then
			return
		end
		local t = function(k: string): string
			return Strings.text(language(), k)
		end
		local coverage = View.progress(s.count, Config.columns * Config.rows, Config.threshold)
		title.Text = string.format(
			t("paintProgress"),
			t(
				if s.error == "Drying"
					then "paintWait"
					elseif coverage.covered then "paintCovered"
					elseif missing then "paintMissing"
					else "paintDrag"
			),
			coverage.percent,
			coverage.target
		)
		if coverage.covered and s.error ~= "Drying" then
			local finishKey = if coverage.percent == 100
				then "paintPerfect"
				elseif coverage.percent >= Config.finishExcellentPercent then "paintExcellent"
				else "paintOptional"
			title.Text = string.format(
				t(finishKey),
				coverage.percent,
				if coverage.percent >= Config.finishExcellentPercent
					then 100
					else Config.finishExcellentPercent
			)
		end
		if (s.surfaceTotal or 1) > 1 then
			title.Text = string.format(
				t("surfaceProgress"),
				s.surfaceIndex or 1,
				s.surfaceTotal or 1
			) .. " · " .. title.Text
		end
		fill.Size = UDim2.fromScale(coverage.fill, 1)
		review.Text = t("inspectResult")
		leave.Text = t("leaveWork")
		if ink then
			ink.update(s.mask)
			ink.step(os.clock())
		end
		for i, stroke in strokes do
			stroke.Enabled = missing and not coverage.covered and string.sub(s.mask, i, i) ~= "1"
		end
	end
	local function refreshInk(): ()
		if ink then
			ink.destroy()
			ink = nil
		end
		local gui, state = surface, snapshot
		if gui and state and not disposed then
			local visual = PaintSurface.new(
				gui,
				paintColor(),
				screen:GetAttribute("LightPaintEffects") == true,
				GuiService.ReducedMotionEnabled,
				if wall then wall.Size.X else nil,
				if wall then wall.Size.Y else nil
			)
			visual.update(state.mask, true)
			ink = visual
		end
	end
	local function enter(target: BasePart, s: Types.Snapshot): ()
		if active or disposed then
			return
		end
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if camera == nil or humanoid == nil or humanoid.Health <= 0 then
			return
		end
		active = true
		deathConnection = humanoid.Died:Once(stop)
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
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.ClipsDescendants = true
		gui.LightInfluence = 0
		gui.Parent = player.PlayerGui
		surface = gui
		refreshInk()
		for row = 0, Config.rows - 1 do
			for col = 0, Config.columns - 1 do
				local cell = Instance.new("Frame")
				cell.BorderSizePixel = 0
				cell.Position = UDim2.fromScale(col / Config.columns, row / Config.rows)
				cell.Size = UDim2.fromScale(1 / Config.columns, 1 / Config.rows)
				cell.ZIndex = 3
				cell.BackgroundColor3 = paintColor()
				cell.BackgroundTransparency = 1
				cell.Parent = gui
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(245, 187, 82)
				stroke.Thickness = 2
				stroke.Enabled = false
				stroke.Parent = cell
				table.insert(strokes, stroke)
			end
		end
		local visual = PaintRoller.new(camera, paintColor(), brushScale())
		roller, sound = visual, visual.sound
		render()
	end
	review.Activated:Connect(function()
		held = false
		current = nil
		inspectPending = true
		flush()
	end)
	leave.Activated:Connect(stop)
	local removingConnection = player.CharacterRemoving:Connect(stop)
	local beganConnection = UIS.InputBegan:Connect(function(input: InputObject, processed: boolean)
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
	local changedConnection = UIS.InputChanged:Connect(function(input: InputObject)
		if input == touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	local endedConnection = UIS.InputEnded:Connect(function(input: InputObject)
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
		if os.clock() - lastSample >= 0.03 then
			lastSample = os.clock()
			local pos = if touch then pointer else UIS:GetMouseLocation()
			if touch then
				pos += inset
			end
			local ray = camera:ViewportPointToRay(pos.X, pos.Y)
			local origin = target.CFrame:PointToObjectSpace(ray.Origin)
			local direction = target.CFrame:VectorToObjectSpace(ray.Direction)
			local p = Aim.project(
				{ x = origin.X, y = origin.Y, z = origin.Z },
				{ x = direction.X, y = direction.Y, z = direction.Z },
				target.Size.X,
				target.Size.Y,
				target.Size.Z,
				Config.edgeAssist
			)
			if roller then
				if p and not inspectPending and (not UIS.TouchEnabled or held) then
					roller.update(
						target,
						p.u,
						p.v,
						held,
						screen:GetAttribute("LightPaintEffects") ~= true
							and not GuiService.ReducedMotionEnabled
					)
				else
					roller.hide()
				end
			end
			if held and not inspectPending and p then
				local segment = current
				if segment and #segment.points < 24 then
					local last = segment.points[#segment.points]
					if last == nil or (p.u - last.u) ^ 2 + (p.v - last.v) ^ 2 > 0.0001 then
						table.insert(segment.points, p)
						if ink then
							ink.predict(p.u, p.v, brushScale(), os.clock())
						end
					end
				end
				lastHit = os.clock()
			else
				lastHit = 0
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
	local effectsConnection =
		screen:GetAttributeChangedSignal("LightPaintEffects"):Connect(refreshInk)
	local motionConnection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled")
		:Connect(refreshInk)
	screen.Destroying:Once(function()
		disposed = true
		stop()
		RunService:UnbindFromRenderStep("PaintingView")
		removingConnection:Disconnect()
		beganConnection:Disconnect()
		changedConnection:Disconnect()
		endedConnection:Disconnect()
		effectsConnection:Disconnect()
		motionConnection:Disconnect()
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
