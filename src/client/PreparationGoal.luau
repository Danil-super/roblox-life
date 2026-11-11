--!strict
local RS = game:GetService("ReplicatedStorage")
local Types = require(RS.Shared.JobTypes)
local Goals = require(RS.Shared.NavigationGoal)
local Goal = {}
export type Resolver = (Types.Snapshot?, BasePart?) -> (Goals.Goal?, BasePart?)
function Goal.start(screen: ScreenGui, ownerId: number): Resolver
	local selected: BasePart? = nil
	local workKey = ""
	local disposed = false
	screen.Destroying:Once(function()
		disposed, selected, workKey = true, nil, ""
	end)
	return function(s: Types.Snapshot?, root: BasePart?): (Goals.Goal?, BasePart?)
		if
			disposed
			or s == nil
			or not s.available
			or s.phase ~= "Prepare"
			or s.jobId == ""
			or s.workId == ""
			or root == nil
		then
			selected, workKey = nil, ""
			return nil, nil
		end
		local homes = workspace:FindFirstChild("Homes")
		local room = if homes and s.location then homes:FindFirstChild(s.location) else nil
		if room == nil or room:GetAttribute("OwnerUserId") ~= ownerId then
			selected, workKey = nil, ""
			return nil, nil
		end
		local key = s.jobId .. ":" .. s.workId
		if key ~= workKey then
			selected, workKey = nil, key
		end
		local pending = (s.preparedCount or 0) < (s.preparationRequired or 0)
		local target: BasePart? = nil
		if pending then
			local folder = room:FindFirstChild("WallPreparation")
			local function valid(part: BasePart?): boolean
				return part ~= nil
					and folder ~= nil
					and part.Parent == folder
					and part.Name:match("^OldFinish[123]$") ~= nil
					and part:GetAttribute("OwnerUserId") == ownerId
					and part:GetAttribute("Cleared") ~= true
			end
			if not valid(selected) then
				selected = nil
				local distance = math.huge
				if folder then
					for _, part in folder:GetChildren() do
						if part:IsA("BasePart") and valid(part) then
							local d = (part.Position - root.Position).Magnitude
							if d < distance then
								selected, distance = part, d
							end
						end
					end
				end
			end
			target = selected
		else
			selected = nil
			local cloth = room:FindFirstChild("Protection")
			target = if cloth and cloth:IsA("BasePart") then cloth else nil
		end
		if target == nil then
			return nil, nil
		end
		local point = target.CFrame:PointToWorldSpace(
			if pending then Vector3.new(0, -1.5, 4) else Vector3.new(0, 3, 0)
		)
		local goal: Goals.Goal = {
			key = key .. ":" .. target.Name,
			kind = "Job",
			roomName = s.location,
			destination = { point.X, point.Y, point.Z },
			labelKey = if pending then "oldFinish" else "protectFloor",
			actionKey = if pending then "scrapeBeaconHint" else nil,
			areaKey = "clientApartment",
			available = s.available,
			near = (root.Position - point).Magnitude <= 2.5,
		}
		return goal, target
	end
end
return table.freeze(Goal)
