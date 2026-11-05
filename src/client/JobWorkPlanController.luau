--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage.Shared.JobWorkPlan)
local Types = require(ReplicatedStorage.Shared.JobTypes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Controller = {}
function Controller.start(body: ScrollingFrame, language: () -> string)
	local baseCanvas = body.CanvasSize
	local root = Instance.new("Frame")
	root.Name, root.BackgroundTransparency = "WorkPlan", 1
	root.Position, root.Size = UDim2.fromOffset(16, 284), UDim2.new(1, -32, 0, 370)
	root.Visible, root.Parent = false, body
	local function text(
		parent: Instance,
		name: string,
		y: number,
		height: number,
		size: number
	): TextLabel
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = name, 1
		label.Position, label.Size = UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, height)
		label.TextWrapped, label.TextSize = true, size
		label.Font, label.TextXAlignment = Enum.Font.GothamMedium, Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(table.unpack(Theme.colors.paper))
		label.Parent = parent
		return label
	end
	local title = text(root, "Title", 0, 34, 16)
	title.Font = Enum.Font.GothamBold
	local rows: { { number: TextLabel, title: TextLabel, state: TextLabel } } = {}
	for i = 1, 5 do
		local row = Instance.new("Frame")
		row.Name, row.BackgroundTransparency = "Step" .. i, 1
		row.Position, row.Size = UDim2.fromOffset(0, 42 + (i - 1) * 48), UDim2.new(1, 0, 0, 44)
		row.Parent = root
		local number = text(row, "Number", 8, 28, 14)
		number.Size, number.BackgroundTransparency = UDim2.fromOffset(28, 28), 0
		number.TextXAlignment, number.Text = Enum.TextXAlignment.Center, tostring(i)
		local corner = Instance.new("UICorner")
		corner.Parent = number
		local label = text(row, "Title", 0, 44, 14)
		label.Position, label.Size = UDim2.fromOffset(36, 0), UDim2.new(1, -108, 0, 44)
		local status = text(row, "State", 4, 36, 12)
		status.Position, status.Size = UDim2.new(1, -68, 0, 4), UDim2.fromOffset(68, 36)
		status.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { number = number, title = label, state = status })
	end
	local note = text(root, "Note", 290, 78, 13)
	note.TextColor3 = Color3.fromRGB(table.unpack(Theme.colors.muted))
	local closed = false
	body.Destroying:Once(function()
		closed = true
	end)
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function render(s: Types.Snapshot?, ready: boolean): string?
		if closed then
			return nil
		end
		local p = Plan.evaluate(s, ready)
		root.Visible = p ~= nil
		body.CanvasSize = if p then UDim2.fromOffset(0, 666) else baseCanvas
		if not p then
			return nil
		end
		local wall = string.format(t("surfaceProgress"), p.surfaceIndex, p.surfaceTotal)
		title.Text = t("workPlanTitle") .. (if p.surfaceTotal > 1 then " · " .. wall else "")
		local keys = { "jobInspect", "jobPrepare", "jobColor", "workPlanPaint", "handoverClient" }
		for i, row in rows do
			local status = p.states[i]
			row.title.Text, row.state.Text = t(keys[i]), t("workPlan" .. status)
			row.title.Font = if status == "Current"
				then Enum.Font.GothamBold
				else Enum.Font.GothamMedium
			row.title.TextColor3 = Color3.fromRGB(
				table.unpack(if status == "Next" then Theme.colors.muted else Theme.colors.paper)
			)
			row.state.TextColor3 = row.title.TextColor3
			row.number.BackgroundColor3 = Color3.fromRGB(
				table.unpack(
					if status == "Current"
						then Theme.colors.paper
						elseif status == "Done" then Theme.colors.accent
						else Theme.colors.surface
				)
			)
			row.number.TextColor3 = Color3.fromRGB(
				table.unpack(if status == "Current" then Theme.colors.ink else Theme.colors.paper)
			)
		end
		note.Text = t(p.noteKey)
		local caption = if p.current == 0
			then t("workPlanWallChecked")
			else string.format(t("workPlanStep"), p.current, 5)
		if p.percent ~= nil then
			caption ..= string.format(" · %d%%", p.percent)
		end
		return (if p.surfaceTotal > 1 then wall .. " · " else "") .. caption
	end
	return { render = render }
end
return Controller
