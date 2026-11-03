--!strict
export type Bounds = { left: number, right: number, back: number, front: number }
export type Layout = {
	width: number,
	height: number,
	legendY: number,
	hintY: number,
	contentHeight: number,
}
local Map = {}
function Map.layout(width: number, height: number): Layout
	local boardHeight = math.clamp(height - 64, 50, 212)
	return {
		width = math.max(40, width - 32),
		height = boardHeight,
		legendY = boardHeight + 10,
		hintY = boardHeight + 30,
		contentHeight = boardHeight + 58,
	}
end
function Map.bounds(homeX: number, homeZ: number, targetX: number?, targetZ: number?): Bounds
	local tx, tz = targetX or homeX, targetZ or (homeZ + 68)
	local xSpan, zSpan =
		math.max(72, math.abs(tx - homeX) + 24), math.max(96, math.abs(tz - homeZ) + 24)
	local cx, cz = (homeX + tx) / 2, (homeZ + tz) / 2
	return {
		left = cx - xSpan / 2,
		right = cx + xSpan / 2,
		back = cz - zSpan / 2,
		front = cz + zSpan / 2,
	}
end
function Map.pixel(
	x: number,
	z: number,
	bounds: Bounds,
	width: number,
	height: number
): (number, number)
	local u = math.clamp((x - bounds.left) / (bounds.right - bounds.left), 0, 1)
	local v = math.clamp((bounds.front - z) / (bounds.front - bounds.back), 0, 1)
	return 10 + u * (width - 20), 10 + v * (height - 20)
end
return table.freeze(Map)
