--!strict
local Path = require("../src/shared/PathProgress")
local points = { { x = 0, z = 0 }, { x = 0, z = 10 }, { x = 10, z = 10 }, { x = 20, z = 10 } }
assert(Path.advance(points, 1, 0, 0) == 2, "Initial anchor did not advance")
assert(Path.advance(points, 1, 0, 4) == 2, "Moving during computation caused backtracking")
assert(Path.advance(points, 2, 0, 12) == 2, "A turn was skipped from too far away")
assert(Path.advance(points, 2, 0, 10) == 3, "Reached turn did not advance")
assert(Path.advance(points, 3, 12, 10) == 4, "Passed straight waypoint did not advance")
assert(Path.advance(points, 3, 12, 15) == 3, "Off-route position skipped a waypoint")
assert(Path.advance(points, 4, 20, 10) == 4, "Last point advanced beyond route")
assert(math.abs(assert(Path.distance(points, 2, 0, 4)) - 26) < 0.001, "Remaining path length wrong")
assert(math.abs(Path.deviation(points, 2, 3, 5) - 3) < 0.001, "Segment deviation wrong")
assert(math.abs(Path.deviation(points, 2, 0, 15) - 5) < 0.001, "Segment endpoint deviation wrong")
assert(
	Path.advance({}, 1, 0, 0) == 1 and Path.distance({}, 1, 0, 0) == nil,
	"Empty route not handled"
)
assert(points[2].z == 10 and points[3].x == 10, "Navigation mutated the path")
print("PathProgress: reach, overshoot, corners, deviation, length and immutable input passed")
