--!strict
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Types = require(RS.Shared.HomeTypes)
local Theme = require(RS.Shared.Theme)
local Budget = require(RS.Shared.HomeBudget)
local Plan = require(RS.Shared.HomePlan)
export type API = {
	render: (Types.Snapshot?, boolean) -> (),
	show: () -> (),
	hide: () -> (),
	isVisible: () -> boolean,
}
local Planner = {}
local function goals(s: Types.Snapshot): { Plan.Goal }
	return if s.plan then Plan.displayGoals(s.plan, s.items) else {}
end
function Planner.start(
	screen: ScreenGui,
	language: () -> string,
	navigate: (string, string?) -> (),
	earn: () -> ()
): API
	local state: Types.Snapshot? = nil
	local stateBlocked = true
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
	local work = button(panel, "Jobs", 0)
	work.Position, work.Size = UDim2.new(0.5, 8, 1, -60), UDim2.new(0.5, -24, 0, 48)
	work.Visible = false
	work.Activated:Connect(function()
		local current = state
		if
			not panel.Visible
			or stateBlocked
			or current == nil
			or not current.available
			or not Plan.isComplete(current.plan)
		then
			return
		end
		earn()
	end)
	local function t(name: string): string
		return Strings.text(language(), name)
	end
	local function render(s: Types.Snapshot?, blocked: boolean): ()
		state, stateBlocked = s, blocked
		title.Text, back.Text = t("roomPlan"), t("backHome")
		local plan = if s and s.available then s.plan else nil
		local complete = Plan.isComplete(plan)
		work.Text, work.Visible, work.Active = t("openJobs"), complete, complete and not blocked
		work.AutoButtonColor, work.BackgroundTransparency =
			work.Active, if work.Active then 0 else 0.6
		back.Size = if complete then UDim2.new(0.5, -24, 0, 48) else UDim2.new(1, -32, 0, 48)
		summary.Text = if plan
			then string.format(t("roomPlanProgress"), plan.placed, plan.total) .. "\n" .. t(
				if complete then "roomPlanFinished" else "roomPlanOptional"
			)
			else t("offerWaiting")
		local nextKey = language() .. tostring(s ~= nil and s.available) .. tostring(blocked)
		if s then
			nextKey ..= s.dollars
			for _, product in s.catalog do
				nextKey ..= product.id .. product.dollars
			end
		end
		if plan and s then
			for _, goal in goals(s) do
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
		if plan and s then
			for _, goal in goals(s) do
				local budget = Budget.evaluate(goal, s.catalog, s.dollars, not blocked)
				local needsWork = budget.ready and budget.action == "Earn"
				local startY = if needsWork then 160 else 104
				local card = Instance.new("Frame")
				card.Name, card.Position, card.Size =
					goal.id,
					UDim2.fromOffset(4, y),
					UDim2.new(1, -8, 0, startY + 4 + #goal.requirements * 56)
				card.BackgroundColor3, card.BorderSizePixel, card.ZIndex, card.Parent =
					color(Theme.colors.surface), 0, 11, body
				local heading = label(card, "Heading", 4, 44, 16)
				heading.Text = t(goal.id)
					.. (if goal.complete then " · " .. t("roomGoalComplete") else "")
				local cost = label(card, "Budget", 48, 48, 13)
				cost.Text = Budget.text(budget, language())
				if needsWork then
					local findWork = button(card, "Earn", 104)
					findWork.Text = t("roomBudgetEarn")
					findWork.Activated:Connect(function()
						local current = state
						if
							not panel.Visible
							or stateBlocked
							or current == nil
							or not current.available
							or current.plan == nil
						then
							return
						end
						for _, currentGoal in goals(current) do
							if
								currentGoal.id == goal.id
								and Budget.evaluate(
										currentGoal,
										current.catalog,
										current.dollars,
										true
									).action
									== "Earn"
							then
								earn()
								return
							end
						end
					end)
				end
				for index, requirement in goal.requirements do
					local b = button(card, requirement.catalogId, startY + (index - 1) * 56)
					b.Active, b.AutoButtonColor = not blocked, not blocked
					b.BackgroundTransparency = if blocked then 0.6 else 0
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
						if panel.Visible and not stateBlocked and current and current.available then
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
