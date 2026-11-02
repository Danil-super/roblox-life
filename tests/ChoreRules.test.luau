--!strict
local Rules = require("../src/shared/ChoreRules")
local passed = 0

local function test(name: string, run: () -> ())
	run()
	passed += 1
	print("PASS", name)
end

test("new player has no coins and no pending action", function()
	local state = Rules.new()
	assert(
		state.coins == 0 and state.completesAt == nil,
		"Expected: state.coins == 0 and state.completesAt == nil"
	)
end)

test("dead or distant player cannot begin", function()
	local state = Rules.new()
	assert(not Rules.begin(state, 10, false), "Expected: not Rules.begin(state, 10, false)")
	assert(state.completesAt == nil, "Expected: state.completesAt == nil")
end)

test("action takes server time and pays exactly once", function()
	local state = Rules.new()
	assert(Rules.begin(state, 10, true), "Expected: Rules.begin(state, 10, true)")
	assert(not Rules.finish(state, 11.999, true), "Expected: not Rules.finish(state, 11.999, true)")
	assert(state.coins == 0, "Expected: state.coins == 0")
	assert(Rules.finish(state, 12, true), "Expected: Rules.finish(state, 12, true)")
	assert(state.coins == 10, "Expected: state.coins == 10")
	assert(not Rules.finish(state, 12, true), "Expected: not Rules.finish(state, 12, true)")
	assert(state.coins == 10, "Expected: state.coins == 10")
end)

test("spam cannot replace a pending action or bypass cooldown", function()
	local state = Rules.new()
	assert(Rules.begin(state, 10, true), "Expected: Rules.begin(state, 10, true)")
	assert(not Rules.begin(state, 11, true), "Expected: not Rules.begin(state, 11, true)")
	assert(state.completesAt == 12, "Expected: state.completesAt == 12")
	assert(Rules.finish(state, 12, true), "Expected: Rules.finish(state, 12, true)")
	assert(not Rules.begin(state, 14.999, true), "Expected: not Rules.begin(state, 14.999, true)")
	assert(Rules.begin(state, 15, true), "Expected: Rules.begin(state, 15, true)")
	assert(Rules.finish(state, 17, true), "Expected: Rules.finish(state, 17, true)")
	assert(state.coins == 20, "Expected: state.coins == 20")
end)

test("leaving range or dying before completion cancels reward", function()
	local state = Rules.new()
	assert(Rules.begin(state, 10, true), "Expected: Rules.begin(state, 10, true)")
	assert(not Rules.finish(state, 12, false), "Expected: not Rules.finish(state, 12, false)")
	assert(
		state.coins == 0 and state.completesAt == nil,
		"Expected: state.coins == 0 and state.completesAt == nil"
	)
	assert(not Rules.finish(state, 13, true), "Expected: not Rules.finish(state, 13, true)")
	assert(not Rules.begin(state, 14, true), "Expected: not Rules.begin(state, 14, true)")
	assert(Rules.begin(state, 15, true), "Expected: Rules.begin(state, 15, true)")
end)

test("players have independent wallets and cooldowns", function()
	local first, second = Rules.new(), Rules.new()
	assert(Rules.begin(first, 10, true), "Expected: Rules.begin(first, 10, true)")
	assert(Rules.begin(second, 10, true), "Expected: Rules.begin(second, 10, true)")
	assert(Rules.finish(first, 12, true), "Expected: Rules.finish(first, 12, true)")
	assert(
		second.coins == 0 and second.completesAt == 12,
		"Expected: second.coins == 0 and second.completesAt == 12"
	)
end)

test("unscheduled completion cannot create money", function()
	local state = Rules.new()
	assert(not Rules.finish(state, 100, true), "Expected: not Rules.finish(state, 100, true)")
	assert(state.coins == 0, "Expected: state.coins == 0")
end)

test("non-finite clock cannot corrupt action state", function()
	local state = Rules.new()
	assert(not Rules.begin(state, 0 / 0, true), "Expected: not Rules.begin(state, 0 / 0, true)")
	assert(
		not Rules.begin(state, math.huge, true),
		"Expected: not Rules.begin(state, math.huge, true)"
	)
	assert(
		not Rules.begin(state, -math.huge, true),
		"Expected: not Rules.begin(state, -math.huge, true)"
	)
	assert(Rules.begin(state, 10, true), "Expected: Rules.begin(state, 10, true)")
	assert(not Rules.finish(state, 0 / 0, true), "Expected: not Rules.finish(state, 0 / 0, true)")
	assert(
		not Rules.finish(state, math.huge, true),
		"Expected: not Rules.finish(state, math.huge, true)"
	)
	assert(Rules.finish(state, 12, true), "Expected: Rules.finish(state, 12, true)")
end)

test("clock going backwards does not complete action", function()
	local state = Rules.new()
	assert(Rules.begin(state, 10, true), "Expected: Rules.begin(state, 10, true)")
	assert(not Rules.finish(state, 9, true), "Expected: not Rules.finish(state, 9, true)")
	assert(
		state.coins == 0 and state.completesAt == 12,
		"Expected: state.coins == 0 and state.completesAt == 12"
	)
end)

print(string.format("%d tests passed (standalone Luau; Studio not exercised)", passed))
