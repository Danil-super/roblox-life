--!strict
local Map = require("../src/shared/MapMath")
local bounds = Map.bounds(0, 0, 0, 72.35)
for _, size in { { 480, 266 }, { 480, 170 }, { 544, 114 }, { 350, 266 }, { 296, 114 } } do
	local layout = Map.layout(size[1], size[2])
	assert(layout.height >= 50 and layout.contentHeight <= size[2], "Map requires scrolling")
	assert(layout.width + 32 <= size[1], "Map clipped horizontally")
	assert(
		layout.legendY >= layout.height + 6 and layout.hintY >= layout.legendY + 18,
		"Map labels overlap"
	)
	for _, point in { { 0, 0 }, { 0, 72.35 }, { 32, 6 }, { -1000, 1000 } } do
		local x, y = Map.pixel(point[1], point[2], bounds, layout.width, layout.height)
		assert(x >= 10 and x <= layout.width - 10, "Marker outside horizontal safe margin")
		assert(y >= 10 and y <= layout.height - 10, "Marker outside vertical safe margin")
	end
end
local hx, hy = Map.pixel(0, 0, bounds, 400, 150)
local tx, ty = Map.pixel(0, 72.35, bounds, 400, 150)
assert(math.abs(hx - tx) < 0.001 and hy > ty, "Client must appear north of home")
local shifted = Map.bounds(128, 256, 128, 328.35)
local sx, sy = Map.pixel(128, 256, shifted, 400, 150)
assert(math.abs(sx - hx) < 0.001 and math.abs(sy - hy) < 0.001, "Room slot changes map geometry")
local empty = Map.bounds(0, 0, nil, nil)
local ex, ey = Map.pixel(0, 0, empty, 400, 150)
assert(ex == ex and ey == ey, "No-job map has invalid coordinates")
print("MapMath: layout, bounds, room-slot translation and no-job cases passed")
