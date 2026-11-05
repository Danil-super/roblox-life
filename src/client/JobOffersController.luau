--!strict
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Strings = require(RS.Shared.Strings)
local Types = require(RS.Shared.JobTypes)
local Config = require(RS.Shared.PaintConfig)
local Mastery = require(RS.Shared.PaintingMastery)
local Theme = require(RS.Shared.Theme)
local Flow = require(RS.Shared.JobAcceptFlow)
export type API = {
	render: (Types.Snapshot?) -> (),
	show: (string?) -> (),
	back: () -> boolean,
	pending: () -> boolean,
}
local Controller = {}
function Controller.start(
	panel: Frame,
	workBody: ScrollingFrame,
	back: TextButton,
	language: () -> string,
	accept: (string, string, string) -> (),
	ready: () -> boolean
): API
	local function color(values: { number }): Color3
		return Color3.fromRGB(values[1], values[2], values[3])
	end
	local paper, accent = color(Theme.colors.paper), color(Theme.colors.accent)
	local state: Types.Snapshot? = nil
	local selected: string? = nil
	local target: Flow.Target? = nil
	local pendingOffer: Types.Offer? = nil
	local disposed = false
	local listKey = ""
	local root = Instance.new("Frame")
	root.Name, root.Position, root.Size =
		"Offers", UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -122)
	root.BackgroundTransparency, root.Visible, root.ZIndex, root.Parent = 1, false, 9, panel
	local function scroll(name: string): ScrollingFrame
		local f = Instance.new("ScrollingFrame")
		f.Name, f.Size = name, UDim2.fromScale(1, 1)
		f.BackgroundTransparency, f.BorderSizePixel, f.ScrollBarThickness = 1, 0, 4
		f.ZIndex, f.Parent = 9, root
		return f
	end
	local list, details = scroll("List"), scroll("Details")
	details.CanvasSize = UDim2.fromOffset(0, 280)
	local function label(
		parent: Instance,
		name: string,
		y: number,
		height: number,
		size: number
	): TextLabel
		local l = Instance.new("TextLabel")
		l.Name, l.Position, l.Size = name, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, height)
		l.BackgroundTransparency, l.TextWrapped, l.TextSize = 1, true, size
		l.Font, l.TextColor3, l.ZIndex, l.Parent = Enum.Font.GothamMedium, paper, 10, parent
		return l
	end
	local xpLabel = label(list, "Experience", 0, 54, 13)
	local progressTrack = Instance.new("Frame")
	progressTrack.Name, progressTrack.Position, progressTrack.Size =
		"MasteryProgress", UDim2.fromOffset(16, 56), UDim2.new(1, -32, 0, 6)
	progressTrack.BackgroundColor3, progressTrack.BorderSizePixel, progressTrack.ZIndex, progressTrack.Parent =
		color(Theme.colors.surface), 0, 10, list
	local progressFill = Instance.new("Frame")
	progressFill.Name, progressFill.Size = "Fill", UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3, progressFill.BorderSizePixel, progressFill.ZIndex, progressFill.Parent =
		accent, 0, 11, progressTrack
	local title = label(details, "Title", 0, 40, 18)
	local reward = label(details, "Reward", 44, 28, 16)
	local requirements = label(details, "Requirements", 78, 62, 14)
	local brief = label(details, "Brief", 148, 72, 14)
	local locked = label(details, "Availability", 228, 44, 14)
	local confirm = Instance.new("TextButton")
	confirm.Name, confirm.Position, confirm.Size =
		"AcceptOffer", UDim2.new(0.5, 8, 1, -56), UDim2.new(0.5, -24, 0, 44)
	confirm.BackgroundColor3, confirm.TextColor3 = accent, paper
	confirm.TextSize, confirm.TextWrapped, confirm.Font = 14, true, Enum.Font.GothamBold
	confirm.ZIndex, confirm.Visible, confirm.Parent = 10, false, panel
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function materials(o: Types.Offer): string
		local first = t(Config.colorKeys[o.colorId] or "warmWhite")
		return if o.secondaryColorId
			then first .. " + " .. t(Config.colorKeys[o.secondaryColorId] or "warmWhite")
			else first
	end
	local function selectedOffer(): Types.Offer?
		if target and pendingOffer and selected == target.offerId then
			return pendingOffer
		end
		local s = state
		if s and s.offers then
			for _, offer in s.offers do
				if offer.id == selected then
					return offer
				end
			end
		end
		return nil
	end
	local render: () -> ()
	render = function(): ()
		local s = state
		local visible = target ~= nil
			or (s ~= nil and (s.phase == "Offer" or s.phase == "Completed"))
		root.Visible, workBody.Visible = visible, not visible
		if not visible then
			selected = nil
		elseif target then
			selected = target.offerId
		end
		local offer = selectedOffer()
		list.Visible, details.Visible = offer == nil, offer ~= nil
		confirm.Visible = visible and offer ~= nil
		back.Size = if confirm.Visible then UDim2.new(0.5, -24, 0, 44) else UDim2.new(1, -32, 0, 44)
		back.Text = t(if target or not confirm.Visible then "backHome" else "backOffers")
		confirm.Text = t(
			if target
				then (if Flow.canSend(target, s, os.clock(), ready())
					then "acceptRetry"
					else "acceptingJob")
				elseif offer and not offer.unlocked then "offerLocked"
				else "acceptJob"
		)
		confirm.Active = if target
			then Flow.canSend(target, s, os.clock(), ready())
			else Flow.available(s, if offer then offer.id else "", ready())
		confirm.AutoButtonColor, confirm.BackgroundTransparency =
			confirm.Active, if confirm.Active then 0 else 0.6
		local experience = if s then s.paintingXP or 0 else 0
		local mastery = Mastery.evaluate(
			if s then s.paintingXP else nil,
			if s then s.offers else nil,
			s ~= nil and s.available,
			nil
		)
		xpLabel.Text = if mastery.ready
			then string.format(t("paintingExperience"), mastery.xp) .. "\n" .. Mastery.goalText(
				mastery,
				language()
			) .. "\n" .. (if mastery.wide
				then t("wideRollerUnlocked")
				else string.format(t("wideRollerGoal"), Config.wideRollerXP - mastery.xp))
			else t("offerWaiting")
		progressTrack.Visible = mastery.ready
		progressFill.Size = UDim2.fromScale(mastery.fraction, 1)
		if offer then
			title.Text, brief.Text = t(offer.titleKey), t(offer.briefKey)
			if target then
				brief.Text = t("acceptPendingHint")
			end
			reward.Text = string.format(t("contractReward"), offer.reward, offer.xp)
			requirements.Text = string.format(t("contractMaterial"), materials(offer))
				.. "\n"
				.. t(offer.clientKey or "residentNina")
				.. " · "
				.. t("contractAddress")
			locked.Text = if target
				then t("acceptPendingStatus")
				elseif offer.unlocked then t("offerReady")
				else string.format(
					t("offerXPNeeded"),
					math.max(0, offer.requiredXP - experience)
				)
		end
		local key = language() .. tostring(experience) .. tostring(s ~= nil and s.available)
		if s and s.offers then
			for _, o in s.offers do
				key ..= o.id .. o.reward .. o.xp .. tostring(o.unlocked)
			end
		end
		if key == listKey then
			return
		end
		listKey = key
		for _, child in list:GetChildren() do
			if child ~= xpLabel and child ~= progressTrack then
				child:Destroy()
			end
		end
		local offers: { Types.Offer } = if s then s.offers or {} else {}
		for index, o in offers do
			local b = Instance.new("TextButton")
			b.Name, b.Position, b.Size =
				o.id, UDim2.fromOffset(16, 72 + (index - 1) * 112), UDim2.new(1, -32, 0, 104)
			b.Text, b.BackgroundColor3, b.ZIndex, b.Parent =
				"", color(Theme.colors.surface), 9, list
			local name = label(b, "Title", 8, 36, 16)
			name.Text = t(o.titleKey)
			local info = label(b, "Info", 46, 50, 13)
			info.Text = string.format(t("contractReward"), o.reward, o.xp)
				.. " · "
				.. materials(o)
				.. "\n"
				.. (
					if o.unlocked
						then t("offerReady")
						else string.format(
							t("offerXPNeeded"),
							math.max(0, o.requiredXP - experience)
						)
				)
			b.Activated:Connect(function()
				if
					disposed
					or target
					or not panel.Visible
					or not root.Visible
					or not list.Visible
				then
					return
				end
				selected = o.id
				details.CanvasPosition = Vector2.zero
				render()
			end)
		end
		list.CanvasSize = UDim2.fromOffset(0, 72 + #offers * 112)
	end
	confirm.Activated:Connect(function()
		local offer = selectedOffer()
		if
			disposed
			or not panel.Visible
			or not root.Visible
			or not confirm.Visible
			or offer == nil
		then
			return
		end
		local candidate = target
			or Flow.request(state, offer.id, ready(), HttpService:GenerateGUID(false))
		local attempt = Flow.sent(candidate, state, os.clock(), ready())
		if attempt == nil then
			return
		end
		target, pendingOffer = attempt, offer
		render()
		accept(attempt.offerId, attempt.jobId, attempt.requestId)
		task.delay(8, function()
			if target == attempt and not disposed and panel.Parent ~= nil then
				render()
			end
		end)
	end)
	panel.Destroying:Once(function()
		disposed = true
		target, pendingOffer, state = nil, nil, nil
	end)
	return {
		render = function(s: Types.Snapshot?): ()
			if disposed then
				return
			end
			state = s
			target = Flow.observe(target, s)
			if target == nil then
				pendingOffer = nil
			end
			render()
		end,
		show = function(id: string?): ()
			if disposed then
				return
			end
			if target then
				selected = target.offerId
				render()
				return
			end
			selected = nil
			local s = state
			if
				id
				and s
				and s.available
				and s.offers
				and (s.phase == "Offer" or s.phase == "Completed")
			then
				for _, o in s.offers do
					if o.id == id and o.unlocked then
						selected = id
						break
					end
				end
			end
			details.CanvasPosition = Vector2.zero
			list.CanvasPosition = Vector2.zero
			render()
		end,
		back = function(): boolean
			if disposed or target then
				return false
			end
			if selected then
				selected = nil
				render()
				return true
			end
			return false
		end,
		pending = function(): boolean
			return target ~= nil
		end,
	}
end
return Controller
