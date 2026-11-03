--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Store = require("./Domain/ProfileStore")
local Profile = require("./Domain/Profile")
local RoomRules = require("./Domain/RoomRules")
local Storage = require("./Storage")
local World = require("./World")
local Recovery = require("./Domain/ProfileRecovery")
local Diagnostics = require("./Diagnostics")
export type API = {
	read: (Player) -> Profile.Profile?,
	home: (Player) -> World.Home?,
	change: (Player, (Profile.Profile) -> boolean, (() -> boolean)?) -> (boolean, string?),
	changed: RBXScriptSignal,
}
type Context = {
	session: Store.Session,
	busy: boolean,
	closing: boolean,
	home: World.Home?,
	slot: number,
	lastHomeRequest: number,
	dollars: IntValue?,
	spawnRequested: boolean,
	spawning: boolean,
	nextSpawnAt: number,
	failure: string?,
	lastRetry: number,
	trace: string,
}
local Service = {}
local LEASE_SECONDS, HEARTBEAT_SECONDS = 120, 30

function Service.start(): API
	Players.CharacterAutoLoads = false
	local adapter = Storage.create()
	local contexts: { [Player]: Context } = {}
	local slots: { [number]: boolean } = {}
	local shuttingDown = false
	local changed = Instance.new("BindableEvent")
	local remote = ReplicatedStorage:WaitForChild("ReturnHome")
	assert(remote:IsA("RemoteEvent"), "ReturnHome must be a RemoteEvent")
	local profileRemote = ReplicatedStorage:WaitForChild("ProfileCommand")
	assert(profileRemote:IsA("RemoteEvent"), "ProfileCommand must be a RemoteEvent")
	local RETRY_SECONDS = 10
	local function refreshRecovery(player: Player, context: Context): ()
		if contexts[player] ~= context or context.closing or player.Parent ~= Players then
			return
		end
		local allowed = Recovery.action(context.session.status(), context.failure, Storage.blocked)
			~= nil
		player:SetAttribute("ProfileRecoveryAllowed", allowed)
		player:SetAttribute(
			"ProfileCanRetry",
			allowed and not context.busy and os.clock() - context.lastRetry >= RETRY_SECONDS
		)
	end
	local function fail(
		player: Player,
		context: Context,
		reason: string?,
		entry: Diagnostics.Entry
	): ()
		context.failure = reason or "StorageUnavailable"
		player:SetAttribute(
			"ProfileErrorCode",
			Recovery.code(context.session.status(), context.failure, Storage.blocked)
		)
		refreshRecovery(player, context)
		player:SetAttribute("ProfileStatus", "Error")
		Diagnostics.emit("profile_failure", context.trace, entry, false, context.failure)
		local delay = math.max(0, RETRY_SECONDS - (os.clock() - context.lastRetry))
		if delay > 0 then
			task.delay(delay, function()
				if player:GetAttribute("ProfileStatus") == "Error" then
					refreshRecovery(player, context)
				end
			end)
		end
	end

	local function publish(player: Player, context: Context): ()
		local profile = context.session.read()
		if profile == nil then
			return
		end
		local dollars: IntValue = context.dollars or Instance.new("IntValue")
		if context.dollars == nil then
			local stats = Instance.new("Folder")
			stats.Name = "leaderstats"
			dollars.Name = "Dollars"
			dollars.Parent = stats
			stats.Parent = player
			context.dollars = dollars
		end
		dollars.Value = profile.wallet.dollars
		player:SetAttribute("PaintingXP", profile.progression.paintingXP)
		player:SetAttribute("OnboardingStep", profile.onboarding.step)
		context.failure = nil
		player:SetAttribute("ProfileErrorCode", nil)
		player:SetAttribute("ProfileRecoveryAllowed", false)
		player:SetAttribute("ProfileCanRetry", false)
		player:SetAttribute("ProfileStatus", "Ready")
		changed:Fire(player)
	end

	local function recover(session: Store.Session): (boolean, string?)
		local reason: string? = nil
		for attempt = 1, 3 do
			if session.status() ~= "Uncertain" then
				return session.status() == "Ready" or session.status() == "Closed", reason
			end
			task.wait(2 ^ (attempt - 1) + math.random() * 0.5)
			local ok, why = session.retry()
			reason = why
			if ok then
				return true, nil
			end
		end
		return false, reason
	end

	local function close(player: Player, context: Context): ()
		if context.closing then
			return
		end
		context.closing = true
		local deadline = os.clock() + 20
		while context.busy and os.clock() < deadline do
			task.wait(0.1)
		end
		if not context.busy then
			context.busy = true
			recover(context.session)
			if context.session.status() == "Ready" then
				if not context.session.close() then
					recover(context.session)
				end
			end
			context.busy = false
		end
		local home = context.home
		if home ~= nil then
			home.model:Destroy()
		end
		slots[context.slot] = nil
		contexts[player] = nil
	end

	local function spawnCharacter(player: Player, context: Context): ()
		if
			context.closing
			or context.busy
			or context.spawning
			or not context.spawnRequested
			or context.home == nil
			or os.clock() < context.nextSpawnAt
			or shuttingDown
			or player.Parent ~= Players
			or context.session.read() == nil
		then
			return
		end
		context.spawning, context.spawnRequested = true, false
		local ok = pcall(function(): ()
			player:LoadCharacterAsync()
		end)
		context.spawning = false
		if not ok and player.Parent == Players then
			context.spawnRequested, context.nextSpawnAt = true, os.clock() + 3
			fail(player, context, "CharacterLoad", "spawn")
		end
	end

	local function finalizeReady(player: Player, context: Context): ()
		if context.closing or shuttingDown or player.Parent ~= Players then
			return
		end
		local profile = context.session.read()
		if profile == nil then
			return
		end
		if
			profile.housing.roomTemplateId ~= "StarterDormTemplate_v1"
			or profile.housing.roomTemplateVersion ~= 1
		then
			fail(player, context, "RoomVersion", "join")
			return
		end
		if context.home == nil then
			context.home = World.createHome(player, context.slot)
		end
		publish(player, context)
		task.spawn(spawnCharacter, player, context)
	end

	local function addPlayer(player: Player): ()
		if contexts[player] ~= nil or shuttingDown then
			return
		end
		player:SetAttribute("ProfileStatus", "Loading")
		player:SetAttribute("StorageMode", if Storage.preview then "Preview" else "Persistent")
		local slot: number? = nil
		for index = 1, RoomRules.SLOTS do
			if not slots[index] then
				slot = index
				break
			end
		end
		if slot == nil then
			player:Kick("This server is full. Please join another server.")
			return
		end
		slots[slot] = true
		-- Simulated Studio clients have negative IDs. Map them only in explicit memory preview.
		local ownerId = if Storage.preview and player.UserId <= 0
			then 9000000000000 + math.abs(player.UserId)
			else player.UserId
		if not Profile.integer(ownerId, 1, 9007199254740991) then
			slots[slot] = nil
			player:SetAttribute("ProfileStatus", "Error")
			player:SetAttribute("ProfileErrorCode", "InvalidOwner")
			return
		end
		local context: Context = {
			session = Store.new(
				adapter,
				ownerId,
				HttpService:GenerateGUID(false),
				os.time,
				LEASE_SECONDS
			),
			busy = true,
			closing = false,
			home = nil,
			slot = slot,
			lastHomeRequest = -math.huge,
			dollars = nil,
			spawnRequested = true,
			spawning = false,
			nextSpawnAt = 0,
			failure = nil,
			lastRetry = -math.huge,
			trace = HttpService:GenerateGUID(false),
		}
		contexts[player] = context
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 15)
			if humanoid == nil or not humanoid:IsA("Humanoid") then
				return
			end
			humanoid.Died:Once(function()
				task.delay(Players.RespawnTime, function(): ()
					if player.Character ~= character or context.closing then
						return
					end
					context.spawnRequested = true
					task.spawn(spawnCharacter, player, context)
				end)
			end)
		end)
		local loaded, loadReason = context.session.load()
		if not loaded and context.session.status() == "Uncertain" then
			loaded, loadReason = recover(context.session)
		end
		context.busy = false
		if context.closing or player.Parent ~= Players then
			return
		end
		if not loaded then
			fail(player, context, loadReason, "join")
			return
		end
		Diagnostics.emit("profile_load", context.trace, "join", true, nil)
		finalizeReady(player, context)
	end

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		local context = contexts[player]
		if context ~= nil then
			close(player, context)
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end

	profileRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
		if type(action) ~= "string" then
			return
		end
		if action == "exit" then
			if
				player:GetAttribute("ProfileStatus") == "Error"
				or player:GetAttribute("ProfileStatus") == "Loading"
			then
				player:Kick(
					"Session closed safely. Please rejoin. / Сессия закрыта. Можно зайти снова."
				)
			end
			return
		end
		local context = contexts[player]
		if
			action ~= "retry"
			or context == nil
			or context.busy
			or context.closing
			or shuttingDown
			or player:GetAttribute("ProfileStatus") ~= "Error"
			or os.clock() - context.lastRetry < RETRY_SECONDS
			or Recovery.action(context.session.status(), context.failure, Storage.blocked)
				== nil
		then
			return
		end
		context.lastRetry, context.busy = os.clock(), true
		player:SetAttribute("ProfileCanRetry", false)
		player:SetAttribute("ProfileStatus", "Loading")
		Diagnostics.emit("profile_recovery", context.trace, "manual", true, "Requested")
		local ok, reason = Recovery.attempt(context.session, context.failure, Storage.blocked)
		context.busy = false
		if context.closing or player.Parent ~= Players then
			return
		end
		Diagnostics.emit("profile_recovery", context.trace, "manual", ok, reason)
		if ok then
			finalizeReady(player, context)
		else
			fail(player, context, reason, "manual")
		end
	end)

	remote.OnServerEvent:Connect(function(player: Player)
		local context = contexts[player]
		if context == nil or context.closing or context.busy or context.session.read() == nil then
			return
		end
		local now = os.clock()
		if now - context.lastHomeRequest < 2 then
			return
		end
		context.lastHomeRequest = now
		local home = context.home
		if home ~= nil then
			World.returnHome(player, home)
		end
	end)

	task.spawn(function()
		while not shuttingDown do
			task.wait(HEARTBEAT_SECONDS)
			for player, context in contexts do
				if context.closing or context.busy or context.session.status() == "Blocked" then
					continue
				end
				context.busy = true
				task.spawn(function()
					local saved: boolean
					local reason: string?
					if context.session.status() == "Uncertain" then
						saved, reason = recover(context.session)
					else
						saved, reason = context.session.renew()
					end
					if not saved then
						saved, reason = recover(context.session)
					end
					context.busy = false
					if not context.closing and player.Parent == Players then
						if saved then
							finalizeReady(player, context)
						else
							fail(player, context, reason, "heartbeat")
						end
					end
				end)
			end
		end
	end)

	task.spawn(function()
		while not shuttingDown do
			task.wait(0.5)
			for player, context in contexts do
				if context.closing then
					continue
				end
				if context.spawnRequested and not context.spawning then
					task.spawn(spawnCharacter, player, context)
				end
				local character = player.Character
				local root = if character ~= nil
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				if root == nil or not root:IsA("BasePart") then
					continue
				end
				local home = context.home
				if home ~= nil and World.isPrivateIntrusion(root.Position, player.UserId) then
					World.returnHome(player, home)
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		for player, context in contexts do
			task.spawn(close, player, context)
		end
		local deadline = os.clock() + 25
		while next(contexts) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	print(
		"[NeighborhoodFixer] Profile service ready; storage="
			.. (if Storage.preview then "StudioMemoryPreview" else Storage.name)
	)
	return {
		changed = changed.Event,
		read = function(player: Player): Profile.Profile?
			local context = contexts[player]
			return if context ~= nil and not context.closing then context.session.read() else nil
		end,
		home = function(player: Player): World.Home?
			local context = contexts[player]
			return if context ~= nil and not context.closing then context.home else nil
		end,
		change = function(
			player: Player,
			mutate: (Profile.Profile) -> boolean,
			guard: (() -> boolean)?
		): (boolean, string?)
			local context = contexts[player]
			if context == nil or context.busy or context.closing or player.Parent ~= Players then
				return false, "NotReady"
			end
			context.busy = true
			player:SetAttribute("ProfileStatus", "Saving")
			local ok, reason = context.session.transact(mutate, function(): boolean
				return not context.closing
					and player.Parent == Players
					and (guard == nil or guard())
			end)
			context.busy = false
			if not context.closing and player.Parent == Players then
				if context.session.status() == "Ready" then
					publish(player, context)
				else
					fail(player, context, reason, "change")
				end
			end
			return ok, reason
		end,
	}
end

return Service
