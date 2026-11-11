--!strict
local Painting = require("../src/server/Domain/Painting")
local Config = require("../src/shared/PaintConfig")
local a = Painting.new("job", "work", 0, Config, nil, nil, true)
assert(Painting.step(a, "inspect", nil, 0, true), "Inspect failed")
assert(not Painting.step(a, "prepare", nil, 1, true), "Advanced work skipped clearing")
for i = 1, 3 do
	assert(not Painting.beginPreparation(a, i, i * 2, false), "Distant begin allowed")
	assert(Painting.beginPreparation(a, i, i * 2, true), "Clearing did not begin")
	assert(not Painting.finishPreparation(a, i, i * 2 + 0.1, true), "Instant clear allowed")
	assert(not Painting.finishPreparation(a, i, i * 2 + 0.7, false), "Distant finish allowed")
	assert(Painting.finishPreparation(a, i, i * 2 + 0.7, true), "Valid clear failed")
	assert(not Painting.finishPreparation(a, i, i * 2 + 0.8, true), "Repeated clear succeeded")
	assert(Painting.preparedCount(a) == i, "Incorrect confirmed count")
end
assert(Painting.step(a, "prepare", nil, 7, true), "Completed clearing did not unlock protection")
assert(not Painting.beginPreparation(a, 1, 8, true), "Clearing continued after protection")
local b = Painting.new("other", "other-work", 0, Config, nil, nil, true)
assert(Painting.preparedCount(b) == 0 and b.phase == "Inspect", "Player/work state leaked")
assert(Painting.step(b, "inspect", nil, 0, true), "Second inspect failed")
for _, bad in { 0, 4, 1.5, math.huge, 0 / 0 } do
	assert(not Painting.beginPreparation(b, bad, 1, true), "Invalid patch allowed")
end
assert(Painting.beginPreparation(b, 1, 1, true), "Begin failed")
assert(Painting.beginPreparation(b, 2, 1, true), "Second begin failed")
assert(not Painting.finishPreparation(b, 1, 2, true), "Concurrent patch finished")
assert(not Painting.finishPreparation(b, 2, 6, true), "Expired hold finished")
assert(not Painting.finishPreparation(b, 2, 0 / 0, true), "Invalid clock finished")
b.phase = "Ready"
assert(not Painting.allReady(b), "Incomplete preparation passed review")
local intro = Painting.new("intro", "short", 0, Config)
assert(Painting.step(intro, "inspect", nil, 0, true), "Intro inspect failed")
assert(Painting.step(intro, "prepare", nil, 1, true), "Intro gained advanced clearing")
print(
	"Preparation: real phase gate, timing, refusal/replay/expiry, one target, isolation and short intro passed"
)
