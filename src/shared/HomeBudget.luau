--!strict
local Plan = require("./HomePlan")
local Types = require("./HomeTypes")
local Strings = require("./Strings")
export type Budget = {
	ready: boolean,
	placed: number,
	total: number,
	cost: number,
	shortfall: number,
	stored: number,
	action: "Wait" | "Place" | "Buy" | "Earn" | "Complete",
}
local Budget = {}
local function integer(value: number): boolean
	return value == value and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
function Budget.evaluate(
	goal: Plan.Goal,
	catalog: { Types.Product },
	dollars: number,
	available: boolean
): Budget
	local result: Budget = {
		ready = false,
		placed = 0,
		total = 0,
		cost = 0,
		shortfall = 0,
		stored = 0,
		action = "Wait",
	}
	if not available or not integer(dollars) or #goal.requirements == 0 then
		return result
	end
	local prices: { [string]: number } = {}
	for _, product in catalog do
		if prices[product.id] ~= nil or not integer(product.dollars) then
			return result
		end
		prices[product.id] = product.dollars
	end
	local seen: { [string]: boolean } = {}
	local affordable = false
	for _, requirement in goal.requirements do
		if seen[requirement.catalogId] or (requirement.placed and requirement.itemId == nil) then
			return result
		end
		seen[requirement.catalogId] = true
		result.total += 1
		if requirement.itemId then
			if requirement.placed then
				result.placed += 1
			else
				result.stored += 1
			end
		else
			local price = prices[requirement.catalogId]
			if price == nil or not integer(result.cost + price) then
				return result
			end
			result.cost += price
			affordable = affordable or dollars >= price
		end
	end
	result.ready = true
	result.shortfall = math.max(0, result.cost - dollars)
	result.action = if result.placed == result.total
		then "Complete"
		elseif result.stored > 0 then "Place"
		elseif affordable then "Buy"
		else "Earn"
	return result
end
function Budget.text(value: Budget, language: string): string
	if not value.ready then
		return Strings.text(language, "offerWaiting")
	end
	local progress = string.format(
		Strings.text(language, "roomBudgetCost"),
		value.placed,
		value.total,
		value.cost
	)
	local hint = if value.action == "Complete"
		then Strings.text(language, "roomGoalComplete")
		elseif value.cost == 0 and value.action == "Place" then Strings.text(
			language,
			"roomBudgetStored"
		)
		elseif value.shortfall > 0 then string.format(
			Strings.text(language, "roomBudgetNeed"),
			value.shortfall
		)
		else Strings.text(language, "roomBudgetReady")
	return progress .. "\n" .. hint
end
return table.freeze(Budget)
