--!strict
export type Facts = { completed: boolean, paid: boolean, ownsFurniture: boolean, phase: string }
export type Step = {
	id: string,
	titleKey: string,
	detailKey: string,
	action: string,
	actionKey: string,
	done: boolean,
}
export type Progress = {
	status: string,
	completed: number,
	total: number,
	current: string?,
	steps: { Step },
}
local definitions = {
	{ id = "job", titleKey = "guideJob", action = "Jobs", actionKey = "openJobs" },
	{ id = "meet", titleKey = "guideMeet", action = "Current", actionKey = "guideReturnJob" },
	{ id = "prepare", titleKey = "guidePrepare", action = "Current", actionKey = "guideReturnJob" },
	{ id = "paint", titleKey = "guidePaint", action = "Current", actionKey = "guideReturnJob" },
	{ id = "pay", titleKey = "guidePay", action = "Current", actionKey = "guideReturnJob" },
	{ id = "buy", titleKey = "guideBuy", action = "Shop", actionKey = "shopTitle" },
	{ id = "place", titleKey = "guidePlace", action = "Furniture", actionKey = "furnitureApp" },
}
local ranks: { [string]: number } =
	{ Inspect = 1, Prepare = 2, ChooseMaterial = 2, Painting = 3, Ready = 4 }
local Guide = {}
function Guide.evaluate(f: Facts?): Progress
	local result: Progress = {
		status = if f then (if f.completed then "Done" else "Active") else "Waiting",
		completed = 0,
		total = 7,
		current = nil,
		steps = {},
	}
	if f == nil then
		return result
	end
	local rank = ranks[f.phase] or 0
	for index, definition in definitions do
		local done = f.completed
			or (
				if index <= 5
					then f.paid or index <= rank
					elseif index == 6 then f.paid and f.ownsFurniture
					else false
			)
		local step: Step = {
			id = definition.id,
			titleKey = definition.titleKey,
			detailKey = definition.titleKey .. "Detail",
			action = definition.action,
			actionKey = definition.actionKey,
			done = done,
		}
		table.insert(result.steps, step)
		if done then
			result.completed += 1
		elseif result.current == nil then
			result.current = step.id
		end
	end
	return result
end
return table.freeze(Guide)
