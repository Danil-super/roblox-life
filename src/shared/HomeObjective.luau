--!strict
local Plan = require("./HomePlan")
local Types = require("./HomeTypes")
export type Cue =
	{ kind: "Base" | "Creative" | "Ready", placed: number, total: number, key: string }
local Objective = {}
function Objective.evaluate(s: Types.Snapshot?, blocked: boolean): Cue?
	if
		s == nil
		or blocked
		or not s.available
		or not s.nearHome
		or s.onboarding ~= "DONE"
		or s.plan == nil
	then
		return nil
	end
	local base = Plan.evaluate(s.items)
	if
		s.plan.placed ~= base.placed
		or s.plan.total ~= base.total
		or Plan.isComplete(s.plan) ~= Plan.isComplete(base)
	then
		return nil
	end
	if not Plan.isComplete(base) then
		return {
			kind = "Base",
			placed = base.placed,
			total = base.total,
			key = "Base:" .. base.placed .. "/" .. base.total,
		}
	end
	local goal = Plan.displayGoals(base, s.items)[4]
	if goal == nil then
		return nil
	end
	local placed = 0
	for _, requirement in goal.requirements do
		if requirement.placed then
			placed += 1
		end
	end
	local total = #goal.requirements
	if goal.complete then
		return {
			kind = "Ready",
			placed = placed,
			total = total,
			key = "Ready:" .. placed .. "/" .. total,
		}
	end
	return {
		kind = "Creative",
		placed = placed,
		total = total,
		key = "Creative:" .. placed .. "/" .. total,
	}
end
return table.freeze(Objective)
