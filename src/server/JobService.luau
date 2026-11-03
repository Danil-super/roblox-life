--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ProfileService = require("./ProfileService")
local Profile = require("./Domain/Profile")
local Jobs = require("./Domain/Jobs")
local Result = require("./Domain/JobResult")
local Painting = require("./Domain/Painting")
local EconomyConfig = require("./Domain/EconomyConfig")
local World = require("./World")
local Config = require(ReplicatedStorage.Shared.PaintConfig)
local Types = require(ReplicatedStorage.Shared.JobTypes)
type Context = {
	work: Painting.State?,
	room: World.Home?,
	wall: BasePart?,
	character: Model?,
	saving: boolean,
	tokens: number,
	lastAt: number,
}
local Service = {}
function Service.start(profiles: ProfileService.API): ()
	local command = ReplicatedStorage:WaitForChild("JobCommand")
	local stateEvent = ReplicatedStorage:WaitForChild("JobState")
	assert(command:IsA("RemoteEvent") and stateEvent:IsA("RemoteEvent"), "Job remotes missing")
	local contexts: { [Player]: Context } = {}
	local function contextFor(player: Player): Context
		local ctx = contexts[player]
		if ctx == nil then
			ctx = {
				work = nil,
				room = nil,
				wall = nil,
				character = nil,
				saving = false,
				tokens = 30,
				lastAt = os.clock(),
			}
			contexts[player] = ctx
		end
		return ctx
	end
	local function eligible(player: Player, ctx: Context): boolean
		local wall, character = ctx.wall, player.Character
		if
			player.Parent ~= Players
			or character == nil
			or not character:IsDescendantOf(workspace)
			or character ~= ctx.character
			or wall == nil
			or not wall:IsDescendantOf(workspace)
		then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
			return false
		end
		local direction = wall.Position - root.Position
		local distance = direction.Magnitude
		if distance ~= distance or distance > Config.maxDistance then
			return false
		end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, direction, filter)
		return hit == nil or hit.Instance == wall
	end
	local function ensure(player: Player, ctx: Context): ()
		local p = profiles.read(player)
		if p == nil then
			return
		end
		local job = p.jobs.active
		if job == nil or job.status == "Completed" or job.status == "Abandoned" then
			return
		end
		if ctx.room == nil then
			local home = profiles.home(player)
			if home == nil then
				return
			end
			local room = World.createWorkplace(player, home)
			ctx.room = room
			local wall = room.model:FindFirstChild("PaintableWall")
			assert(wall ~= nil and wall:IsA("BasePart"), "Work wall missing")
			ctx.wall = wall
		end
		local old = ctx.work
		if old == nil or old.jobId ~= job.id or ctx.character ~= player.Character then
			ctx.work = Painting.new(
				job.id,
				HttpService:GenerateGUID(false),
				os.clock(),
				table.clone(Config)
			)
			ctx.character = player.Character
			local wall = ctx.wall
			if wall ~= nil then
				wall.Color = Color3.fromRGB(145, 148, 140)
			end
			local room = ctx.room
			local cloth = if room then room.model:FindFirstChild("Protection") else nil
			if cloth and cloth:IsA("BasePart") then
				cloth.Transparency = 1
			end
		end
	end
	local function send(player: Player, ctx: Context, reason: string?): ()
		if player.Parent ~= Players then
			return
		end
		local p = profiles.read(player)
		local job = if p then p.jobs.active else nil
		local work, room, wall = ctx.work, ctx.room, ctx.wall
		local phase = if work then work.phase else "Offer"
		if job and job.status == "Completed" then
			phase = "Completed"
		elseif job and job.status == "Abandoned" then
			phase = "Offer"
		end
		local target = if wall
				and job
				and job.status ~= "Completed"
				and job.status ~= "Abandoned"
			then wall.CFrame:PointToWorldSpace(Vector3.new(0, -1.5, 7))
			else nil
		local snapshot: Types.Snapshot = {
			available = p ~= nil and not ctx.saving,
			phase = phase,
			jobId = if job then job.id elseif work then work.jobId else "",
			workId = if work then work.workId else "",
			sequence = if work then work.seq else 0,
			mask = if work then Painting.mask(work) else "",
			count = if work then work.count else 0,
			reward = if job and job.receipt
				then job.receipt.dollarsDelta
				else EconomyConfig.rewards["paint-tutorial-v1"].dollars,
			result = if p then Result.read(p) else nil,
			near = eligible(player, ctx),
			error = reason,
			location = if room then room.model.Name else nil,
			destination = if target then { target.X, target.Y, target.Z } else nil,
		}
		stateEvent:FireClient(player, snapshot)
	end
	local function changed(player: Player): ()
		local ctx = contextFor(player)
		ensure(player, ctx)
		local p = profiles.read(player)
		if p and p.jobs.active and p.jobs.active.status == "Completed" and ctx.wall then
			ctx.wall.Color = Color3.new(table.unpack(Config.color))
		end
		send(player, ctx, nil)
	end
	profiles.changed:Connect(changed)
	local function add(player: Player): ()
		contextFor(player)
		player.CharacterRemoving:Connect(function()
			local ctx = contexts[player]
			if ctx then
				ctx.work = nil
				ctx.character = nil
				send(player, ctx, "Restart")
			end
		end)
		player.CharacterAdded:Connect(function()
			task.defer(changed, player)
		end)
	end
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player: Player)
		local ctx = contexts[player]
		if ctx and ctx.room then
			ctx.room.model:Destroy()
		end
		contexts[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		add(player)
		changed(player)
	end
	command.OnServerEvent:Connect(function(player: Player, raw: unknown)
		if type(raw) ~= "table" or player.Parent ~= Players then
			return
		end
		local ctx = contextFor(player)
		local now = os.clock()
		ctx.tokens = math.min(30, ctx.tokens + (now - ctx.lastAt) * 15)
		ctx.lastAt = now
		if ctx.tokens < 1 then
			return
		end
		ctx.tokens -= 1
		local data = raw :: { [string]: unknown }
		local size = 0
		local fields = {
			action = true,
			jobId = true,
			workId = true,
			wallId = true,
			sequence = true,
			points = true,
			starts = true,
			color = true,
		}
		for key in next, data do
			size += 1
			if size > 8 or not fields[key] then
				return
			end
		end
		local action = data.action
		if type(action) ~= "string" or #action > 16 then
			return
		end
		if action == "sync" then
			ensure(player, ctx)
			send(player, ctx, nil)
			return
		end
		if ctx.saving then
			return
		end
		local p = profiles.read(player)
		if p == nil then
			send(player, ctx, "Unavailable")
			return
		end
		if action == "accept" then
			ctx.saving = true
			local id = HttpService:GenerateGUID(false)
			local ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				return Jobs.accept(candidate, id)
			end)
			ctx.saving = false
			if ok then
				ensure(player, ctx)
			end
			send(player, ctx, if ok then nil else "Unavailable")
			return
		end
		ensure(player, ctx)
		local work = ctx.work
		local job = p.jobs.active
		if action == "submit" and job and job.status == "Completed" and data.jobId == job.id then
			send(player, ctx, nil)
			return
		end
		if
			work == nil
			or job == nil
			or job.status == "Completed"
			or job.status == "Abandoned"
			or data.jobId ~= work.jobId
			or data.workId ~= work.workId
		then
			send(player, ctx, "Stale")
			return
		end
		if action == "cancel" then
			ctx.saving = true
			local ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				return Jobs.cancel(candidate, work.jobId)
			end)
			ctx.saving = false
			if ok then
				ctx.work = nil
			end
			send(player, ctx, if ok then nil else "Unavailable")
			return
		end
		local valid = eligible(player, ctx)
		local ok = false
		if action == "stroke" then
			if
				data.wallId ~= Config.wallId
				or type(data.sequence) ~= "number"
				or type(data.starts) ~= "boolean"
			then
				return
			end
			ok = Painting.batch(work, data.sequence, data.points, data.starts, now, valid)
		elseif action == "submit" then
			ctx.saving = true
			local character = player.Character
			ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				return Jobs.submit(candidate, work, os.time(), valid)
			end, function(): boolean
				return contexts[player] == ctx
					and ctx.work == work
					and player.Character == character
					and eligible(player, ctx)
			end)
			ctx.saving = false
			if ok and ctx.wall then
				ctx.wall.Color = Color3.new(table.unpack(Config.color))
			end
		else
			local color = if type(data.color) == "string" and #data.color <= 32
				then data.color
				else nil
			ok = Painting.step(work, action, color, now, valid)
			if ok and action == "prepare" and ctx.room then
				local room = ctx.room
				local cloth = if room then room.model:FindFirstChild("Protection") else nil
				if cloth and cloth:IsA("BasePart") then
					cloth.Transparency = 0.35
				end
			end
		end
		send(
			player,
			ctx,
			if ok
				then nil
				elseif not valid then "TooFar"
				elseif action == "choose" then "Color"
				elseif action == "review" then "Coverage"
				else "Retry"
		)
	end)
end
return Service
