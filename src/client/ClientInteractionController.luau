--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local Strings = require(RS.Shared.Strings)
local Types = require(RS.Shared.JobTypes)
local Dialogue = require(RS.Shared.ClientDialogue)
local Config = require(RS.Shared.PaintConfig)
export type API = {
	render: (Types.Snapshot?) -> (),
	step: (boolean) -> (),
	hide: () -> (),
	isVisible: () -> boolean,
}
local Controller = {}
function Controller.start(
	screen: ScreenGui,
	language: () -> string,
	open: () -> (),
	act: (string) -> ()
): API
	local player = Players.LocalPlayer
	local state: Types.Snapshot? = nil
	local previous: Types.Snapshot? = nil
	local token: { jobId: string, workId: string }? = nil
	local started = 0
	local panel = Instance.new("Frame")
	panel.Name, panel.AnchorPoint, panel.Position =
		"ClientPanel", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	panel.Size, panel.BackgroundColor3, panel.ZIndex =
		UDim2.new(1, -24, 1, -24), Color3.fromRGB(26, 43, 43), 12
	panel.Visible, panel.Parent = false, screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize, limit.Parent = Vector2.new(520, 348), panel
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
		l.TextColor3, l.Font, l.ZIndex, l.Parent =
			Color3.fromRGB(244, 239, 224), Enum.Font.GothamMedium, 13, parent
		return l
	end
	local heading = label(panel, "Heading", 8, 36, 21)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -122)
	body.CanvasSize, body.BackgroundTransparency, body.BorderSizePixel =
		UDim2.fromOffset(0, 204), 1, 0
	body.ScrollBarThickness, body.ZIndex, body.Parent = 4, 13, panel
	local line, details = label(body, "Line", 0, 112, 16), label(body, "Details", 116, 84, 14)
	local function button(name: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name, b.Position, b.Size = name, UDim2.new(x, 16, 1, -56), UDim2.new(0.5, -24, 0, 44)
		b.TextWrapped, b.TextSize, b.Font = true, 14, Enum.Font.GothamMedium
		b.TextColor3, b.BackgroundColor3, b.ZIndex, b.Parent =
			Color3.fromRGB(244, 239, 224), Color3.fromRGB(55, 120, 102), 13, panel
		return b
	end
	local back, action = button("Close", 0), button("Action", 0.5)
	local function t(key: string): string
		return Strings.text(language(), key)
	end
	local function hide(): ()
		panel.Visible = false
		token = nil
	end
	back.Activated:Connect(hide)
	local function render(s: Types.Snapshot?): ()
		state = s
		if
			token
			and (
				s == nil
				or not s.available
				or not s.canTalk
				or s.jobId ~= token.jobId
				or s.workId ~= token.workId
				or s.phase == "Offer"
			)
		then
			hide()
		end
		if s ~= previous then
			previous = s
			if s and s.conversation and s.available and s.canTalk then
				open()
				token = { jobId = s.jobId, workId = s.workId }
				started = os.clock()
				body.CanvasPosition = Vector2.zero
				panel.Visible = true
			end
		end
		local d = if s then Dialogue.describe(s.clientKey or "residentNina", s.phase) else nil
		heading.Text = t(if d then d.speakerKey else "clientResident")
		line.Text = t(if d then d.lineKey else "offerWaiting")
		details.Text = if s
			then (if s.phase == "SurfaceReady"
				then t("jobSurfaceReady")
				else string.format(
					t("contractMaterial"),
					t(Config.colorKeys[s.requiredColorId or Config.colorId] or "warmWhite")
				)) .. "\n" .. string.format(t("residentReward"), s.reward)
			else ""
		back.Text, action.Text =
			t("closeClient"), t(if d and d.actionKey then d.actionKey else "roomGoalComplete")
		action.Visible = d ~= nil and d.action ~= nil
		action.Active = action.Visible and s ~= nil and s.available and s.canTalk == true
		back.Size = if action.Visible then UDim2.new(0.5, -24, 0, 44) else UDim2.new(1, -32, 0, 44)
	end
	action.Activated:Connect(function()
		local s = state
		local d = if s then Dialogue.describe(s.clientKey or "residentNina", s.phase) else nil
		if panel.Visible and action.Active and d and d.action then
			hide()
			act(d.action)
		end
	end)
	local shown = Prompts.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "TalkPrompt" and prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			prompt.Enabled = false
		end
	end)
	screen.Destroying:Once(function()
		shown:Disconnect()
	end)
	local tag: BillboardGui? = nil
	local tagged: Model? = nil
	local function step(blocked: boolean): ()
		local s = state
		local folder = workspace:FindFirstChild("Homes")
		local room = if folder and s and s.location then folder:FindFirstChild(s.location) else nil
		local resident = if room then room:FindFirstChild("Resident") else nil
		local char = player.Character
		local h = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local alive = h ~= nil and h.Health > 0 and player:GetAttribute("ProfileStatus") == "Ready"
		if not alive then
			hide()
		end
		if resident == nil or not resident:IsA("Model") or resident.PrimaryPart == nil then
			return
		end
		local torso = resident:FindFirstChild("Torso")
		if torso == nil or not torso:IsA("BasePart") then
			return
		end
		local near = root ~= nil
			and root:IsA("BasePart")
			and (root.Position - torso.Position).Magnitude <= 8
		if panel.Visible and not near then
			hide()
		end
		local modal = false
		for _, gui in screen:GetChildren() do
			if
				gui:IsA("GuiObject")
				and gui.Visible
				and (string.match(gui.Name, "Panel$") or string.match(gui.Name, "Toolbar$"))
			then
				modal = true
			end
		end
		local prompt = torso:FindFirstChild("TalkPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText, prompt.ObjectText =
				t("talkClient"), t(if s then s.clientKey or "clientResident" else "clientResident")
			prompt.Enabled = alive
				and not blocked
				and not modal
				and s ~= nil
				and s.available
				and s.canTalk == true
		end
		if tagged ~= resident then
			if tag then
				tag:Destroy()
			end
			local createdTag = Instance.new("BillboardGui")
			createdTag.Name, createdTag.Size, createdTag.StudsOffsetWorldSpace =
				"ResidentName", UDim2.fromOffset(180, 36), Vector3.new(0, 3.2, 0)
			createdTag.MaxDistance, createdTag.Adornee, createdTag.Parent = 35, torso, resident
			local text = label(createdTag, "Name", 0, 36, 16)
			text.BackgroundTransparency, text.BackgroundColor3 = 0, Color3.fromRGB(26, 43, 43)
			tagged = resident
			tag = createdTag
		end
		if tag then
			tag.Enabled = s ~= nil and s.phase ~= "Offer" and not blocked
			local text = tag:FindFirstChild("Name")
			if text and text:IsA("TextLabel") then
				text.Text = t(if s then s.clientKey or "clientResident" else "clientResident")
			end
		end
		local d = if s and panel.Visible
			then Dialogue.describe(s.clientKey or "residentNina", s.phase)
			else nil
		local elapsed = os.clock() - started
		local armX, armZ, headX, headY = 0, 0, 0, math.sin(os.clock() * 0.7) * 0.06
		if d then
			if d.gesture == "wave" then
				armZ = 2.4 + math.sin(elapsed * 9) * 0.18
			elseif d.gesture == "point" then
				armX = 1.1
			elseif d.gesture == "nod" then
				headX = math.sin(elapsed * 7) * 0.14
			end
		end
		local base = resident:GetPivot()
		for _, p in resident:GetChildren() do
			if p:IsA("BasePart") then
				local rest = p:GetAttribute("RestLocal")
				if typeof(rest) == "CFrame" then
					if p:GetAttribute("GestureGroup") == "head" then
						p.CFrame = base
							* CFrame.new(0, 4.5, 0)
							* CFrame.Angles(headX, headY, 0)
							* CFrame.new(0, -4.5, 0)
							* rest
					elseif p:GetAttribute("GestureGroup") == "arm" then
						p.CFrame = base
							* CFrame.new(1.35, 3.6, 0)
							* CFrame.Angles(armX, 0, armZ)
							* CFrame.new(-1.35, -3.6, 0)
							* rest
					end
				end
			end
		end
	end
	return {
		render = render,
		step = step,
		hide = hide,
		isVisible = function(): boolean
			return panel.Visible
		end,
	}
end
return Controller
