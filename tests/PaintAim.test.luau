--!strict
local Aim = require("../src/shared/PaintAim")
local function cast(x: number, y: number)
	return Aim.project({ x = x, y = y, z = 10 }, { x = 0, y = 0, z = -1 }, 12, 8, 0.3, 0.35)
end
local center = cast(0, 0)
assert(center and center.u == 0.5 and center.v == 0.5, "Wall center moved")
for _, xy in { { -6.3, 0 }, { 6.3, 0 }, { 0, -4.3 }, { 0, 4.3 } } do
	local p = cast(xy[1], xy[2])
	assert(p and p.u >= 0 and p.u <= 1 and p.v >= 0 and p.v <= 1, "Near edge not clamped")
end
assert(cast(6.35, 0), "Inclusive edge tolerance lost")
assert(not cast(6.36, 0) and not cast(0, 4.36), "Distant ray painted wall")
assert(not cast(6.3, 4.3), "Corner tolerance grew diagonally")
local corner = cast(6.2, 4.2)
assert(corner and corner.u == 1 and corner.v == 0, "Near corner did not snap")
local origin = { x = 0, y = 0, z = 10 }
assert(not Aim.project(origin, { x = 1, y = 0, z = 0 }, 12, 8, 0.3, 0.35), "Parallel ray accepted")
assert(not Aim.project(origin, { x = 0, y = 0, z = 1 }, 12, 8, 0.3, 0.35), "Backward ray accepted")
assert(
	not Aim.project({ x = 0, y = 0, z = -10 }, { x = 0, y = 0, z = 1 }, 12, 8, 0.3, 0.35),
	"Back face accepted"
)
assert(not cast(0 / 0, 0) and not cast(math.huge, 0), "Nonfinite ray accepted")
assert(not Aim.project(origin, { x = 0, y = 0, z = -1 }, 0, 8, 0.3, 0.35), "Invalid wall accepted")
assert(
	not Aim.project(origin, { x = 0, y = 0, z = -1 }, 12, 8, 0.3, -1),
	"Negative tolerance accepted"
)
local exact = Aim.project(origin, { x = 0, y = 0, z = -1 }, 12, 8, 0.3, 0)
assert(exact and exact.u == center.u and exact.v == center.v, "Exact hit depends on assistance")
assert(
	not Aim.project({ x = 0, y = 0, z = 200 }, { x = 0, y = 0, z = -1 }, 12, 8, 0.3, 0.35),
	"Ray range grew"
)
print("PaintAim: bounded edges/corners, exact hits, face/range/finite validation passed")
