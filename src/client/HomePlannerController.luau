--!strict
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Types = require(RS.Shared.HomeTypes)
local Theme = require(RS.Shared.Theme)
export type API = {
	render: (Types.Snapshot?) -> (),
	show: () -> (),
	hide: () -> (),
	isVisible: () -> boolean,
}
local Planner = {}
function Planner.start(
	screen: ScreenGui,
	language: () -> string,
	navigate: (string, string?) -> ()
): API
	local state: Types.Snapshot? = nil
	local key = ""
	local function color(rgb: { number }): Color3
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position =
		"RoomPlanPanel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundColor3 = UDim2.new(1, -24, 1, -24), color(Theme.colors.ink)
	panel.ZIndex, panel.Visible, panel.Parent = 10, false, screen
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize, constraint.Parent = Vector2.new(600, 488), panel
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
			Enum.Font.GothamMedium, color(Theme.colors.paper), 11, parent
		return l
	end
	local function button(parent: Instance, name: string, y: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size = name, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 48)
		b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamMedium, 14, true
		b.BackgroundColor3, b.TextColor3 = color(Theme.colors.accent), color(Theme.colors.paper)
		b.ZIndex, b.Parent = 11, parent
		return b
	end
	local title = label(panel, "Title", 8, 36, 22)
	local summary = label(panel, "Summary", 48, 54, 14)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size =
		"Body", UDim2.fromOffset(8, 110), UDim2.new(1, -16, 1, -182)
	body.BackgroundTransparency, body.BorderSizePixel, body.ScrollBarThickness = 1, 0, 4
	body.ZIndex, body.Parent = 11, panel
	local back = button(panel, "Back", 0)
	back.Position = UDim2.new(0, 16, 1, -60)
	back.Activated:Connect(function()
		panel.Visible = false
		local home = screen:FindFirstChild("HomePanel")
		if home and home:IsA("Frame") then
			home.Visible = true
		end
	end)
	local function t(name: string): string
		return Strings.text(language(), name)
	end
	local function render(s: Types.Snapshot?): ()
		state = s
		title.Text, back.Text = t("roomPlan"), t("backHome")
		local plan = if s and s.available then s.plan else nil
		summary.Text = if plan
			then string.format(t("roomPlanProgress"), plan.placed, plan.total) .. "\n" .. t(
				"roomPlanOptional"
			)
			else t("offerWaiting")
		local nextKey = language() .. tostring(s ~= nil and s.available)
		if plan then
			for _, goal in plan.goals do
				for _, r in goal.requirements do
					nextKey ..= r.catalogId .. (r.itemId or "") .. tostring(r.placed)
				end
			end
		end
		if nextKey == key then
			return
		end
		key = nextKey
		body:ClearAllChildren()
		local y = 0
		if plan then
			for _, goal in plan.goals do
				local card = Instance.new("Frame")
				card.Name, card.Position, card.Size =
					goal.id,
					UDim2.fromOffset(4, y),
					UDim2.new(1, -8, 0, 56 + #goal.requirements * 56)
				card.BackgroundColor3, card.BorderSizePixel, card.ZIndex, card.Parent =
					color(Theme.colors.surface), 0, 11, body
				local heading = label(card, "Heading", 4, 44, 16)
				heading.Text = t(goal.id)
					.. (if goal.complete then " · " .. t("roomGoalComplete") else "")
				for index, requirement in goal.requirements do
					local b = button(card, requirement.catalogId, 52 + (index - 1) * 56)
					b.Text = t(requirement.catalogId)
						.. " · "
						.. t(
							if requirement.placed
								then "itemPlaced"
								elseif requirement.itemId then "placeItem"
								else "buyItem"
						)
					b.Activated:Connect(function()
						local current = state
						if current and current.available then
							navigate(requirement.catalogId, requirement.itemId)
						end
					end)
				end
				y += card.Size.Y.Offset + 8
			end
		end
		body.CanvasSize = UDim2.fromOffset(0, y)
	end
	return {
		render = render,
		show = function(): ()
			panel.Visible = true
		end,
		hide = function(): ()
			panel.Visible = false
		end,
		isVisible = function(): boolean
			return panel.Visible
		end,
	}
end
return Planner
