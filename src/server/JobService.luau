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
local ClientScene = require("./ClientScene")
local Meeting = require("./Domain/ClientMeeting")
local Dialogue = require(ReplicatedStorage.Shared.ClientDialogue)
local FirstSteps = require(ReplicatedStorage.Shared.FirstSteps)
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
	scene: ClientScene.API?,
	lastTalk: number,
}
local Service = {}
function Service.start(profiles: ProfileService.API): ()
	local command = ReplicatedStorage:WaitForChild("JobCommand")
	local stateEvent = ReplicatedStorage:WaitForChild("JobState")
	assert(command:IsA("RemoteEvent") and stateEvent:IsA("RemoteEvent"), "Job remotes missing")
	local contexts: { [Player]: Context } = {}
	local talk: (Player, Context) -> ()
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
				scene = nil,
				lastTalk = -math.huge,
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
		if job == nil or job.status == "Abandoned" then
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
			local scene = ClientScene.create(room.model, player.UserId)
			ctx.scene = scene
			scene.prompt.Triggered:Connect(function(actor: Player)
				if actor == player then
					ensure(player, ctx)
					talk(player, ctx)
				end
			end)
		end
		local contract = EconomyConfig.contracts[job.templateId]
		local room = ctx.room
		assert(room, "Workplace missing after creation")
		local walls = ClientScene.configureWalls(
			room.model,
			contract ~= nil and contract.secondaryColorId ~= nil
		)
		if ctx.scene and contract then
			ctx.scene.apply(contract.roomStyle, contract.clientKey)
		end
		if job.status == "Completed" then
			for index, wall in walls do
				local id = if contract
					then (if index == 2
						then contract.secondaryColorId or contract.colorId
						else contract.colorId)
					else Config.colorId
				wall.Color = Color3.new(table.unpack(Config.palette[id] or Config.color))
			end
			ctx.wall = walls[#walls]
			ctx.character = player.Character
			return
		end
		local old = ctx.work
		if old == nil or old.jobId ~= job.id or ctx.character ~= player.Character then
			ctx.work = Painting.new(job.id, HttpService:GenerateGUID(false), os.clock(), Config, {
				primary = if contract then contract.colorId else Config.colorId,
				secondary = if contract then contract.secondaryColorId else nil,
			})
			ctx.character = player.Character
			for _, wall in walls do
				wall.Color = Color3.fromRGB(145, 148, 140)
			end
			local cloth = room.model:FindFirstChild("Protection")
			if cloth and cloth:IsA("BasePart") then
				cloth.Transparency = 1
			end
		end
		ctx.wall = walls[if ctx.work then Painting.surface(ctx.work) else 1]
	end
	local function phaseOf(p: Profile.Profile?, ctx: Context): string
		local job = if p then p.jobs.active else nil
		if job == nil or job.status == "Abandoned" then
			return "Offer"
		end
		if job.status == "Completed" then
			return "Completed"
		end
		if ctx.work and ctx.work.phase == "Ready" and not Painting.allReady(ctx.work) then
			return "SurfaceReady"
		end
		return if ctx.work then ctx.work.phase else "Inspect"
	end
	local function canTalk(player: Player, ctx: Context, phase: string, available: boolean): boolean
		local scene, character = ctx.scene, player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			scene == nil
			or character == nil
			or root == nil
			or not root:IsA("BasePart")
			or not scene.root:IsDescendantOf(workspace)
		then
			return false
		end
		if not available or not eligible(player, ctx) then
			return false
		end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { character, scene.resident }
		local direction = scene.root.Position - root.Position
		local distance = direction.Magnitude
		if distance ~= distance or distance > 8 then
			return false
		end
		local hit = workspace:Raycast(root.Position, direction, filter)
		local owner = scene.resident:GetAttribute("OwnerUserId")
		return Meeting.allowed({
			ownerId = if type(owner) == "number" then owner else -1,
			actorId = player.UserId,
			available = available,
			alive = true,
			distance = distance,
			visible = hit == nil,
			phase = phase,
		})
	end
	local function send(
		player: Player,
		ctx: Context,
		reason: string?,
		conversation: Dialogue.Dialogue?,
		acceptAck: Types.AcceptAck?
	): ()
		if player.Parent ~= Players then
			return
		end
		local p = profiles.read(player)
		local job = if p then p.jobs.active else nil
		local contract = if job then EconomyConfig.contracts[job.templateId] else nil
		local reward = if job then EconomyConfig.rewards[job.templateId] else nil
		local work, room, wall = ctx.work, ctx.room, ctx.wall
		local phase = phaseOf(p, ctx)
		local available = p ~= nil and not ctx.saving
		local scene = ctx.scene
		if scene then
			scene.prompt.Enabled = available and phase ~= "Offer"
		end
		local target = if wall
				and job
				and job.status ~= "Completed"
				and job.status ~= "Abandoned"
			then wall.CFrame:PointToWorldSpace(
				Vector3.new(if work and Painting.surface(work) == 2 then -3 else 0, -1.5, 7)
			)
			else nil
		if
			target
			and scene
			and (phase == "Inspect" or phase == "Ready" or phase == "SurfaceReady")
		then
			target = scene.root.CFrame:PointToWorldSpace(Vector3.new(0, 0, -3))
		end
		local snapshot: Types.Snapshot = {
			acceptAck = acceptAck,
			available = available,
			phase = phase,
			jobId = if job then job.id elseif work then work.jobId else "",
			workId = if work then work.workId else "",
			sequence = if work then work.seq else 0,
			mask = if work then Painting.mask(work) else "",
			count = if work then work.count else 0,
			reward = if job and job.receipt
				then job.receipt.dollarsDelta
				elseif reward then reward.dollars
				else EconomyConfig.rewards["paint-tutorial-v1"].dollars,
			result = if p then Result.read(p) else nil,
			near = eligible(player, ctx),
			error = reason,
			location = if room then room.model.Name else nil,
			wallName = if wall then wall.Name else nil,
			wallId = if work and Painting.surface(work) == 2 then "wall-b" else Config.wallId,
			surfaceIndex = if work then Painting.surface(work) else 1,
			surfaceTotal = if contract and contract.secondaryColorId then 2 else 1,
			destination = if target then { target.X, target.Y, target.Z } else nil,
			offers = Jobs.offers(p),
			paintingXP = if p then p.progression.paintingXP else 0,
			contractId = if job then job.templateId else nil,
			requiredColorId = if work
				then work.config.colorId
				elseif contract then contract.colorId
				else Config.colorId,
			toolId = if work then work.toolId else "basic",
			clientKey = if contract then contract.clientKey else nil,
			canTalk = canTalk(player, ctx, phase, available),
			conversation = conversation,
			firstSteps = FirstSteps.evaluate(if p
				then {
					completed = p.onboarding.completed,
					paid = p.jobs.completedCount > 0,
					ownsFurniture = next(p.inventory) ~= nil,
					phase = phase,
				}
				else nil),
		}
		stateEvent:FireClient(player, snapshot)
	end
	talk = function(player: Player, ctx: Context): ()
		local now = os.clock()
		if now - ctx.lastTalk < 1 then
			return
		end
		ctx.lastTalk = now
		local p = profiles.read(player)
		local job = if p then p.jobs.active else nil
		local contract = if job then EconomyConfig.contracts[job.templateId] else nil
		local phase = phaseOf(p, ctx)
		if contract == nil or not canTalk(player, ctx, phase, p ~= nil and not ctx.saving) then
			send(player, ctx, "TooFar", nil)
			return
		end
		send(player, ctx, nil, Dialogue.describe(contract.clientKey, phase))
	end
	local function changed(player: Player): ()
		local ctx = contextFor(player)
		ensure(player, ctx)
		local p = profiles.read(player)
		if p and p.jobs.active and p.jobs.active.status == "Completed" and ctx.wall then
			local cloth = if ctx.room then ctx.room.model:FindFirstChild("Protection") else nil
			if cloth and cloth:IsA("BasePart") then
				cloth.Transparency = 1
			end
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
			requestId = true,
			action = true,
			jobId = true,
			workId = true,
			wallId = true,
			sequence = true,
			points = true,
			starts = true,
			color = true,
			offerId = true,
			toolId = true,
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
			if
				type(data.jobId) ~= "string"
				or #data.jobId > 80
				or type(data.requestId) ~= "string"
				or #data.requestId == 0
				or #data.requestId > 80
			then
				return
			end
			local previousJobId = data.jobId
			local requestId = data.requestId
			local current = p.jobs.active
			if previousJobId ~= (if current then current.id else "") then
				send(player, ctx, "Stale")
				return
			end
			if data.offerId ~= nil and (type(data.offerId) ~= "string" or #data.offerId > 80) then
				return
			end
			local offerId = if type(data.offerId) == "string"
				then data.offerId
				else "paint-tutorial-v1"
			local contract = EconomyConfig.contracts[offerId]
			if contract == nil or not contract.offered then
				send(player, ctx, "UnknownOffer", nil, {
					requestId = requestId,
					jobId = previousJobId,
					offerId = offerId,
					error = "UnknownOffer",
				})
				return
			end
			if p.progression.paintingXP < contract.minXP then
				send(player, ctx, "OfferLocked", nil, {
					requestId = requestId,
					jobId = previousJobId,
					offerId = offerId,
					error = "OfferLocked",
				})
				return
			end
			ctx.saving = true
			local id = HttpService:GenerateGUID(false)
			local ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				local previous = candidate.jobs.active
				if previousJobId ~= (if previous then previous.id else "") then
					return false
				end
				return Jobs.accept(candidate, id, offerId)
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
		if action == "talk" then
			if
				job == nil
				or data.jobId ~= job.id
				or data.workId ~= (if work then work.workId else "")
			then
				send(player, ctx, "Stale", nil)
				return
			end
			talk(player, ctx)
			return
		end
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
				data.wallId ~= (if Painting.surface(work) == 2 then "wall-b" else Config.wallId)
				or type(data.sequence) ~= "number"
				or type(data.starts) ~= "boolean"
			then
				return
			end
			ok = Painting.batch(work, data.sequence, data.points, data.starts, now, valid)
		elseif action == "nextSurface" then
			ok = valid and Painting.nextSurface(work, HttpService:GenerateGUID(false), now)
			if ok then
				ensure(player, ctx)
			end
		elseif action == "tool" then
			if type(data.toolId) ~= "string" or #data.toolId > 16 then
				return
			end
			ok = valid and Painting.tool(work, data.toolId, p.progression.paintingXP)
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
				ctx.wall.Color =
					Color3.new(table.unpack(Config.palette[work.config.colorId] or Config.color))
			end
		else
			local color = if type(data.color) == "string" and #data.color <= 32
				then data.color
				else nil
			ok = Painting.step(work, action, color, now, valid)
			if ok and action == "review" and ctx.wall then
				ctx.wall.Color =
					Color3.new(table.unpack(Config.palette[work.config.colorId] or Config.color))
			end
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
				elseif action == "review" then Painting.reviewError(work, now) or "Retry"
				elseif action == "tool" then "ToolLocked"
				else "Retry"
		)
	end)
end
return Service
