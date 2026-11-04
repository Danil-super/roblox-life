--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Types = require(RS.Shared.JobTypes)
local FirstSteps = require(RS.Shared.FirstSteps)
local InputConfig = require(RS.Shared.InputConfig)
export type API = {
	render: (Types.Snapshot?) -> (),
	show: () -> (),
	hide: () -> (),
	step: (boolean) -> (),
}
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	language: () -> string,
	open: () -> (),
	navigate: (string) -> ()
): API
	local player = Players.LocalPlayer
	local state: Types.Snapshot? = nil
	local selected: string? = nil
	local lastStatus: string? = nil
	local pending, announced = false, false
	local listKey = ""
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position =
		"GuidePanel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundColor3, panel.ZIndex =
		UDim2.new(1, -24, 1, -24), Color3.fromRGB(26, 43, 43), 12
	panel.Visible, panel.Parent = false, screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(560, 488), panel
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
			Enum.Font.GothamMedium, Color3.fromRGB(244, 239, 224), 13, parent
		return l
	end
	local function button(parent: Instance, name: string, y: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size = name, UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 48)
		b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamMedium, 14, true
		b.BackgroundColor3, b.TextColor3, b.ZIndex, b.Parent =
			Color3.fromRGB(55, 120, 102), Color3.fromRGB(244, 239, 224), 13, parent
		return b
	end
	local heading = label(panel, "Heading", 8, 36, 22)
	heading.Size = UDim2.new(1, -88, 0, 36)
	local close = button(panel, "Close", 8)
	close.Position, close.Size, close.Text = UDim2.new(1, -60, 0, 8), UDim2.fromOffset(44, 44), "×"
	local summary = label(panel, "Summary", 52, 50, 14)
	local function scroll(name: string): ScrollingFrame
		local f = Instance.new("ScrollingFrame")
		f.Name, f.Position, f.Size = name, UDim2.fromOffset(0, 110), UDim2.new(1, 0, 1, -182)
		f.BackgroundTransparency, f.BorderSizePixel, f.ScrollBarThickness = 1, 0, 4
		f.ZIndex, f.Parent = 13, panel
		return f
	end
	local list, details = scroll("List"), scroll("Details")
	details.CanvasSize = UDim2.fromOffset(0, 240)
	local detailTitle = label(details, "Title", 0, 44, 18)
	local detailStatus = label(details, "Status", 48, 44, 14)
	local description = label(details, "Description", 100, 136, 15)
	local back, primary = button(panel, "Back", 0), button(panel, "Action", 0)
	back.Position, back.Size = UDim2.new(0, 16, 1, -60), UDim2.new(0.5, -24, 0, 48)
	primary.Position, primary.Size = UDim2.new(0.5, 8, 1, -60), UDim2.new(0.5, -24, 0, 48)
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function progress(): FirstSteps.Progress?
		local s = state
		return if s
				and s.available
				and player:GetAttribute("ProfileStatus") == "Ready"
			then s.firstSteps
			else nil
	end
	local function observe(status: string): ()
		if status == "Waiting" then
			return
		end
		if lastStatus == "Active" and status == "Done" and not announced then
			pending = true
		end
		lastStatus = status
	end
	local function hide(): ()
		panel.Visible = false
		selected = nil
	end
	local function dismiss(): ()
		local p = progress()
		if p and p.status == "Done" then
			pending = false
			announced = true
		end
		hide()
	end
	local function selectedStep(p: FirstSteps.Progress?): FirstSteps.Step?
		if p then
			for _, s in p.steps do
				if s.id == (selected or p.current) then
					return s
				end
			end
		end
		return nil
	end
	local render: (Types.Snapshot?) -> ()
	render = function(s: Types.Snapshot?): ()
		state = s
		local p = progress()
		if p then
			observe(p.status)
		end
		heading.Text = t("firstSteps")
		summary.Text = if p == nil or p.status == "Waiting"
			then t("guideWaiting")
			elseif p.status == "Done" then t("guideFinished") .. "\n" .. t("guideFreedom")
			else string.format(t("guideCount"), p.completed, p.total)
		local chosen = selectedStep(p)
		details.Visible, list.Visible =
			selected ~= nil and chosen ~= nil, selected == nil or chosen == nil
		back.Text = t(if details.Visible then "guideAllSteps" else "backHome")
		primary.Text = t(
			if chosen
				then chosen.actionKey
				elseif p and p.status == "Done" then "roomPlan"
				else "guideWaitAction"
		)
		primary.Active = p ~= nil and p.status ~= "Waiting"
		primary.AutoButtonColor, primary.BackgroundTransparency =
			primary.Active, if primary.Active then 0 else 0.6
		if chosen then
			detailTitle.Text = t(chosen.titleKey)
			detailStatus.Text = t(
				if chosen.done
					then "guideDoneReview"
					elseif p and chosen.id == p.current then "guideNow"
					else "guideLater"
			)
			description.Text = if chosen.id == "job"
				then string.format(t(chosen.detailKey), InputConfig.phoneKey)
				else t(chosen.detailKey)
		end
		local key = language() .. (if p then p.status else "Waiting")
		if p then
			for _, s2 in p.steps do
				key ..= s2.id .. tostring(s2.done)
			end
		end
		if key == listKey then
			return
		end
		listKey = key
		list:ClearAllChildren()
		local y = 0
		if p and p.status == "Done" then
			local jobs = button(list, "NewJob", 0)
			jobs.Text = t("openJobs")
			jobs.Activated:Connect(function()
				dismiss()
				navigate("Jobs")
			end)
			y = 56
		end
		if p then
			for _, item in p.steps do
				local b = button(list, item.id, y)
				b.Size = UDim2.new(1, -32, 0, 76)
				b.Text = t(item.titleKey)
					.. "\n"
					.. t(
						if item.done
							then "guideDone"
							elseif p.current == item.id then "guideNow"
							else "guideLater"
					)
				b.Activated:Connect(function()
					selected = item.id
					details.CanvasPosition = Vector2.zero
					render(state)
				end)
				y += 84
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, y)
	end
	primary.Activated:Connect(function()
		if not panel.Visible or not primary.Active then
			return
		end
		local p = progress()
		local chosen = selectedStep(p)
		local target = if chosen
			then chosen.action
			elseif p and p.status == "Done" then "Room"
			else nil
		if target then
			dismiss()
			navigate(target)
		end
	end)
	back.Activated:Connect(function()
		if selected then
			selected = nil
			render(state)
		else
			dismiss()
			navigate("Phone")
		end
	end)
	close.Activated:Connect(dismiss)
	local function show(): ()
		local p = progress()
		selected = if p and p.status == "Active" then p.current else nil
		details.CanvasPosition = Vector2.zero
		open()
		panel.Visible = true
		render(state)
	end
	local function step(blocked: boolean): ()
		local char = player.Character
		local h = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local alive = h ~= nil and h.Health > 0
		if not alive or player:GetAttribute("ProfileStatus") ~= "Ready" then
			hide()
		end
		if not pending then
			return
		end
		if screen:GetAttribute("ShowHints") == false then
			pending = false
			announced = true
			return
		end
		if blocked or not alive or progress() == nil then
			return
		end
		for _, name in { "ResultsPanel", "ClientPanel", "ProfilePanel" } do
			local other = screen:FindFirstChild(name)
			if other and other:IsA("GuiObject") and other.Visible then
				return
			end
		end
		pending, announced = false, true
		show()
	end
	return { render = render, show = show, hide = hide, step = step }
end
return Controller
