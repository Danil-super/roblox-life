--!strict
local Service = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")
local Progress = require(RS.Shared.PathProgress)
export type API = {
	update: (Vector3, Vector3, string, number) -> (Vector3?, number?, string),
	clear: () -> (),
	destroy: () -> (),
	points: () -> ({ Vector3 }, number),
}
local Route = {}
local function finite(n: number): boolean
	return n == n and math.abs(n) < 1000000
end
local function valid(v: Vector3): boolean
	return finite(v.X) and finite(v.Y) and finite(v.Z)
end
function Route.start(ownerId: number): API
	local points: { Vector3 } = {}
	local flat: { Progress.Point } = {}
	local index, version, retryAt = 1, 0, 0
	local refreshAt = 0
	local goal: Vector3? = nil
	local identity, status = "", "Finding"
	local busy, dirty, closed = false, true, false
	local path: Path? = nil
	local blocked: RBXScriptConnection? = nil
	local function retire(): ()
		if blocked then
			blocked:Disconnect()
			blocked = nil
		end
		if path then
			path:Destroy()
			path = nil
		end
	end
	local function release(): ()
		version += 1
		retire()
		points, flat, index = {}, {}, 1
		dirty, status = true, "Finding"
	end
	local function clear(): ()
		if goal == nil and #points == 0 then
			return
		end
		goal, identity = nil, ""
		release()
	end
	local function costs(): { [string]: number }
		local result: { [string]: number } = {}
		local homes = workspace:FindFirstChild("Homes")
		if homes then
			for _, room in homes:GetChildren() do
				local volume = room:FindFirstChild("NavigationVolume")
				local modifier = if volume
					then volume:FindFirstChildOfClass("PathfindingModifier")
					else nil
				if modifier then
					result[modifier.Label] = if room:GetAttribute("OwnerUserId") == ownerId
						then 1
						else math.huge
				end
			end
		end
		return result
	end
	return {
		clear = clear,
		destroy = function(): ()
			if closed then
				return
			end
			closed = true
			clear()
		end,
		points = function(): ({ Vector3 }, number)
			return points, index
		end,
		update = function(
			position: Vector3,
			destination: Vector3,
			key: string,
			now: number
		): (Vector3?, number?, string)
			if closed then
				return nil, nil, "Unavailable"
			end
			if
				not valid(position)
				or not valid(destination)
				or now ~= now
				or math.abs(now) == math.huge
				or (destination - position).Magnitude > 2048
			then
				clear()
				return nil, nil, "Unavailable"
			end
			local previous = goal
			if previous == nil or identity ~= key or (previous - destination).Magnitude > 1 then
				goal, identity = destination, key
				release()
			end
			if #points > 0 then
				index = Progress.advance(flat, index, position.X, position.Z)
				if Progress.deviation(flat, index, position.X, position.Z) > 6 then
					release()
				elseif now >= refreshAt then
					-- Blocked notifications alone did not cover every local geometry update in Studio.
					dirty = true
				end
			end
			if dirty and not busy and now >= retryAt then
				busy, dirty, retryAt = true, false, now + 0.75
				local stamp = version
				local regionCosts = costs()
				task.spawn(function()
					local created: Path? = nil
					local raw: { PathWaypoint } = {}
					local ok = pcall(function()
						local candidate = Service:CreatePath({
							-- Six-stud doors are walkable, but a radius-2 voxel agent cannot traverse them.
							AgentRadius = 1,
							AgentHeight = 5,
							AgentCanJump = false,
							AgentCanClimb = false,
							WaypointSpacing = 8,
							Costs = regionCosts,
						})
						created = candidate
						candidate:ComputeAsync(position, destination)
						if candidate.Status == Enum.PathStatus.Success then
							raw = candidate:GetWaypoints()
						end
					end)
					busy = false
					local candidate = created
					if closed or stamp ~= version then
						if candidate then
							candidate:Destroy()
						end
						return
					end
					local usable = ok and candidate ~= nil and #raw > 0 and #raw <= 512
					local positions: { Vector3 } = {}
					local coordinates: { Progress.Point } = {}
					if usable then
						for _, waypoint in raw do
							if
								not valid(waypoint.Position)
								or waypoint.Action ~= Enum.PathWaypointAction.Walk
							then
								usable = false
								break
							end
							table.insert(positions, waypoint.Position)
							table.insert(
								coordinates,
								{ x = waypoint.Position.X, z = waypoint.Position.Z }
							)
						end
					end
					if not usable or candidate == nil then
						if candidate then
							candidate:Destroy()
						end
						release()
						status, dirty, retryAt =
							"Unavailable", true, math.max(retryAt, os.clock() + 2)
						return
					end
					retire()
					path, points, flat, index, status =
						candidate, table.freeze(positions), coordinates, 1, "Ready"
					refreshAt, dirty = now + 3, false
					blocked = candidate.Blocked:Connect(function(blockedIndex: number)
						if
							not closed
							and path == candidate
							and stamp == version
							and blockedIndex >= index
						then
							release()
						end
					end)
				end)
			end
			if #points > 0 then
				index = Progress.advance(flat, index, position.X, position.Z)
				return points[index],
					Progress.distance(flat, index, position.X, position.Z),
					"Ready"
			end
			return nil, nil, status
		end,
	}
end
return Route
