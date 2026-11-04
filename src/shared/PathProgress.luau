--!strict
export type Point = { x: number, z: number }
local Progress = {}
local REACH = 1.5
local function distance(a: Point, x: number, z: number): number
	return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end
local function projection(a: Point, b: Point, x: number, z: number): (number, number)
	local dx, dz = b.x - a.x, b.z - a.z
	local length = dx * dx + dz * dz
	if length < 0.000001 then
		return 0, distance(a, x, z)
	end
	local t = ((x - a.x) * dx + (z - a.z) * dz) / length
	return t, math.sqrt((x - a.x - t * dx) ^ 2 + (z - a.z - t * dz) ^ 2)
end
function Progress.advance(points: { Point }, index: number, x: number, z: number): number
	if #points == 0 then
		return 1
	end
	index = math.clamp(index, 1, #points)
	if index == 1 and #points > 1 then
		local t, side = projection(points[1], points[2], x, z)
		if t >= 0 and side <= REACH then
			index = 2
		end
	end
	while index < #points do
		local reached = distance(points[index], x, z) <= REACH
		if not reached and index > 1 then
			local a, b, c = points[index - 1], points[index], points[index + 1]
			local ux, uz, vx, vz = b.x - a.x, b.z - a.z, c.x - b.x, c.z - b.z
			local product = math.sqrt((ux * ux + uz * uz) * (vx * vx + vz * vz))
			local t, side = projection(a, b, x, z)
			reached = product > 0.000001
				and (ux * vx + uz * vz) / product > 0.99
				and t >= 1
				and side <= REACH
		end
		if not reached then
			break
		end
		index += 1
	end
	return index
end
function Progress.distance(points: { Point }, index: number, x: number, z: number): number?
	if #points == 0 then
		return nil
	end
	index = math.clamp(index, 1, #points)
	local total = distance(points[index], x, z)
	for i = index + 1, #points do
		total += distance(points[i], points[i - 1].x, points[i - 1].z)
	end
	return total
end
function Progress.deviation(points: { Point }, index: number, x: number, z: number): number
	if #points == 0 then
		return 0
	end
	index = math.clamp(index, 1, #points)
	if index == 1 then
		return distance(points[1], x, z)
	end
	local a, b = points[index - 1], points[index]
	local t = projection(a, b, x, z)
	t = math.clamp(t, 0, 1)
	return math.sqrt((x - a.x - t * (b.x - a.x)) ^ 2 + (z - a.z - t * (b.z - a.z)) ^ 2)
end
return table.freeze(Progress)
