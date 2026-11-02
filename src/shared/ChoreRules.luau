--!strict
-- Pure rules: no Roblox services, clock, network or persistence.
local ChoreRules = {}

ChoreRules.REWARD = 10
ChoreRules.DURATION = 2
ChoreRules.COOLDOWN = 3
ChoreRules.MAX_DISTANCE = 8

export type State = {
	coins: number,
	readyAt: number,
	completesAt: number?,
}

function ChoreRules.new(): State
	return { coins = 0, readyAt = 0, completesAt = nil }
end

local function isFinite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function ChoreRules.begin(state: State, now: number, eligible: boolean): boolean
	if not eligible or not isFinite(now) or state.completesAt ~= nil or now < state.readyAt then
		return false
	end
	state.completesAt = now + ChoreRules.DURATION
	return true
end

function ChoreRules.finish(state: State, now: number, eligible: boolean): boolean
	local completesAt = state.completesAt
	if completesAt == nil or not isFinite(now) or now < completesAt then
		return false
	end
	state.completesAt = nil
	state.readyAt = now + ChoreRules.COOLDOWN
	if not eligible then
		return false
	end
	state.coins += ChoreRules.REWARD
	return true
end

return table.freeze(ChoreRules)
