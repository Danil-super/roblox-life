--!strict
local Config = table.clone(require("../src/shared/PaintConfig"))
local Painting = require("../src/server/Domain/Painting")
local Jobs = require("../src/server/Domain/Jobs")
local Profile = require("../src/server/Domain/Profile")
local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print("PASS", name)
end
local function prepared()
	local work = Painting.new("job-1", "work-1", 0, Config)
	assert(Painting.step(work, "inspect", nil, 0, true), "Inspection failed")
	assert(Painting.step(work, "prepare", nil, 0, true), "Preparation failed")
	assert(Painting.step(work, "choose", "warm-white", 0, true), "Material failed")
	return work
end
local function cover(work: Painting.State): ()
	for row = 0, 7 do
		local points = {}
		for col = 0, 11 do
			table.insert(points, { u = (col + 0.5) / 12, v = (row + 0.5) / 8 })
		end
		assert(
			Painting.batch(work, row + 1, points, true, (row + 1) * 2, true),
			"Valid stroke row rejected"
		)
	end
end
test("phases cannot be skipped and wrong color is recoverable", function()
	local work = Painting.new("job-1", "work-1", 0, Config)
	assert(not Painting.step(work, "prepare", nil, 0, true), "Cannot skip inspection")
	assert(not Painting.step(work, "inspect", nil, 0, false), "Ineligible actor cannot inspect")
	assert(Painting.step(work, "inspect", nil, 0, true), "Inspection failed")
	assert(Painting.step(work, "prepare", nil, 0, true), "Preparation failed")
	assert(not Painting.step(work, "choose", "rose", 0, true), "Wrong color must be rejected")
	assert(work.phase == "ChooseMaterial", "Wrong color must remain fixable")
	assert(Painting.step(work, "choose", "warm-white", 0, true), "Correct color must recover")
end)
test("server interpolates coverage and counts each cell once", function()
	local work = prepared()
	assert(
		Painting.batch(work, 1, { { u = 0.05, v = 0.1 }, { u = 0.3, v = 0.1 } }, true, 1, true),
		"Stroke rejected"
	)
	assert(work.count >= 3 and work.count < 20, "Stroke must cover a local path")
	local count = work.count
	assert(
		not Painting.batch(work, 1, { { u = 0.9, v = 0.9 } }, true, 2, true),
		"Repeated sequence must be rejected"
	)
	assert(work.count == count, "Replay changed coverage")
	assert(
		Painting.batch(work, 2, { { u = 0.05, v = 0.1 }, { u = 0.3, v = 0.1 } }, true, 2, true),
		"Repeating a path with a new sequence is valid"
	)
	assert(work.count == count, "Repainting same cells must not inflate coverage")
end)
test("malformed, huge, nonfinite and distant strokes leave state unchanged", function()
	local work = prepared()
	for _, points in
		{
			false,
			{},
			{ { u = 0 / 0, v = 0.2 } },
			{ { u = math.huge, v = 0.2 } },
			{ { u = -0.1, v = 0.2 } },
			{ { u = 0.1, v = 2 } },
			{ { u = 0, v = 0 }, { u = 1, v = 1 } },
		}
	do
		assert(not Painting.batch(work, 1, points, true, 1, true), "Invalid stroke accepted")
	end
	local huge = {}
	for _ = 1, 13 do
		table.insert(huge, { u = 0.1, v = 0.1 })
	end
	assert(not Painting.batch(work, 1, huge, true, 1, true), "Oversized packet accepted")
	assert(
		not Painting.batch(work, 1, { { u = 0.1, v = 0.1 } }, true, 1, false),
		"Distant actor accepted"
	)
	assert(
		not Painting.batch(work, 1, { { u = 0.1, v = 0.1 } }, true, 0 / 0, true),
		"Invalid clock accepted"
	)
	assert(work.seq == 0 and work.count == 0, "Rejected packets mutated state")
end)
test("packet frequency, path jumps and area speed are bounded", function()
	local work = prepared()
	assert(
		Painting.batch(work, 1, { { u = 0.1, v = 0.1 } }, true, 1, true),
		"Initial stroke failed"
	)
	assert(
		not Painting.batch(work, 2, { { u = 0.2, v = 0.1 } }, false, 1.01, true),
		"Spam accepted"
	)
	assert(
		not Painting.batch(work, 2, { { u = 0.9, v = 0.9 } }, false, 2, true),
		"Teleporting roller accepted"
	)
	assert(
		Painting.batch(work, 2, { { u = 0.9, v = 0.9 } }, true, 2, true),
		"New gesture should not connect across the wall"
	)
end)
test("inspection requires real server coverage and elapsed time", function()
	local work = prepared()
	assert(not Painting.step(work, "review", nil, 1, true), "Empty wall cannot pass")
	cover(work)
	assert(work.count == 96, "Full paths must cover the wall")
	assert(
		Painting.step(work, "review", nil, 17, true) and work.phase == "Ready",
		"Painted wall did not pass"
	)
	assert(
		not Painting.batch(work, 9, { { u = 0.1, v = 0.1 } }, true, 18, true),
		"Accepted work must not accept strokes"
	)
end)
test("orders, reward and permanent replay proof settle together", function()
	local p = Profile.new(1)
	assert(Jobs.accept(p, "job-1"), "Accept failed")
	assert(not Jobs.accept(p, "job-2"), "Cannot replace active order")
	local work = prepared()
	cover(work)
	assert(not Jobs.submit(p, work, 17, true), "Must inspect result before submission")
	assert(Painting.step(work, "review", nil, 17, true), "Review failed")
	assert(not Jobs.submit(p, work, 17, false), "Absent actor cannot receive reward")
	assert(Jobs.submit(p, work, 17, true), "Submit failed")
	assert(
		Jobs.submit(p, work, 18, true),
		"Duplicate submit must return success without paying again"
	)
	assert(p.wallet.dollars == 250 and p.jobs.completedCount == 1, "Reward duplicated or missing")
	assert(Profile.decode(p, 1) ~= nil, "Result must remain serializable")
end)
test("cancel and fresh work session never preserve old strokes", function()
	local p = Profile.new(1)
	assert(Jobs.accept(p, "job-1"), "Accept failed")
	assert(Jobs.cancel(p, "job-1"), "Cancel failed")
	assert(
		p.wallet.dollars == 0 and Jobs.accept(p, "job-2"),
		"Cancel must allow another order without reward"
	)
	local first, second = prepared(), Painting.new("job-1", "work-2", 1, Config)
	assert(Painting.batch(first, 1, { { u = 0.1, v = 0.1 } }, true, 2, true), "Stroke failed")
	assert(second.count == 0 and second.phase == "Inspect", "Work sessions share state")
	assert(not Jobs.submit(p, first, 20, true), "Old job cannot pay against a new order")
end)
test("area budget rejects a fast whole-wall fill without partial mutation", function()
	local work = prepared()
	local first, second = {}, {}
	for col = 0, 11 do
		table.insert(first, { u = (col + 0.5) / 12, v = 0.5 / 8 })
		table.insert(second, { u = (col + 0.5) / 12, v = 1.5 / 8 })
	end
	assert(Painting.batch(work, 1, first, true, 1, true), "First row must fit burst budget")
	local count = work.count
	assert(not Painting.batch(work, 2, second, true, 1.1, true), "Rapid new area must be rejected")
	assert(work.seq == 1 and work.count == count, "Budget rejection must not partially paint")
	assert(Painting.batch(work, 2, second, true, 3, true), "Budget must recover over server time")
	assert(not Painting.batch(work, 0 / 0, first, true, 4, true), "NaN sequence must not pass")
	assert(
		not Painting.batch(
			work,
			3,
			{ [1] = { u = 0.1, v = 0.1 }, [3] = { u = 0.2, v = 0.1 } },
			true,
			4,
			true
		),
		"Sparse point packet must not pass"
	)
end)

print(string.format("%d painting/job tests passed", passed))
