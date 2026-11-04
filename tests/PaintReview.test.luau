--!strict
local Painting = require("../src/server/Domain/Painting")
local Config = require("../src/shared/PaintConfig")
local s = Painting.new("job", "work", 0, Config)
s.config.minSeconds = 30
assert(Painting.reviewError(s, 31) == "Retry", "Wrong phase invented coverage failure")
for _, action in { "inspect", "prepare", "choose" } do
	assert(Painting.step(s, action, "warm-white", 0, true))
end
assert(Painting.reviewError(s, 31) == "Coverage", "Empty wall not identified")
for row = 0, 7 do
	local points = {}
	for col = 0, 11 do
		table.insert(points, { u = (col + 0.5) / 12, v = (row + 0.5) / 8 })
	end
	assert(Painting.batch(s, row + 1, points, true, (row + 1) * 2, true))
end
assert(
	s.count == 96 and Painting.reviewError(s, 16) == "Drying",
	"Covered wall reported as missing paint"
)
assert(
	not Painting.step(s, "review", nil, 16, true) and s.phase == "Painting",
	"Minimum time bypassed"
)
assert(Painting.reviewError(s, 30) == nil, "Exact time boundary rejected")
assert(not Painting.step(s, "review", nil, 30, false), "Ineligible actor advanced")
assert(Painting.reviewError(s, 0 / 0) == "Retry", "NaN clock accepted")
assert(Painting.reviewError(s, 15) == "Retry", "Clock rollback accepted")
assert(Painting.step(s, "review", nil, 30, true) and s.phase == "Ready", "Valid review refused")
assert(not Painting.step(s, "review", nil, 31, true), "Review repeated phase transition")
print("PaintReview: phase/coverage/time, boundary, rollback, eligibility and repeat passed")
