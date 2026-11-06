--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Http = game:GetService("HttpService")
local Models = require(RS.Assets.FurnitureModels)
local Types = require(RS.Shared.HomeTypes)
local View = require(RS.Shared.PaintView)
local Strings = require(RS.Shared.Strings)
local PlacementFlow = require(RS.Shared.PlacementFlow)
local Guides = require("./BuildGuidesController")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	send: (string, { [string]: unknown }?) -> (),
	language: () -> string,
	onExit: (boolean) -> ()
)
	local player = Players.LocalPlayer
	local active = false
	local disposed = false
	local guides: Guides.API? = nil
	local pinned = false
	local item: Types.Owned? = nil
	local snapshot: Types.Snapshot? = nil
	local ghost: Model? = nil
	local floor: BasePart? = nil
	local x, z, rotation = 5, 3, 0
	local mode = "Grid"
	local sequence = 0
	local sentSequence = 0
	local valid = false
	local confirmedAt = 0
	local lastSend = 0
	local dirty = true
	local waiting = false
	local pending: PlacementFlow.Pending? = nil
	local reason = "Checking"
	local pointer = Vector2.zero
	local touch: InputObject? = nil
	local mouseHeld = false
	local deathConnection: RBXScriptConnection? = nil
	local oldType = Enum.CameraType.Custom
	local oldSubject: Instance? = nil
	local oldFrame = CFrame.identity
	local oldFov = 70
	local altered: { [BasePart]: number } = {}
	local visibility: { [GuiObject]: boolean } = {}
	local bar = Instance.new("Frame")
	bar.Name = "BuildToolbar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.Size = UDim2.new(1, -24, 0, 140)
	bar.BackgroundColor3 = Color3.fromRGB(26, 43, 43)
	bar.ZIndex = 30
	bar.Visible = false
	bar.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 140)
	limit.Parent = bar
	local function label(name: string, y: number, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromOffset(8, y)
		l.Size = UDim2.new(1, -16, 0, height)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(244, 239, 224)
		l.TextSize = 14
		l.Font = Enum.Font.GothamMedium
		l.TextWrapped = true
		l.ZIndex = 31
		l.Parent = bar
		return l
	end
	local title = label("Title", 4, 28)
	local status = label("Status", 32, 40)
	local buttons: { [string]: TextButton } = {}
	for index, name in { "Mode", "RotateLeft", "Rotate", "Confirm", "Cancel" } do
		local b = Instance.new("TextButton")
		b.Name = name
		b.Position = UDim2.new((index - 1) / 5, 4, 1, -60)
		b.Size = UDim2.new(0.2, -8, 0, 48)
		b.BackgroundColor3 = Color3.fromRGB(55, 120, 102)
		b.TextColor3 = Color3.fromRGB(244, 239, 224)
		b.TextSize = 14
		b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.ZIndex = 31
		b.Parent = bar
		buttons[name] = b
	end
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function pose(): PlacementFlow.Pose
		return { x = x, z = z, rotationY = rotation, mode = mode }
	end
	local function render(): ()
		local compact = UIS.TouchEnabled
		title.Text = if item
			then string.format(t("buildAngle"), t(item.catalogId), rotation)
			else t("buildHint")
		local retry = pending ~= nil and PlacementFlow.canRetry(pending, os.clock())
		status.Text = t(
			if waiting
				then (if retry then "placementDelayed" else "homeErrorSaving")
				elseif valid and not pinned then (if mouseHeld or touch ~= nil
					then "releaseFurniture"
					elseif compact then "touchFloor"
					else "clickFloor")
				else "homeError" .. reason
		)
		buttons.Mode.Text = t(
			if compact
				then (if mode == "Grid" then "buildGridCompact" else "buildFreeCompact")
				else (if mode == "Grid" then "gridMode" else "freeMode")
		) .. (if compact then "" else " [G]")
		local step = if mode == "Grid" then 90 else 15
		buttons.RotateLeft.Text = (if compact then "" else "Q · ") .. string.format("-%d°", step)
		buttons.Rotate.Text = (if compact then "" else "R · ") .. string.format("+%d°", step)
		local confirmKey = if waiting
			then (if retry then "retryPlacement" else "saving")
			else "placeItem"
		if compact then
			confirmKey = if waiting
				then (if retry then "buildRetryCompact" else "buildWaitCompact")
				else "buildConfirmCompact"
		end
		buttons.Confirm.Text = t(confirmKey) .. (if compact then "" else " [Enter]")
		buttons.Cancel.Text = t("cancelBuild")
		buttons.Confirm.Active = active
			and (
				if waiting
					then retry and snapshot ~= nil and snapshot.available
					else snapshot ~= nil
						and snapshot.available
						and pinned
						and valid
						and os.clock() - confirmedAt < 1
			)
		for _, button in buttons do
			button.TextSize = if compact then 12 else 13
		end
		for _, name in { "Mode", "RotateLeft", "Rotate", "Cancel" } do
			buttons[name].Active = active and not waiting
			buttons[name].AutoButtonColor = buttons[name].Active
		end
		buttons.Confirm.AutoButtonColor = buttons.Confirm.Active
		buttons.Confirm.BackgroundColor3 = if buttons.Confirm.Active
			then Color3.fromRGB(55, 120, 102)
			else Color3.fromRGB(86, 88, 82)
		if guides then
			guides.update(
				x,
				z,
				rotation,
				mode,
				valid and not waiting,
				if waiting then "Checking" else reason
			)
		end
		local model = ghost
		if model then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "Pivot" then
					part.Color = if valid
						then Color3.fromRGB(103, 193, 130)
						elseif reason == "Checking" then Color3.fromRGB(232, 190, 94)
						else Color3.fromRGB(213, 105, 92)
				end
			end
		end
	end
	local function stop(returnToInventory: boolean?): ()
		if not active then
			return
		end
		active = false
		if deathConnection then
			deathConnection:Disconnect()
			deathConnection = nil
		end
		screen:SetAttribute("Building", false)
		waiting = false
		pending = nil
		valid = false
		touch = nil
		mouseHeld = false
		bar.Visible = false
		CAS:UnbindAction("FurnitureMovement")
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = oldType
			if oldSubject and oldSubject.Parent then
				camera.CameraSubject = oldSubject
			end
			camera.CFrame = oldFrame
			camera.FieldOfView = oldFov
		end
		for part, value in altered do
			if part.Parent then
				part.LocalTransparencyModifier = value
			end
		end
		altered = {}
		for gui, value in visibility do
			if gui.Parent then
				gui.Visible = value
			end
		end
		visibility = {}
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		if guides then
			guides.destroy()
			guides = nil
		end
		item = nil
		floor = nil
		onExit(returnToInventory ~= false)
	end
	local function change(): ()
		valid = false
		reason = "Checking"
		dirty = true
		render()
	end
	local function toggleMode(): ()
		if not active or waiting then
			return
		end
		mode = if mode == "Grid" then "Free" else "Grid"
		local step = if mode == "Grid" then 1 else 0.1
		x = math.round(x / step) * step
		z = math.round(z / step) * step
		local angle = if mode == "Grid" then 90 else 15
		rotation = (math.round(rotation / angle) * angle) % 360
		change()
	end
	local function rotate(direction: number): ()
		if not active or waiting then
			return
		end
		rotation = (rotation + direction * (if mode == "Grid" then 90 else 15)) % 360
		change()
	end
	local function confirmPlacement(): ()
		local current = item
		local s = snapshot
		if not active or current == nil or s == nil or not s.available then
			return
		end
		local intent = pending
		if intent then
			if not PlacementFlow.canRetry(intent, os.clock()) then
				return
			end
			pending = PlacementFlow.retry(intent, os.clock())
		else
			if not pinned or not valid or waiting or os.clock() - confirmedAt >= 1 then
				return
			end
			pending = PlacementFlow.start(
				"place:" .. Http:GenerateGUID(false),
				s.editorId,
				current.id,
				s.revision,
				pose(),
				os.clock()
			)
		end
		waiting = true
		reason = "Saving"
		local request = pending
		assert(request, "Placement intent missing")
		local packet: { [string]: unknown } = {
			requestId = request.requestId,
			itemId = request.itemId,
			revision = request.revision,
			pose = table.clone(request.pose),
		}
		send("place", packet)
		render()
	end
	buttons.Mode.Activated:Connect(toggleMode)
	buttons.RotateLeft.Activated:Connect(function()
		rotate(-1)
	end)
	buttons.Rotate.Activated:Connect(function()
		rotate(1)
	end)
	buttons.Cancel.Activated:Connect(function()
		if not waiting then
			stop()
		end
	end)
	buttons.Confirm.Activated:Connect(confirmPlacement)
	local function enter(owned: Types.Owned, s: Types.Snapshot): ()
		if disposed then
			return
		end
		if active then
			stop()
		end
		local home = workspace:FindFirstChild("Homes")
		local room = if home then home:FindFirstChild(s.homeName) else nil
		local base = if room then room:FindFirstChild("Floor") else nil
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			not s.nearHome
			or room == nil
			or base == nil
			or not base:IsA("BasePart")
			or camera == nil
			or humanoid == nil
			or humanoid.Health <= 0
		then
			return
		end
		local spec: Types.Product? = nil
		for _, product in s.catalog do
			if product.id == owned.catalogId then
				spec = product
				break
			end
		end
		if spec == nil then
			return
		end
		local created = Models.create(owned.catalogId)
		if created == nil then
			return
		end
		item = owned
		snapshot = s
		ghost = created
		floor = base
		active = true
		deathConnection = humanoid.Died:Once(function()
			stop(false)
		end)
		mouseHeld = false
		pinned = owned.placed ~= nil
		screen:SetAttribute("Building", true)
		mode = if owned.placed then "Free" else "Grid"
		waiting = false
		sequence = 0
		sentSequence = 0
		x = if owned.placed then owned.placed.x else 5
		z = if owned.placed then owned.placed.z else 3
		rotation = if owned.placed then owned.placed.rotationY else 0
		oldType = camera.CameraType
		oldSubject = camera.CameraSubject
		oldFrame = camera.CFrame
		oldFov = camera.FieldOfView
		for _, part in created:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				if part.Name ~= "Pivot" then
					part.Transparency = 0.45
				end
			end
		end
		created.Name = "FurnitureGhost"
		created.Parent = workspace
		if s.layout then
			guides = Guides.start(base, spec, s.layout, language)
		end
		for _, name in
			{
				"Home",
				"Objective",
				"Wallet",
				"Language",
				"HomePanel",
				"ShopPanel",
				"InventoryPanel",
				"JobsPanel",
				"MapPanel",
				"JobNavigation",
				"ShopRoute",
			}
		do
			local gui = screen:FindFirstChild(name)
			if gui and gui:IsA("GuiObject") then
				visibility[gui] = gui.Visible
				gui.Visible = false
			end
		end
		local existing = room:FindFirstChild("Furniture")
		local selected = if existing then existing:FindFirstChild(owned.id) else nil
		for _, part in room:GetDescendants() do
			if
				part:IsA("BasePart")
				and (
					part.Name == "Roof"
					or string.find(part.Name, "Wall") ~= nil
					or part.Name == "FrontLeft"
					or part.Name == "FrontRight"
					or part.Name == "DoorLintel"
					or (selected and part:IsDescendantOf(selected))
				)
			then
				altered[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
		if player.Character then
			for _, part in player.Character:GetDescendants() do
				if part:IsA("BasePart") then
					altered[part] = part.LocalTransparencyModifier
					part.LocalTransparencyModifier = 1
				end
			end
		end
		CAS:BindAction(
			"FurnitureMovement",
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
		bar.Visible = true
		change()
	end
	local function aim(pos: Vector2): boolean
		local s = snapshot
		local base = floor
		local camera = workspace.CurrentCamera
		if s == nil or base == nil or camera == nil then
			return false
		end
		local inset = GuiService:GetGuiInset()
		if
			pos.X ~= pos.X
			or pos.Y ~= pos.Y
			or pos.X < 0
			or pos.X >= camera.ViewportSize.X
			or pos.Y < inset.Y
			or pos.Y >= bar.AbsolutePosition.Y + inset.Y
		then
			return false
		end
		local ray = camera:ViewportPointToRay(pos.X, pos.Y)
		local filter = RaycastParams.new()
		filter.IncludeInstances = { base }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, filter)
		if hit == nil then
			return false
		end
		local localPos = hit.Position - Vector3.new(s.origin[1], s.origin[2], s.origin[3])
		local step = if mode == "Grid" then 1 else 0.1
		local nx, nz = math.round(localPos.X / step) * step, math.round(localPos.Z / step) * step
		if nx ~= x or nz ~= z then
			x = nx
			z = nz
			change()
		end
		return true
	end
	UIS.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and not waiting then
			stop()
			return
		end
		if processed or UIS:GetFocusedTextBox() ~= nil then
			return
		end
		if
			not waiting
			and touch == nil
			and input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if aim(UIS:GetMouseLocation()) then
				mouseHeld = true
				pinned = false
				render()
			end
		end
		if
			not waiting
			and not mouseHeld
			and input.UserInputType == Enum.UserInputType.Touch
			and touch == nil
		then
			pinned = false
			touch = input
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotate(1)
		elseif input.KeyCode == Enum.KeyCode.Q then
			rotate(-1)
		elseif input.KeyCode == Enum.KeyCode.G then
			toggleMode()
		elseif input.KeyCode == Enum.KeyCode.Return then
			confirmPlacement()
		end
	end)
	UIS.InputChanged:Connect(function(input: InputObject)
		if input == touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseHeld then
			mouseHeld = false
			if active and not waiting then
				pinned = UIS:GetFocusedTextBox() == nil and aim(UIS:GetMouseLocation())
				render()
			end
		end
		if input == touch then
			touch = nil
			if active and not waiting then
				local inset = GuiService:GetGuiInset()
				pinned = UIS:GetFocusedTextBox() == nil
					and aim(Vector2.new(input.Position.X, input.Position.Y) + inset)
				render()
			end
		end
	end)
	local focusConnection = UIS.WindowFocusReleased:Connect(function()
		if mouseHeld or touch ~= nil then
			mouseHeld = false
			touch = nil
			if active and not waiting then
				pinned = false
				render()
			end
		end
	end)
	player.CharacterRemoving:Connect(function()
		stop(false)
	end)
	local event = RS:WaitForChild("HomePreview")
	assert(event:IsA("RemoteEvent"), "Home preview missing")
	event.OnClientEvent:Connect(function(result: Types.Preview)
		local s = snapshot
		local owned = item
		if
			not active
			or waiting
			or s == nil
			or owned == nil
			or result.editorId ~= s.editorId
			or result.itemId ~= owned.id
			or result.sequence ~= sentSequence
			or result.revision ~= s.revision
		then
			return
		end
		local p = result.pose
		valid = p ~= nil
			and math.abs(p.x - x) < 0.001
			and math.abs(p.z - z) < 0.001
			and p.rotationY == rotation
		reason = if valid then "Valid" else result.error or "Checking"
		confirmedAt = os.clock()
		render()
	end)
	RunService:BindToRenderStep("FurnitureView", Enum.RenderPriority.Camera.Value + 2, function()
		if not active then
			return
		end
		local s = snapshot
		local base = floor
		local model = ghost
		local camera = workspace.CurrentCamera
		local owned = item
		if
			s == nil
			or base == nil
			or base.Parent == nil
			or model == nil
			or camera == nil
			or owned == nil
		then
			stop(false)
			return
		end
		local origin = Vector3.new(s.origin[1], s.origin[2], s.origin[3])
		local inset = GuiService:GetGuiInset()
		local vp = camera.ViewportSize
		local distance, offset =
			View.fit(32, 24, vp.X, vp.Y, inset.Y + 12, bar.AbsolutePosition.Y + inset.Y - 12)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(
			origin + Vector3.new(0, distance, 0),
			origin,
			Vector3.new(0, 0, -1)
		) * CFrame.new(0, offset, 0)
		local mouse = if touch then pointer + inset else UIS:GetMouseLocation()
		local inBar = mouse.Y >= bar.AbsolutePosition.Y + inset.Y
		if
			not waiting
			and not pinned
			and not inBar
			and (not UIS.TouchEnabled or touch ~= nil or UIS.MouseEnabled)
		then
			aim(mouse)
		end
		model:PivotTo(
			CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, math.rad(rotation), 0)
		)
		if valid and os.clock() - confirmedAt > 1 then
			valid = false
			reason = "Checking"
		end
		if
			not waiting
			and os.clock() - lastSend > 0.2
			and (dirty or os.clock() - confirmedAt > 0.5)
		then
			lastSend = os.clock()
			dirty = false
			sequence += 1
			sentSequence = sequence
			local packet: { [string]: unknown } =
				{ itemId = owned.id, revision = s.revision, pose = pose(), sequence = sequence }
			send("probe", packet)
		end
		render()
	end)
	screen.Destroying:Once(function()
		disposed = true
		stop(false)
		RunService:UnbindFromRenderStep("FurnitureView")
		focusConnection:Disconnect()
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
			if not active then
				return
			end
			if
				previous
				and (
					s.editorId ~= previous.editorId
					or s.homeName ~= previous.homeName
					or not s.nearHome
				)
			then
				stop(false)
				return
			end
			local intent = pending
			if waiting and intent then
				local nextIntent, outcome = PlacementFlow.observe(intent, s)
				pending = nextIntent
				if outcome == "Confirmed" then
					stop()
					return
				end
				if outcome == "Rejected" then
					waiting = false
					valid = false
					reason = s.error or "Checking"
					dirty = true
				end
			end
			if not waiting and previous and s.revision ~= previous.revision then
				change()
			end
		end,
	}
end
return Controller
