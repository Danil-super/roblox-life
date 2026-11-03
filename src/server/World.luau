--!strict
local ServerStorage = game:GetService("ServerStorage")
local Rules = require("./Domain/RoomRules")
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
	character:PivotTo(home.spawn.CFrame + Vector3.new(0, 3, 0))
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
