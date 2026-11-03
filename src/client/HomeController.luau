--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Strings = require(RS.Shared.Strings)
local Models = require(RS.Assets.FurnitureModels)
local Types = require(RS.Shared.HomeTypes)
local PurchaseFlow = require(RS.Shared.PurchaseFlow)
local Build = require("./BuildController")
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	homePanel: Frame,
	language: () -> string,
	exclusive: () -> ()
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
	local purchasedItem: string? = nil
	local routeActive = false
	local syncAt = 0
	local listKey = ""
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
	local returnButton = button(inventory, "ReturnHome")
	returnButton.Position = UDim2.new(1, -150, 0, 54)
	returnButton.Size = UDim2.fromOffset(134, 44)
	inventoryInfo.Size = UDim2.new(1, -182, 0, 54)
	local routeButton = button(shop, "Route")
	routeButton.Position = UDim2.new(1, -150, 0, 54)
	routeButton.Size = UDim2.fromOffset(134, 44)
	shopInfo.Size = UDim2.new(1, -182, 0, 54)
	local route = button(screen, "ShopRoute")
	route.Position = UDim2.fromOffset(16, 172)
	route.Size = UDim2.fromOffset(242, 52)
	route.BackgroundColor3 = Color3.fromRGB(26, 43, 43)
	route.Visible = false
	local marker = Instance.new("BillboardGui")
	marker.Name = "ShopMarker"
	marker.Size = UDim2.fromOffset(190, 52)
	marker.AlwaysOnTop = true
	marker.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	marker.Enabled = false
	marker.Parent = screen
	local badge = text(marker, "Label", 0, 52, 16)
	badge.Position = UDim2.fromOffset(0, 0)
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Color3.fromRGB(245, 197, 98)
	badge.TextColor3 = Color3.fromRGB(26, 43, 43)
	round(badge)
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
	end
	local function show(tab: string): ()
		exclusive()
		homePanel.Visible = false
		hidePanels()
		shop.Visible = tab == "Shop"
		inventory.Visible = tab == "Furniture"
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
			camera.CFrame = CFrame.lookAt(Vector3.new(5, 5, 7), Vector3.new(0, 2, 0))
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end
	end
	local function row(
		parent: ScrollingFrame,
		name: string,
		index: number,
		catalogId: string
	): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.new(1, -8, 0, 100)
		f.Position = UDim2.fromOffset(4, (index - 1) * 108)
		f.BackgroundColor3 = Color3.fromRGB(41, 62, 60)
		f.BorderSizePixel = 0
		f.Parent = parent
		round(f)
		thumbnail(f, catalogId)
		return f
	end
	local function buy(product: Types.Product): ()
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
	local function render(): ()
		local s = state
		shopTitle.Text = t("shopTitle") .. (if s then " · $" .. s.dollars else "")
		inventoryTitle.Text = t("inventoryTitle")
		shopBack.Text = t(if purchasedItem then "openInventory" else "backHome")
		inventoryBack.Text = t("backHome")
		returnButton.Text = t("returnHome")
		routeButton.Text = t("showShopRoute")
		badge.Text = t("shopTitle")
		local errorText = if lastError and os.clock() < errorUntil
			then t("homeError" .. lastError)
			else nil
		shopInfo.Text = if purchase
			then t(
				if PurchaseFlow.canRetry(purchase, os.clock())
					then "purchaseUncertain"
					else "purchasePending"
			)
			else errorText or t(if s and s.nearShop then "shopReady" else "shopTravel")
		inventoryInfo.Text = errorText
			or t(if s and s.nearHome then "inventoryHint" else "inventoryGoHome")
		builder.render()
		if s == nil then
			return
		end
		local key = language()
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
			local card = row(shopBody, product.id, index, product.id)
			local title = text(card, "Name", 4, 46, 15)
			title.Position = UDim2.fromOffset(84, 4)
			title.Size = UDim2.new(1, -92, 0, 42)
			title.Text = t(product.id)
			local price = text(card, "Price", 48, 40, 16)
			price.Position = UDim2.fromOffset(84, 48)
			price.Size = UDim2.fromOffset(52, 40)
			price.Text = "$" .. product.dollars
			local b = button(card, "Buy")
			b.Position = UDim2.new(1, -132, 0, 48)
			b.Size = UDim2.fromOffset(124, 44)
			b.Text = t(
				if purchase and purchase.catalogId == product.id
					then (if PurchaseFlow.canRetry(purchase, os.clock())
						then "retryPurchase"
						else "purchaseBusy")
					else "buyItem"
			)
			b.Active = s.available
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
		shopBody.CanvasSize = UDim2.fromOffset(0, #s.catalog * 108)
		for index, owned in s.items do
			local card = row(inventoryBody, owned.id, index, owned.catalogId)
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
			b.Active = s.available and s.nearHome
			b.AutoButtonColor = b.Active
			b.BackgroundTransparency = if b.Active then 0 else 0.6
			b.Activated:Connect(function()
				local current = state
				if current and current.available and current.nearHome then
					hidePanels()
					builder.enter(owned, current)
				end
			end)
			local store = button(card, "Store")
			store.Position = UDim2.new(0.65, 0, 0, 48)
			store.Size = UDim2.new(0.35, -8, 0, 44)
			store.Text = t("storeItem")
			store.Visible = owned.placed ~= nil
			store.Active = s.available and s.nearHome
			store.BackgroundTransparency = if store.Active then 0 else 0.6
			store.Activated:Connect(function()
				local current = state
				if current and current.nearHome and current.available then
					local packet: { [string]: unknown } =
						{ itemId = owned.id, revision = current.revision }
					send("store", packet)
				end
			end)
		end
		if #s.items == 0 then
			local empty = text(inventoryBody, "Empty", 8, 70, 17)
			empty.Text = t("emptyInventory")
		end
		inventoryBody.CanvasSize = UDim2.fromOffset(0, math.max(90, #s.items * 108))
		for _, rootPanel in { shop, inventory } do
			for _, gui in rootPanel:GetDescendants() do
				if gui:IsA("GuiObject") then
					gui.ZIndex = 11
				end
			end
		end
	end
	for _, back in { shopBack, inventoryBack } do
		back.Activated:Connect(function()
			if back == shopBack and purchasedItem then
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
	routeButton.Activated:Connect(function()
		routeActive = true
		hidePanels()
		homePanel.Visible = false
	end)
	route.Activated:Connect(function()
		show("Shop")
		render()
	end)
	event.OnClientEvent:Connect(function(s: Types.Snapshot)
		state = s
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
			routeActive = false
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
	RunService.RenderStepped:Connect(function()
		local inBuild = builder.isActive()
		route.Visible = routeActive and not inBuild
		marker.Enabled = route.Visible
		local shopModel = workspace:FindFirstChild("NeighborhoodShop")
		local counter = if shopModel then shopModel:FindFirstChild("Counter") else nil
		if counter and counter:IsA("BasePart") then
			marker.Adornee = counter
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				route.Text = t("shopTitle")
					.. " · "
					.. math.floor((root.Position - counter.Position).Magnitude)
					.. " · "
					.. t("openShop")
			end
		end
		if
			(shop.Visible or inventory.Visible or inBuild or routeActive)
			and os.clock() - syncAt > 1
		then
			syncAt = os.clock()
			send("sync", nil)
			render()
		end
	end)
	send("sync", nil)
	return {
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
