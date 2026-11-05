--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Flow = require(RS.Shared.JobAbandonFlow)
local Types = require(RS.Shared.JobTypes)
local Strings = require(RS.Shared.Strings)
local Theme = require(RS.Shared.Theme)
export type API = {
	ask: (Types.Snapshot?) -> (),
	resume: () -> (),
	hide: () -> (),
	render: (Types.Snapshot?) -> (),
	pending: () -> boolean,
	isVisible: () -> boolean,
}
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	language: () -> string,
	sendCancel: (string, string) -> (),
	closed: (boolean) -> ()
): API
	local player = Players.LocalPlayer
	local target: Flow.Target? = nil
	local state: Types.Snapshot? = nil
	local contractKey = "jobs"
	local disposed = false
	local function color(rgb: { number }): Color3
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position =
		"AbandonPanel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundColor3 = UDim2.new(1, -24, 1, -24), color(Theme.colors.ink)
	panel.ZIndex, panel.Visible, panel.Parent = 16, false, screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(480, 344), panel
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
		l.Font, l.TextColor3, l.ZIndex, l.Parent =
			Enum.Font.GothamMedium, color(Theme.colors.paper), 17, parent
		return l
	end
	local title = label(panel, "Title", 8, 40, 20)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -122)
	body.BackgroundTransparency, body.BorderSizePixel, body.ScrollBarThickness = 1, 0, 4
	body.CanvasSize, body.ZIndex, body.Parent = UDim2.fromOffset(0, 166), 17, panel
	local order = label(body, "Order", 0, 44, 16)
	local message = label(body, "Message", 48, 112, 14)
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size =
			name, UDim2.new(x, if x == 0 then 16 else 8, 1, -56), UDim2.new(0.5, -24, 0, 44)
		b.BackgroundColor3, b.TextColor3 = color(Theme.colors.accent), color(Theme.colors.paper)
		b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamMedium, 14, true
		b.ZIndex, b.Parent = 17, panel
		return b
	end
	local keep, confirm = button("Keep", 0), button("Confirm", 0.5)
	local function pending(): boolean
		return target ~= nil and target.sentAt ~= nil
	end
	local function ready(): boolean
		return player:GetAttribute("ProfileStatus") == "Ready"
	end
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function refresh(): ()
		local sent = pending()
		local canSend = Flow.canSend(target, state, os.clock(), ready())
		title.Text = t(if sent then "abandonPendingTitle" else "abandonTitle")
		order.Text = t(contractKey)
		message.Text = t(if sent then "abandonPendingHint" else "abandonWarning")
		keep.Text = t(if sent then "abandonClose" else "abandonKeep")
		confirm.Text =
			t(if sent then (if canSend then "abandonRetry" else "saving") else "abandonConfirm")
		confirm.Active, confirm.AutoButtonColor = canSend, canSend
		confirm.BackgroundTransparency = if canSend then 0 else 0.6
	end
	local function hide(): ()
		panel.Visible = false
		if not pending() then
			target = nil
		end
	end
	keep.Activated:Connect(function()
		if disposed or not panel.Visible then
			return
		end
		local waiting = pending()
		hide()
		closed(waiting)
	end)
	confirm.Activated:Connect(function()
		if disposed or not panel.Visible then
			return
		end
		local attempt = Flow.sent(target, state, os.clock(), ready())
		if attempt == nil then
			return
		end
		target = attempt
		refresh()
		sendCancel(attempt.jobId, attempt.workId)
	end)
	screen.Destroying:Once(function()
		disposed = true
		target, state = nil, nil
	end)
	return {
		ask = function(s: Types.Snapshot?): ()
			if disposed then
				return
			end
			state = s
			if not pending() then
				target = Flow.request(s, ready())
				contractKey = "jobs"
				if s and s.offers then
					for _, offer in s.offers do
						if offer.id == s.contractId then
							contractKey = offer.titleKey
							break
						end
					end
				end
			end
			panel.Visible = target ~= nil
			body.CanvasPosition = Vector2.zero
			refresh()
		end,
		resume = function(): ()
			if not disposed and target then
				panel.Visible = true
				refresh()
			end
		end,
		hide = hide,
		render = function(s: Types.Snapshot?): ()
			if disposed then
				return
			end
			state = s
			local old, visible = target, panel.Visible
			target = Flow.observe(target, s)
			if old and target == nil then
				panel.Visible = false
				if visible and ready() then
					closed(false)
				end
			end
			refresh()
		end,
		pending = pending,
		isVisible = function(): boolean
			return panel.Visible
		end,
	}
end
return Controller
