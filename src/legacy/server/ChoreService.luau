--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.ChoreRules)

type Session = {
	state: Rules.State,
	coins: IntValue,
}

local ChoreService = {}

function ChoreService.start(sink: BasePart, prompt: ProximityPrompt): ()
	local sessions: { [Player]: Session } = {}

	local function addPlayer(player: Player): ()
		if sessions[player] ~= nil then
			return
		end
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = stats
		sessions[player] = { state = Rules.new(), coins = coins }
		player:SetAttribute("ChoreBusy", false)
		stats.Parent = player
	end

	local function isEligible(player: Player): boolean
		if player.Parent ~= Players or not prompt.Enabled or not sink:IsDescendantOf(workspace) then
			return false
		end
		local character = player.Character
		if character == nil or not character:IsDescendantOf(workspace) then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
			return false
		end
		local direction = sink.Position - root.Position
		local distance = direction.Magnitude
		if distance ~= distance or distance > Rules.MAX_DISTANCE then
			return false
		end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, direction, filter)
		return hit == nil or hit.Instance == sink or hit.Instance:IsDescendantOf(sink)
	end

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	prompt.ObjectText = "Раковина"
	prompt.ActionText = string.format("Помыть посуду (+%d монет)", Rules.REWARD)
	prompt.MaxActivationDistance = Rules.MAX_DISTANCE
	prompt.RequiresLineOfSight = true
	-- The server schedules the full action; client HoldDuration is not a security boundary.
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(player: Player)
		local session = sessions[player]
		if session == nil or not Rules.begin(session.state, os.clock(), isEligible(player)) then
			return
		end
		local character = player.Character
		player:SetAttribute("ChoreBusy", true)
		task.delay(Rules.DURATION, function()
			if sessions[player] ~= session then
				return
			end
			local valid = player.Character == character and isEligible(player)
			if Rules.finish(session.state, os.clock(), valid) then
				session.coins.Value = session.state.coins
			end
			player:SetAttribute("ChoreBusy", false)
		end)
	end)
end

return ChoreService
