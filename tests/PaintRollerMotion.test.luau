--!strict
local Motion = require("../src/shared/PaintRollerMotion")
local s = Motion.new()
Motion.step(s, 0, 0, false, true)
Motion.step(s, 0, 2, false, true)
assert(s.spin == 0 and s.tilt == 0 and s.x == nil, "Hover animated or began a gesture")
Motion.step(s, 0, 2, true, true)
assert(s.spin == 0, "First contact bridged hover movement")
Motion.step(s, 0, 2, true, true)
assert(s.spin == 0 and s.tilt == 0, "Stationary roller rotated by time")
Motion.step(s, 0, 2.1, true, true)
local spin = s.spin
assert(spin > 0 and spin < math.pi * 2, "Vertical stroke did not roll")
Motion.step(s, 0, 2, true, true)
assert(
	math.abs(s.spin) < 0.0001 or math.abs(s.spin - math.pi * 2) < 0.0001,
	"Reverse stroke did not reverse spin"
)
Motion.step(s, 0.4, 2, true, true)
assert(s.tilt > 0 and math.abs(s.tilt) <= math.rad(12), "Lateral contact has no bounded feedback")
Motion.step(s, 20, 20, false, true)
assert(s.x == nil and s.tilt == 0, "Release retained gesture/lean")
local released = s.spin
Motion.step(s, -20, -20, true, true)
assert(s.spin == released, "New gesture bridged distant points")
Motion.step(s, 1e8, 1e8, true, true)
assert(
	s.spin >= 0 and s.spin < math.pi * 2 and math.abs(s.tilt) <= math.rad(12),
	"Large cosmetic jump produced unbounded pose"
)
Motion.step(s, 3, 4, true, false)
assert(s.spin == 0 and s.tilt == 0 and s.x == 3, "Reduced motion lost aim or animated")
Motion.step(s, 3, 4.1, true, true)
assert(s.spin > 0 and s.spin < 1, "Re-enabled motion bridged the disabled interval")
for _, value in { 0 / 0, math.huge, -math.huge } do
	Motion.step(s, value, 1, true, true)
	assert(s.x == nil and s.spin == 0 and s.tilt == 0, "Invalid point produced an invalid CFrame")
end
Motion.step(s, 1, 1, true, true)
Motion.reset(s)
assert(
	s.x == nil and s.y == nil and s.spin == 0 and s.tilt == 0,
	"Hidden/closed roller retained motion"
)
local other = Motion.new()
Motion.step(s, 0, 0, true, true)
Motion.step(s, 0, 0.1, true, true)
assert(other.spin == 0 and other.x == nil, "Rollers shared mutable motion state")
print(
	"PaintRollerMotion: contact/hover/stationary/reverse/release/reduced/invalid/reset/isolation passed"
)
