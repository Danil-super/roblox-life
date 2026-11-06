--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local ProfileService = require("./ProfileService")
local Profile = require("./Domain/Profile")
local Economy = require("./Domain/Economy")
local Config = require("./Domain/EconomyConfig")
local Furniture = require("./Domain/Furniture")
local RoomRules = require("./Domain/RoomRules")
local Models = require(RS.Assets.FurnitureModels)
local Types = require(RS.Shared.HomeTypes)
local HomePlan = require(RS.Shared.HomePlan)
local HomeLights = require("./HomeLights")
local Service = {}
type Context = {
	editorId: string,
	character: Model?,
	saving: boolean,
	tokens: number,
	lastAt: number,
}
function Service.start(profiles: ProfileService.API): ()
	local command = RS:WaitForChild("HomeCommand")
	local state = RS:WaitForChild("HomeState")
	local preview = RS:WaitForChild("HomePreview")
	assert(
		command:IsA("RemoteEvent") and state:IsA("RemoteEvent") and preview:IsA("RemoteEvent"),
		"Home remotes missing"
	)
	local shop = workspace:WaitForChild("NeighborhoodShop")
	local counter = shop:WaitForChild("Counter")
	assert(counter:IsA("BasePart"), "Shop counter missing")
	local displays = {
		{ id = "floor-plant-v1", x = 24, z = -8, yaw = 0 },
		{ id = "side-table-v1", x = 27, z = -8, yaw = 0 },
		{ id = "floor-lamp-v1", x = 30, z = -8, yaw = 0 },
		{ id = "reading-chair-v1", x = 34, z = -8, yaw = 0 },
		{ id = "bookcase-v1", x = 39, z = -8, yaw = 0 },
		{ id = "cozy-sofa-v1", x = 25.8, z = 5, yaw = 0 },
		{ id = "floor-easel-v1", x = 39, z = 0, yaw = math.pi },
		{ id = "floor-planter-v1", x = 38.5, z = 5, yaw = 0 },
	}
	for index, display in displays do
		local model = Models.create(display.id)
		if model then
			model.Name = "Display" .. index
			model:PivotTo(CFrame.new(display.x, 0, display.z) * CFrame.Angles(0, display.yaw, 0))
			model.Parent = shop
		end
	end
	local contexts: { [Player]: Context } = {}
	local function context(player: Player): Context
		local c = contexts[player]
		if c == nil then
			c = {
				editorId = Http:GenerateGUID(false),
				character = player.Character,
				saving = false,
				tokens = 24,
				lastAt = os.clock(),
			}
			contexts[player] = c
		end
		if c.character ~= player.Character then
			c.character = player.Character
			c.editorId = Http:GenerateGUID(false)
		end
		return c
	end
	local function root(player: Player): BasePart?
		local char = player.Character
		if player.Parent ~= Players or char == nil or not char:IsDescendantOf(workspace) then
			return nil
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local part = char:FindFirstChild("HumanoidRootPart")
		return if humanoid
				and humanoid.Health > 0
				and part
				and part:IsA("BasePart")
			then part
			else nil
	end
	local function atHome(player: Player): boolean
		local home = profiles.home(player)
		local part = root(player)
		if
			home == nil
			or part == nil
			or home.model:GetAttribute("OwnerUserId") ~= player.UserId
		then
			return false
		end
		local p = part.Position - home.origin
		return RoomRules.contains(p.X, p.Y, p.Z)
	end
	local function atShop(player: Player): boolean
		local part = root(player)
		if part == nil then
			return false
		end
		local p = part.Position
		return math.abs(p.X - 32) < 10
			and p.Z > -10
			and p.Z < 12
			and p.Y > 0
			and p.Y < 9
			and (p - counter.Position).Magnitude < 14
	end
	local function reconcile(player: Player, p: Profile.Profile): ()
		local home = profiles.home(player)
		if home == nil then
			return
		end
		local folder = home.model:FindFirstChild("Furniture")
		if folder == nil then
			local created = Instance.new("Folder")
			created.Name = "Furniture"
			created.Parent = home.model
			folder = created
		end
		assert(folder ~= nil, "Furniture folder missing")
		for _, model in folder:GetChildren() do
			if p.housing.placements[model.Name] == nil then
				model:Destroy()
			end
		end
		for id, placed in p.housing.placements do
			local item = p.inventory[id]
			local valid = Furniture.validate(
				p,
				id,
				{ x = placed.x, z = placed.z, rotationY = placed.rotationY, mode = "Free" },
				p.housing.revision
			)
			local model = folder:FindFirstChild(id)
			if item and valid then
				if model == nil then
					local created = Models.create(item.catalogItemId)
					if created then
						created.Name = id
						created:SetAttribute("OwnerUserId", player.UserId)
						created:SetAttribute("CatalogId", item.catalogItemId)
						for _, descendant in created:GetDescendants() do
							if descendant:IsA("Seat") then
								descendant.Disabled = false
							end
						end
						created.Parent = folder
						model = created
					end
				end
				if model and model:IsA("Model") then
					model:PivotTo(
						CFrame.new(home.origin + Vector3.new(placed.x, 0, placed.z))
							* CFrame.Angles(0, math.rad(placed.rotationY), 0)
					)
					HomeLights.attach(model, player, profiles)
				end
			elseif model then
				model:Destroy()
			end
		end
	end
	local function send(
		player: Player,
		reason: string?,
		ack: string?,
		openShop: boolean?,
		placementAck: string?,
		storeAck: string?
	): ()
		if player.Parent ~= Players then
			return
		end
		local c = context(player)
		local p = profiles.read(player)
		local home = profiles.home(player)
		local items: { Types.Owned } = {}
		local catalog: { Types.Product } = {}
		for id, product in Config.catalog do
			local entry: Types.Product = {
				id = id,
				dollars = product.dollars,
				modelVersion = product.modelVersion,
				width = product.width,
				depth = product.depth,
				height = product.height,
			}
			table.insert(catalog, entry)
		end
		table.sort(catalog, function(a: Types.Product, b: Types.Product): boolean
			return a.id < b.id
		end)
		if p then
			for id, item in p.inventory do
				local placed = p.housing.placements[id]
				local entry: Types.Owned = {
					id = id,
					catalogId = item.catalogItemId,
					purchaseOperationId = item.purchaseOperationId,
					placed = if placed
						then { x = placed.x, z = placed.z, rotationY = placed.rotationY }
						else nil,
				}
				table.insert(items, entry)
			end
			table.sort(items, function(a: Types.Owned, b: Types.Owned): boolean
				return a.id < b.id
			end)
		end
		local o = if home then home.origin else Vector3.zero
		local snapshot: Types.Snapshot = {
			layout = Furniture.layout,
			available = p ~= nil and not c.saving,
			dollars = if p then p.wallet.dollars else 0,
			revision = if p then p.housing.revision else 0,
			editorId = c.editorId,
			homeName = if home then home.model.Name else "",
			origin = { o.X, o.Y, o.Z },
			nearHome = atHome(player),
			nearShop = atShop(player),
			items = items,
			catalog = catalog,
			onboarding = if p then p.onboarding.step else "INTRO",
			error = reason,
			ack = ack,
			placementAck = placementAck,
			storeAck = storeAck,
			openShop = openShop,
			plan = if p then HomePlan.evaluate(items) else nil,
		}
		state:FireClient(player, snapshot)
	end
	local function changed(player: Player): ()
		local p = profiles.read(player)
		if p then
			reconcile(player, p)
		end
		send(player, nil, nil, nil)
	end
	profiles.changed:Connect(changed)
	local function add(player: Player): ()
		context(player)
		player.CharacterAdded:Connect(function()
			task.defer(changed, player)
		end)
		player.CharacterRemoving:Connect(function()
			local c = contexts[player]
			if c then
				c.editorId = Http:GenerateGUID(false)
				c.character = nil
				send(player, "Restart", nil, nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player: Player)
		contexts[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		add(player)
		changed(player)
	end
	local prompt = counter:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			if atShop(player) then
				send(player, nil, nil, true)
			end
		end)
	end
	command.OnServerEvent:Connect(function(player: Player, raw: unknown)
		if player.Parent ~= Players or type(raw) ~= "table" then
			return
		end
		local c = context(player)
		local now = os.clock()
		c.tokens = math.min(24, c.tokens + (now - c.lastAt) * 12)
		c.lastAt = now
		if c.tokens < 1 then
			return
		end
		c.tokens -= 1
		local d = raw :: { [string]: unknown }
		local allowed = {
			action = true,
			editorId = true,
			requestId = true,
			catalogId = true,
			itemId = true,
			revision = true,
			pose = true,
			sequence = true,
		}
		local count = 0
		for k in next, d do
			count += 1
			if count > 8 or not allowed[k] then
				return
			end
		end
		local action = d.action
		if type(action) ~= "string" or #action > 12 then
			return
		end
		local commandRequestId = if type(d.requestId) == "string"
				and #d.requestId <= 80
				and Profile.identifier(d.requestId)
			then d.requestId
			else nil
		local purchaseRequestId = if action == "buy" then commandRequestId else nil
		local placementRequestId = if action == "place" then commandRequestId else nil
		local storeRequestId = if action == "store" then commandRequestId else nil
		if (action == "place" or action == "store") and commandRequestId == nil then
			return
		end

		if action == "sync" then
			send(player, nil, nil, nil)
			return
		end
		if c.saving then
			return
		end
		local p = profiles.read(player)
		if p == nil then
			send(player, "Unavailable", purchaseRequestId, nil, placementRequestId, storeRequestId)
			return
		end
		if action ~= "buy" and d.editorId ~= c.editorId then
			send(player, "StaleRevision", nil, nil, placementRequestId, storeRequestId)
			return
		end
		if action == "probe" then
			if
				type(d.itemId) ~= "string"
				or not Profile.integer(d.sequence, 1, 1000000000)
				or type(d.revision) ~= "number"
			then
				return
			end
			local pose, reason = Furniture.validate(p, d.itemId, d.pose, d.revision)
			if not atHome(player) then
				pose = nil
				reason = "GoHome"
			end
			local result: Types.Preview = {
				editorId = c.editorId,
				itemId = d.itemId,
				sequence = d.sequence :: number,
				revision = p.housing.revision,
				pose = pose,
				error = reason,
			}
			preview:FireClient(player, result)
			return
		end
		local character = player.Character
		local nonce = c.editorId
		local function guard(): boolean
			return contexts[player] == c
				and player.Character == character
				and c.editorId == nonce
				and (if action == "buy" then atShop(player) else atHome(player))
		end
		if not guard() then
			send(
				player,
				if action == "buy" then "GoShop" else "GoHome",
				purchaseRequestId,
				nil,
				placementRequestId,
				storeRequestId
			)
			return
		end
		local reason: string? = nil
		local ack: string? = nil
		local ok = false
		if action == "buy" then
			if
				type(d.requestId) ~= "string"
				or #d.requestId > 80
				or not Profile.identifier(d.requestId)
				or type(d.catalogId) ~= "string"
			then
				return
			end
			local requestId, catalogId = d.requestId, d.catalogId
			local itemId = Http:GenerateGUID(false)
			c.saving = true
			ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				local receipt, why =
					Economy.purchase(candidate, requestId, catalogId, itemId, os.time())
				reason = why
				return receipt ~= nil
			end, guard)
			ack = requestId
		elseif action == "place" or action == "store" then
			if type(d.itemId) ~= "string" or type(d.revision) ~= "number" then
				return
			end
			local id, revision = d.itemId, d.revision
			if
				action == "store"
				and Profile.identifier(id)
				and p.inventory[id] ~= nil
				and Profile.integer(revision, 0, 9007199254740991)
				and p.housing.placements[id] == nil
			then
				send(player, nil, nil, nil, nil, storeRequestId)
				return
			end
			if action == "place" then
				local pose, why = Furniture.validate(p, id, d.pose, revision)
				if pose == nil then
					send(player, why, nil, nil, placementRequestId)
					return
				end
				local old = p.housing.placements[id]
				if
					old
					and old.x == pose.x
					and old.z == pose.z
					and old.rotationY == pose.rotationY
				then
					-- Confirm a retry/no-op without another profile write or model.
					send(player, nil, nil, nil, placementRequestId)
					return
				end
			end
			c.saving = true
			ok = profiles.change(player, function(candidate: Profile.Profile): boolean
				local accepted: boolean
				local why: string?
				if action == "place" then
					accepted, why = Furniture.place(candidate, id, d.pose, revision)
				else
					accepted, why = Furniture.store(candidate, id, revision)
				end
				reason = why
				return accepted
			end, guard)
		end
		c.saving = false
		if ok then
			local confirmed = profiles.read(player)
			if confirmed then
				reconcile(player, confirmed)
			end
		end
		send(
			player,
			if ok then nil else reason or "Unavailable",
			ack,
			nil,
			placementRequestId,
			storeRequestId
		)
	end)
end
return Service
