--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService").Server
local Storage = require(Server.Storage)
local Profile = require(Server.Domain.Profile)

local stages = table.freeze({
	["wall-before"] = true,
	["wall-after"] = true,
	["furniture-before"] = true,
	["furniture-after"] = true,
})

return function(stage: string): string
	assert(stages[stage], "Unknown SAVE-01 stage")
	assert(
		RunService:IsStudio()
			and RunService:IsRunning()
			and RunService:IsServer()
			and not Storage.preview
			and not Storage.blocked
			and Storage.name == "NeighborhoodFixer_P0_StudioQA_v1"
			and string.sub(Storage.scope, 1, 3) == "qa-",
		"Open solo server Play in the configured test Place with a named run"
	)
	local players = Players:GetPlayers()
	assert(#players == 1, "SAVE-01 capture requires exactly one player")
	local player = players[1]
	assert(
		player.UserId > 0
			and player:GetAttribute("ProfileStatus") == "Ready"
			and player:GetAttribute("StorageMode") == "Persistent",
		"Wait for the confirmed persistent player profile"
	)
	local store = DataStoreService:GetDataStore(Storage.name, Storage.scope)
	local options = Instance.new("DataStoreGetOptions")
	options.UseCache = false
	local succeeded, record = pcall(function(): unknown
		return store:GetAsync("player:" .. player.UserId, options)
	end)
	assert(succeeded and type(record) == "table", "Could not read the saved QA profile")
	local raw = record :: { [string]: unknown }
	assert(
		raw.recordVersion == 1
			and Profile.integer(raw.fence, 1, 9007199254740991)
			and Profile.identifier(raw.leaseOwner)
			and type(raw.leaseUntil) == "number"
			and raw.leaseUntil > os.time(),
		"Saved QA record lacks an active lease"
	)
	local profile = Profile.decode(raw.profile, player.UserId)
	assert(profile, "Saved QA profile failed validation")
	local stats = player:FindFirstChild("leaderstats")
	local dollars = if stats then stats:FindFirstChild("Dollars") else nil
	assert(
		player.Parent == Players
			and player:GetAttribute("ProfileStatus") == "Ready"
			and player:GetAttribute("PaintingXP") == profile.progression.paintingXP
			and player:GetAttribute("OnboardingStep") == profile.onboarding.step
			and dollars ~= nil
			and dollars:IsA("IntValue")
			and dollars.Value == profile.wallet.dollars,
		"Saved profile and running game disagree"
	)
	local job = profile.jobs.active
	assert(job and job.templateId == "paint-tutorial-v1", "Keep the tutorial as the current QA job")
	local inventory = {}
	for itemId, item in profile.inventory do
		table.insert(inventory, {
			id = itemId,
			catalog = item.catalogItemId,
			price = item.paidDollars,
			pose = profile.housing.placements[itemId],
		})
	end
	return "SAVE01 "
		.. HttpService:JSONEncode({
			schema = 1,
			stage = stage,
			universe = game.GameId,
			place = game.PlaceId,
			scope = Storage.scope,
			fence = raw.fence,
			revision = profile.revision,
			dollars = profile.wallet.dollars,
			xp = profile.progression.paintingXP,
			step = profile.onboarding.step,
			completed = profile.jobs.completedCount,
			housingRevision = profile.housing.revision,
			job = {
				id = job.id,
				status = job.status,
				cells = job.checkpoint or job.finish,
				reward = if job.receipt then job.receipt.dollarsDelta else nil,
			},
			items = inventory,
		})
end
