--!strict
local RouteMath = require("../src/shared/RouteMath")
local function near(actual: number, expected: number): ()
	assert(math.abs(actual - expected) < 0.001, "Incorrect camera-relative bearing")
end
near(RouteMath.bearing(0, -10, 0, -1), 0)
near(RouteMath.bearing(10, 0, 0, -1), 90)
near(RouteMath.bearing(-10, 0, 0, -1), -90)
near(math.abs(RouteMath.bearing(0, 10, 0, -1)), 180)
near(RouteMath.bearing(10, 0, 1, 0), 0)
near(RouteMath.bearing(0, 10, 1, 0), 90)
print("RouteMath: 6 camera-relative direction checks passed")
