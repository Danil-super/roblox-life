--!strict
local Surface = require("../src/shared/PaintSurface")
local Config = require("../src/shared/PaintConfig")
local count = Config.columns * Config.rows
local empty, full = string.rep("0", count), string.rep("1", count)
local function at(values: { number }, x: number, y: number): number
	return values[y * Surface.columns + x + 1]
end
assert(
	Surface.columns == 36 and Surface.rows == 24 and Surface.columns * Surface.rows <= 1024,
	"Visual budget changed"
)
local blank, painted = Surface.build(empty), Surface.build(full)
assert(#blank == 864 and #painted == 864, "Wrong visual dimensions")
for i = 1, #blank do
	assert(blank[i] == 1 and painted[i] == 0, "Blank/full mask not faithful at boundary")
end
for _, bad in
	{
		"",
		string.rep("1", count - 1),
		string.rep("1", count + 1),
		"x" .. string.rep("0", count - 1),
	}
do
	for _, alpha in Surface.build(bad) do
		assert(alpha == 1, "Malformed mask invented accepted paint")
	end
end
local mask = string.rep("0", 39) .. "1" .. string.rep("0", count - 40)
local before = mask
local dot = Surface.build(mask)
-- Coarse cell x=3,y=3. Its centre is fine pixel x=10,y=10.
assert(at(dot, 10, 10) == 0, "Confirmed centre disappeared")
assert(at(dot, 9, 10) > 0 and at(dot, 9, 10) < 1, "Edge is still a solid coarse tile")
assert(at(dot, 8, 10) > at(dot, 9, 10) and at(dot, 7, 10) == 1, "Paint edge is not smooth/local")
assert(at(dot, 13, 10) == 1, "Unconfirmed neighbour centre painted")
local adjacent = Surface.build(string.rep("0", 39) .. "11" .. string.rep("0", count - 41))
assert(at(adjacent, 11, 10) == 0 and at(adjacent, 12, 10) == 0, "Seam between confirmed neighbours")
for i, alpha in dot do
	assert(alpha == alpha and alpha >= 0 and alpha <= 1, "Invalid opacity")
	assert(adjacent[i] <= alpha, "Adding coverage erased paint")
end
assert(mask == before, "Visual calculation mutated authoritative input")
dot[1] = 0
assert(Surface.build(empty)[1] == 1 and Surface.build(mask)[1] == 1, "Visual state crossed calls")
print(
	"PaintSurface: bounded field, blank/full/invalid, soft edges, seams, monotonicity and isolation passed"
)
