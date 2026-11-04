--!strict
local ServerStorage = game:GetService("ServerStorage")
local Rules = require("./Domain/RoomRules")
local Scenery = require("./NeighborhoodScenery")
export type Home = { model: Model, origin: Vector3, spawn: SpawnLocation, ownerId: number }
local World = {}
local rooms: { [Model]: Home } = {}

local function cloneRoom(
	player: Player,
	templateName: string,
	origin: Vector3,
	rotation: number
): Home
	local template = ServerStorage:WaitForChild(templateName)
	assert(template:IsA("Model"), "Room template must be a Model")
	local model = template:Clone()
	local floor, spawn = model:FindFirstChild("Floor"), model:FindFirstChild("HomeSpawn")
	assert(floor ~= nil and floor:IsA("BasePart"), "Room floor missing")
	assert(spawn ~= nil and spawn:IsA("SpawnLocation"), "Room spawn missing")
	model.PrimaryPart = floor
	model.Name = "Home_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("TemplateVersion", 1)
	model:PivotTo(CFrame.new(origin + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, rotation, 0))
	Scenery.decorateRoom(
		model,
		origin,
		rotation,
		templateName == "ClientApartmentTemplate_v1",
		player.UserId
	)
	-- Guidance costs only; authoritative intrusion checks remain in ProfileService.
	local volume = Instance.new("Part")
	volume.Name = "NavigationVolume"
	volume.Size = Vector3.new(Rules.WIDTH, Rules.HEIGHT, Rules.DEPTH)
	volume.CFrame = CFrame.new(origin + Vector3.new(0, 4.5, 0))
	volume.Anchored, volume.Transparency = true, 1
	volume.CanCollide, volume.CanTouch, volume.CanQuery = false, false, false
	local modifier = Instance.new("PathfindingModifier")
	modifier.Label = "RoomOwner_" .. player.UserId
	modifier.Parent = volume
	volume.Parent = model
	model.Parent = workspace:WaitForChild("Homes")
	local home: Home = { model = model, origin = origin, spawn = spawn, ownerId = player.UserId }
	rooms[model] = home
	return home
end

function World.createHome(player: Player, slot: number): Home
	local x, z = Rules.origin(slot)
	local home = cloneRoom(player, "StarterDormTemplate_v1", Vector3.new(x, 0, z), 0)
	local spawn = home.spawn
	player.RespawnLocation = spawn
	player:SetAttribute("HomePosition", spawn.Position)
	return home
end

function World.createWorkplace(player: Player, home: Home): Home
	local room = cloneRoom(
		player,
		"ClientApartmentTemplate_v1",
		home.origin + Vector3.new(0, 0, 68),
		math.pi
	)
	room.model.Name = "Client_" .. player.UserId
	room.spawn.Enabled = false
	return room
end

function World.returnHome(player: Player, home: Home): boolean
	local character = player.Character
	if character == nil or not character:IsDescendantOf(workspace) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local seat = humanoid.SeatPart
	local releasedRoot: BasePart? = nil
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(character) then
			weld:Destroy()
		end
		humanoid.Sit = false
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") or not root:CanSetNetworkOwnership() then
			return false
		end
		-- Prevent a late position from the former seat owner undoing this teleport.
		root:SetNetworkOwner(nil)
		releasedRoot = root
	end
	character:PivotTo(home.spawn.CFrame + Vector3.new(0, 3, 0))
	local root = releasedRoot
	if root then
		task.delay(1, function()
			if
				root:IsDescendantOf(character)
				and character:IsDescendantOf(workspace)
				and root:CanSetNetworkOwnership()
			then
				root:SetNetworkOwnershipAuto()
			end
		end)
	end
	return true
end

function World.isIntruding(position: Vector3, home: Home, visitorId: number): boolean
	local relative = position - home.origin
	return Rules.contains(relative.X, relative.Y, relative.Z)
		and not Rules.mayEnter(home.ownerId, visitorId)
end

function World.isPrivateIntrusion(position: Vector3, visitorId: number): boolean
	for model, room in rooms do
		if model.Parent == nil then
			rooms[model] = nil
		elseif World.isIntruding(position, room, visitorId) then
			return true
		end
	end
	return false
end

return World
