--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Strings = require(RS.Shared.Strings)
local Models = require(RS.Assets.FurnitureModels)
local Types = require(RS.Shared.HomeTypes)
local PurchaseFlow = require(RS.Shared.PurchaseFlow)
local StoreFlow = require(RS.Shared.StoreFlow)
local Inventory = require(RS.Shared.FurnitureInventory)
local Goals = require(RS.Shared.NavigationGoal)
local Build = require("./BuildController")
local RoomPlanner = require("./HomePlannerController")
local Objective = require(RS.Shared.HomeObjective)
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	homePanel: Frame,
	language: () -> string,
	exclusive: () -> (),
	openJobs: () -> ()
)
	local player = Players.LocalPlayer
	local command = RS:WaitForChild("HomeCommand")
	local event = RS:WaitForChild("HomeState")
	local returnHome = RS:WaitForChild("ReturnHome")
	assert(
		command:IsA("RemoteEvent") and event:IsA("RemoteEvent") and returnHome:IsA("RemoteEvent"),
		"Home events missing"
	)
	local state: Types.Snapshot? = nil
	local lastError: string? = nil
	local errorUntil = 0
	local purchase: PurchaseFlow.Pending? = nil
	local storing: StoreFlow.Pending? = nil
	local purchasedItem: string? = nil
	local routeTarget: ("Home" | "Shop")? = nil
	local syncAt = 0
	local listKey = ""
	local focus: { tab: string, id: string }? = nil
	local inventoryFilter: Inventory.Filter = "All"
	local planner: RoomPlanner.API
	local function firstProduct(s: Types.Snapshot): string?
		local best: Types.Product? = nil
		for _, product in s.catalog do
			if product.dollars <= s.dollars then
				if product.id == "floor-plant-v1" then
					return product.id
				end
				if
					best == nil
					or product.dollars < best.dollars
					or (product.dollars == best.dollars and product.id < best.id)
				then
					best = product
				end
			end
		end
		return if best then best.id else nil
	end
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function round(p: GuiObject): ()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = p
	end
	local function text(
		parent: Instance,
		name: string,
		y: number,
		height: number,
		size: number
	): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromOffset(16, y)
		l.Size = UDim2.new(1, -32, 0, height)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(244, 239, 224)
		l.TextWrapped = true
		l.Font = Enum.Font.GothamMedium
		l.TextSize = size
		l.Parent = parent
		return l
	end
	local function button(parent: Instance, name: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.TextColor3 = Color3.fromRGB(244, 239, 224)
		b.BackgroundColor3 = Color3.fromRGB(55, 120, 102)
		b.TextSize = 14
		b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.Parent = parent
		round(b)
		return b
	end
	local function panel(name: string): (Frame, TextLabel, TextLabel, ScrollingFrame, TextButton)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.new(1, -24, 1, -24)
		f.BackgroundColor3 = Color3.fromRGB(26, 43, 43)
		f.ZIndex = 10
		f.Visible = false
		f.Parent = screen
		round(f)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(600, 488)
		limit.Parent = f
		local title = text(f, "Title", 8, 36, 22)
		local info = text(f, "Info", 48, 54, 14)
		local body = Instance.new("ScrollingFrame")
		body.Name = "Body"
		body.Position = UDim2.fromOffset(8, 110)
		body.Size = UDim2.new(1, -16, 1, -182)
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.ScrollBarThickness = 4
		body.Parent = f
		local back = button(f, "Back")
		back.Position = UDim2.new(0, 16, 1, -60)
		back.Size = UDim2.new(1, -32, 0, 48)
		return f, title, info, body, back
	end
	local shop, shopTitle, shopInfo, shopBody, shopBack = panel("ShopPanel")
	local inventory, inventoryTitle, inventoryInfo, inventoryBody, inventoryBack =
		panel("InventoryPanel")
	inventoryTitle.Visible = false
	inventoryInfo.Position, inventoryInfo.Size = UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 54)
	local filters = Instance.new("Frame")
	filters.Name, filters.Position, filters.Size =
		"Filters", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 44)
	filters.BackgroundTransparency, filters.Parent = 1, inventory
	local filterButtons: { [string]: TextButton } = {}
	local sections: { { id: Inventory.Filter } } =
		{ { id = "All" }, { id = "Stored" }, { id = "Placed" } }
	for index, entry in sections do
		local section: Inventory.Filter = entry.id
		local b = button(filters, section)
		b.Position, b.Size = UDim2.new((index - 1) / 3, 4, 0, 0), UDim2.new(1 / 3, -8, 1, 0)
		b.TextSize = 13
		filterButtons[section] = b
	end
	local returnButton = button(inventory, "ReturnHome")
	local routeButton = button(shop, "Route")
	local apps = homePanel:FindFirstChild("Apps")
	local homeRouteButton = if apps then apps:FindFirstChild("WalkHome") else nil
	assert(homeRouteButton and homeRouteButton:IsA("TextButton"), "Home route button missing")
	for _, back in { shopBack, inventoryBack } do
		back.Size = UDim2.new(0.5, -24, 0, 48)
	end
	for _, action in { returnButton, routeButton } do
		action.Position, action.Size = UDim2.new(0.5, 8, 1, -60), UDim2.new(0.5, -24, 0, 48)
	end

	local function send(action: string, fields: { [string]: unknown }?): ()
		local data: { [string]: unknown } = fields or {}
		data.action = action
		if state then
			data.editorId = state.editorId
		end
		command:FireServer(data)
	end
	local function hidePanels(): ()
		shop.Visible = false
		inventory.Visible = false
		planner.hide()
	end
	local function show(tab: string): ()
		if tab ~= "Shop" then
			routeTarget = nil
		end
		exclusive()
		homePanel.Visible = false
		hidePanels()
		shop.Visible = tab == "Shop"
		inventory.Visible = tab == "Furniture"
		if tab == "Room" then
			planner.show()
		end
		local current = state
		if
			tab == "Shop"
			and focus == nil
			and current
			and current.available
			and current.onboarding == "BUY"
			and purchase == nil
		then
			local productId = firstProduct(current)
			if productId then
				focus = { tab = "Shop", id = productId }
			end
		end
		listKey = ""
		send("sync", nil)
	end
	local builder = Build.start(screen, send, language, function(returnToInventory: boolean)
		if returnToInventory then
			show("Furniture")
		else
			hidePanels()
			homePanel.Visible = false
		end
	end)
	local function planBlocked(): boolean
		return purchase ~= nil
			or storing ~= nil
			or builder.isActive()
			or player:GetAttribute("ProfileStatus") ~= "Ready"
	end
	local function homeObjective(): Objective.Cue?
		return Objective.evaluate(state, planBlocked() or routeTarget ~= nil)
	end
	local function thumbnail(parent: Instance, catalogId: string): ()
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Preview"
		viewport.Position = UDim2.fromOffset(6, 8)
		viewport.Size = UDim2.fromOffset(72, 80)
		viewport.BackgroundTransparency = 1
		viewport.Ambient = Color3.fromRGB(190, 190, 190)
		viewport.LightColor = Color3.new(1, 1, 1)
		viewport.Parent = parent
		local model = Models.create(catalogId)
		if model then
			model.Parent = viewport
			local camera = Instance.new("Camera")
			local bounds, size = model:GetBoundingBox()
			camera.FieldOfView = 35
			local distance = size.Magnitude * 0.55 / math.sin(math.rad(camera.FieldOfView / 2))
			camera.CFrame = CFrame.lookAt(
				bounds.Position + Vector3.new(1, 0.7, 1).Unit * distance,
				bounds.Position
			)
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end
	end
	local function row(
		parent: ScrollingFrame,
		name: string,
		index: number,
		catalogId: string,
		height: number
	): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.new(1, -8, 0, height)
		f.Position = UDim2.fromOffset(4, (index - 1) * (height + 8))
		f.BackgroundColor3 = Color3.fromRGB(41, 62, 60)
		f.BorderSizePixel = 0
		f.Parent = parent
		round(f)
		thumbnail(f, catalogId)
		return f
	end
	local function buy(product: Types.Product): ()
		if storing then
			return
		end
		local s = state
		if s == nil or not s.available or not s.nearShop then
			lastError = "GoShop"
			errorUntil = os.clock() + 4
			return
		end
		local nextPurchase, shouldSend = PurchaseFlow.request(
			purchase,
			product.id,
			if purchase then purchase.requestId else Http:GenerateGUID(false),
			os.clock()
		)
		if not shouldSend then
			return
		end
		purchase = nextPurchase
		listKey = ""
		local packet: { [string]: unknown } =
			{ catalogId = product.id, requestId = nextPurchase.requestId }
		send("buy", packet)
	end
	local function storeItem(owned: Types.Owned): ()
		local s = state
		if s == nil or not s.available or not s.nearHome or purchase ~= nil then
			return
		end
		if storing == nil and owned.placed == nil then
			return
		end
		local nextStore, shouldSend = StoreFlow.request(
			storing,
			owned.id,
			s.editorId,
			s.revision,
			if storing then storing.requestId else "store:" .. Http:GenerateGUID(false),
			os.clock()
		)
		if not shouldSend then
			return
		end
		storing = nextStore
		listKey = ""
		focus = { tab = "Furniture", id = owned.id }
		local packet: { [string]: unknown } = {
			requestId = nextStore.requestId,
			itemId = nextStore.itemId,
			revision = nextStore.revision,
		}
		send("store", packet)
	end

	local function render(): ()
		local s = state
		local selected = routeTarget
		screen:SetAttribute(
			"TravelState",
			if selected
				then selected .. ":" .. tostring(s ~= nil and s.available) .. ":" .. tostring(
					s ~= nil and (if selected == "Home" then s.nearHome else s.nearShop)
				)
				else ""
		)
		local cue = homeObjective()
		screen:SetAttribute("HomeObjectiveState", if cue then cue.key else "")
		planner.render(s, planBlocked())
		if storing or (focus and focus.tab == "Furniture") then
			inventoryFilter = "All"
		end
		local inventoryView = Inventory.project(if s then s.items else {}, inventoryFilter)
		local ready = s ~= nil and s.available and player:GetAttribute("ProfileStatus") == "Ready"
		for _, entry in sections do
			local section: Inventory.Filter = entry.id
			local b = filterButtons[section]
			b.Text = (if section == inventoryFilter then "✓ " else "")
				.. string.format(
					t("inventory" .. section),
					if ready
						then tostring(Inventory.count(inventoryView.counts, section))
						else "—"
				)
			b.Active, b.AutoButtonColor = ready and not planBlocked(), ready and not planBlocked()
			b.BackgroundTransparency = if b.Active then 0 else 0.6
		end
		shopTitle.Text = t("shopTitle") .. (if s then " · $" .. s.dollars else "")
		inventoryTitle.Text = t("inventoryTitle")
		shopBack.Text = t(if purchasedItem then "openInventory" else "backHome")
		inventoryBack.Text = t("backHome")
		returnButton.Text = t("returnHome")
		routeButton.Text = t(if routeTarget == "Shop" then "stopShopRoute" else "showShopRoute")
		local routeReady = routeTarget == "Shop"
			or (s ~= nil and s.available and player:GetAttribute("ProfileStatus") == "Ready")
		routeButton.Active, routeButton.AutoButtonColor = routeReady, routeReady
		routeButton.BackgroundTransparency = if routeReady then 0 else 0.5
		homeRouteButton.Text = t(
			if routeTarget == "Home"
				then "stopHomeRoute"
				elseif s and s.nearHome then "alreadyHome"
				else "walkHome"
		)
		local homeRouteReady = s ~= nil
			and s.available
			and not planBlocked()
			and (routeTarget == "Home" or not s.nearHome)
		homeRouteButton.Active, homeRouteButton.AutoButtonColor = homeRouteReady, homeRouteReady
		homeRouteButton.BackgroundTransparency = if homeRouteReady then 0 else 0.5
		local errorText = if lastError and os.clock() < errorUntil
			then t("homeError" .. lastError)
			else nil
		local storeText = if storing
			then t(
				if StoreFlow.canRetry(storing, os.clock()) then "storeUncertain" else "storePending"
			)
			else nil
		shopInfo.Text = if storeText
			then storeText
			elseif purchase then t(
				if PurchaseFlow.canRetry(purchase, os.clock())
					then "purchaseUncertain"
					else "purchasePending"
			)
			else errorText or t(if s and s.nearShop then "shopReady" else "shopTravel")
		inventoryInfo.Text = storeText
			or errorText
			or t(
				if not ready
					then "offerWaiting"
					elseif s and s.nearHome then "inventoryHint"
					else "inventoryGoHome"
			)
		builder.render()
		if s == nil then
			return
		end
		local key = language()
			.. inventoryFilter
			.. tostring(ready)
			.. tostring(s.available)
			.. tostring(s.nearHome)
			.. tostring(s.nearShop)
			.. s.dollars
			.. s.revision
			.. (
				if purchase
					then purchase.requestId .. tostring(PurchaseFlow.canRetry(purchase, os.clock()))
					else ""
			)
		if storing then
			key ..= storing.requestId .. tostring(StoreFlow.canRetry(storing, os.clock()))
		end
		for _, owned in s.items do
			key ..= owned.id .. (if owned.placed then "placed" else "stored")
		end
		if key == listKey then
			return
		end
		listKey = key
		shopBody:ClearAllChildren()
		inventoryBody:ClearAllChildren()
		for index, product in s.catalog do
			local card = row(shopBody, product.id, index, product.id, 156)
			local title = text(card, "Name", 4, 46, 15)
			title.Position = UDim2.fromOffset(84, 4)
			title.Size = UDim2.new(1, -92, 0, 32)
			title.Text = t(product.id)
			local description = text(card, "Description", 38, 42, 12)
			description.Position, description.Size =
				UDim2.fromOffset(84, 38), UDim2.new(1, -92, 0, 42)
			description.Text = t(product.id .. "Description")
			local dimensions = text(card, "Dimensions", 80, 24, 12)
			dimensions.Position, dimensions.Size =
				UDim2.fromOffset(84, 80), UDim2.new(1, -92, 0, 24)
			dimensions.Text = string.format(t("productSize"), product.width, product.depth)
			local price = text(card, "Price", 108, 36, 16)
			price.Position = UDim2.fromOffset(12, 108)
			price.Size = UDim2.fromOffset(72, 36)
			price.Text = "$" .. product.dollars
			local b = button(card, "Buy")
			b.Position = UDim2.new(1, -132, 0, 104)
			b.Size = UDim2.fromOffset(124, 44)
			b.Text = t(
				if purchase and purchase.catalogId == product.id
					then (if PurchaseFlow.canRetry(purchase, os.clock())
						then "retryPurchase"
						else "purchaseBusy")
					else "buyItem"
			)
			b.Active = storing == nil
				and s.available
				and s.nearShop
				and (
					if purchase
						then purchase.catalogId == product.id and PurchaseFlow.canRetry(
							purchase,
							os.clock()
						)
						else s.dollars >= product.dollars
				)
			b.AutoButtonColor = b.Active
			b.BackgroundTransparency = if b.Active then 0 else 0.6
			b.Activated:Connect(function()
				if b.Active then
					buy(product)
					render()
				end
			end)
		end
		shopBody.CanvasSize = UDim2.fromOffset(0, #s.catalog * 164)
		for index, owned in inventoryView.items do
			local card = row(inventoryBody, owned.id, index, owned.catalogId, 100)
			local title = text(card, "Name", 4, 40, 15)
			title.Position = UDim2.fromOffset(84, 4)
			title.Size = UDim2.new(1, -92, 0, 40)
			title.Text = t(owned.catalogId)
				.. " · "
				.. t(if owned.placed then "itemPlaced" else "itemStored")
			local b = button(card, "Place")
			b.Position = UDim2.new(0.3, 0, 0, 48)
			b.Size = UDim2.new(0.35, -6, 0, 44)
			b.Text = t(if owned.placed then "moveItem" else "placeItem")
			b.Active = s.available and s.nearHome and storing == nil and purchase == nil
			b.AutoButtonColor = b.Active
			b.BackgroundTransparency = if b.Active then 0 else 0.6
			b.Activated:Connect(function()
				local current = state
				if
					inventory.Visible
					and not builder.isActive()
					and current
					and current.available
					and current.nearHome
					and storing == nil
					and purchase == nil
				then
					hidePanels()
					builder.enter(owned, current)
				end
			end)
			local store = button(card, "Store")
			store.Position = UDim2.new(0.65, 0, 0, 48)
			store.Size = UDim2.new(0.35, -8, 0, 44)
			local storeIntent = storing
			local pendingItem = storeIntent ~= nil and storeIntent.itemId == owned.id
			local retryStore = storeIntent ~= nil and StoreFlow.canRetry(storeIntent, os.clock())
			store.Text = t(
				if pendingItem
					then (if retryStore then "retryStore" else "storeBusy")
					else "storeItem"
			)
			store.Visible = owned.placed ~= nil or pendingItem
			store.Active = s.available
				and s.nearHome
				and purchase == nil
				and (storeIntent == nil or (pendingItem and retryStore))
			store.AutoButtonColor = store.Active
			store.BackgroundTransparency = if store.Active then 0 else 0.6
			store.Activated:Connect(function()
				storeItem(owned)
				render()
			end)
		end
		if #inventoryView.items == 0 then
			local empty = text(inventoryBody, "Empty", 8, 70, 17)
			empty.Text = t(
				if not ready
					then "offerWaiting"
					elseif inventoryFilter == "All" then "emptyInventory"
					else "emptyInventory" .. inventoryFilter
			)
		end
		inventoryBody.CanvasSize = UDim2.fromOffset(0, math.max(90, #inventoryView.items * 108))
		local target = focus
		if target then
			local body = if target.tab == "Shop" then shopBody else inventoryBody
			local card = body:FindFirstChild(target.id)
			if card and card:IsA("Frame") then
				body.CanvasPosition = Vector2.new(0, card.Position.Y.Offset)
				focus = nil
			end
		end
		for _, rootPanel in { shop, inventory } do
			for _, gui in rootPanel:GetDescendants() do
				if gui:IsA("GuiObject") then
					gui.ZIndex = 11
				end
			end
		end
	end
	for _, entry in sections do
		local section: Inventory.Filter = entry.id
		local b = filterButtons[section]
		b.Activated:Connect(function()
			local current = state
			if
				not inventory.Visible
				or current == nil
				or not current.available
				or planBlocked()
			then
				return
			end
			if inventoryFilter ~= section then
				inventoryFilter, focus, listKey = section, nil, ""
				inventoryBody.CanvasPosition = Vector2.zero
				render()
			end
		end)
	end
	planner = RoomPlanner.start(screen, language, function(catalogId: string, itemId: string?)
		local current = state
		if current == nil or not current.available or planBlocked() then
			return
		end
		local tab, id = "Shop", catalogId
		for _, owned in current.items do
			if owned.id == itemId and owned.catalogId == catalogId then
				tab, id = "Furniture", owned.id
				break
			end
		end
		focus = { tab = tab, id = id }
		show(tab)
		render()
	end, function()
		local current = state
		if current == nil or not current.available or planBlocked() then
			return
		end
		routeTarget = nil
		hidePanels()
		homePanel.Visible = false
		openJobs()
	end)
	for _, back in { shopBack, inventoryBack } do
		back.Activated:Connect(function()
			if back == shopBack and purchasedItem then
				focus = { tab = "Furniture", id = purchasedItem }
				purchasedItem = nil
				show("Furniture")
				render()
			else
				hidePanels()
				homePanel.Visible = true
			end
		end)
	end
	returnButton.Activated:Connect(function()
		returnHome:FireServer()
		task.delay(0.8, function()
			send("sync", nil)
		end)
	end)
	homeRouteButton.Activated:Connect(function()
		local current = state
		if not homePanel.Visible or current == nil or not current.available or planBlocked() then
			return
		end
		if routeTarget == "Home" then
			routeTarget = nil
		elseif not current.nearHome then
			routeTarget = "Home"
			hidePanels()
			homePanel.Visible = false
		end
		render()
	end)
	routeButton.Activated:Connect(function()
		if routeTarget == "Shop" then
			routeTarget = nil
			render()
		elseif state and state.available and player:GetAttribute("ProfileStatus") == "Ready" then
			routeTarget = "Shop"
			hidePanels()
			homePanel.Visible = false
			render()
		end
	end)
	event.OnClientEvent:Connect(function(s: Types.Snapshot)
		state = s
		local nextStore, storeOutcome = StoreFlow.observe(storing, s)
		storing = nextStore
		if storeOutcome == "Confirmed" then
			lastError, errorUntil = "Stored", os.clock() + 4
		elseif storeOutcome == "Expired" then
			lastError, errorUntil = "Restart", os.clock() + 4
		end
		if s.error then
			lastError = s.error
			errorUntil = os.clock() + 4
		end
		local nextPurchase, outcome, itemId =
			PurchaseFlow.observe(purchase, s.items, s.ack, s.error)
		purchase = nextPurchase
		if outcome == "Confirmed" then
			purchasedItem = itemId
			lastError, errorUntil = "Bought", os.clock() + 4
			routeTarget = nil
		end
		if s.openShop then
			show("Shop")
		end
		builder.update(s)
		render()
	end)
	player:GetAttributeChangedSignal("ProfileStatus"):Connect(function()
		if player:GetAttribute("ProfileStatus") == "Ready" then
			send("sync", nil)
		end
	end)
	local homeSync = RunService.RenderStepped:Connect(function()
		local inBuild = builder.isActive()
		if
			(
				shop.Visible
				or inventory.Visible
				or planner.isVisible()
				or inBuild
				or routeTarget ~= nil
				or (state ~= nil and state.onboarding == "DONE")
			) and os.clock() - syncAt > 1
		then
			syncAt = os.clock()
			send("sync", nil)
			render()
		end
	end)
	screen.Destroying:Once(function()
		homeSync:Disconnect()
	end)
	send("sync", nil)
	return {
		objective = homeObjective,
		travel = function(): Goals.Goal?
			if routeTarget == "Home" then
				return Goals.home(true, state)
			end
			if routeTarget ~= "Shop" then
				return nil
			end
			local shopModel = workspace:FindFirstChild("NeighborhoodShop")
			local counter = if shopModel then shopModel:FindFirstChild("Counter") else nil
			if counter == nil or not counter:IsA("BasePart") then
				return nil
			end
			local position = counter.Position + Vector3.new(0, 1.5, 6)
			return Goals.shop(true, state, { position.X, position.Y, position.Z })
		end,
		stopRoute = function(): ()
			routeTarget = nil
			render()
		end,
		render = render,
		show = function(tab: string): ()
			builder.stop()
			show(tab)
			render()
		end,
		hide = function(): ()
			builder.stop()
			hidePanels()
		end,
	}
end
return Controller
