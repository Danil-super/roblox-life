--!strict
type Vector = { x: number, y: number, z: number }
export type Point = { u: number, v: number }
local Aim = {}
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
-- Local-space ray against the front (+Z) face. Assistance only clamps near edges.
function Aim.project(
	origin: Vector,
	direction: Vector,
	width: number,
	height: number,
	depth: number,
	margin: number
): Point?
	for _, n in
		{
			origin.x,
			origin.y,
			origin.z,
			direction.x,
			direction.y,
			direction.z,
			width,
			height,
			depth,
			margin,
		}
	do
		if not finite(n) then
			return nil
		end
	end
	if width <= 0 or height <= 0 or depth <= 0 or margin < 0 or direction.z >= -0.000001 then
		return nil
	end
	local distance = (depth / 2 - origin.z) / direction.z
	if distance <= 0 or distance > 150 then
		return nil
	end
	local x, y = origin.x + direction.x * distance, origin.y + direction.y * distance
	local cx, cy = math.clamp(x, -width / 2, width / 2), math.clamp(y, -height / 2, height / 2)
	if (x - cx) ^ 2 + (y - cy) ^ 2 > margin ^ 2 + 0.000000001 then
		return nil
	end
	return { u = cx / width + 0.5, v = 0.5 - cy / height }
end
return table.freeze(Aim)
