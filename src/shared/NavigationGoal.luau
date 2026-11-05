--!strict
export type Goal = {
	key: string,
	kind: "Job" | "Shop",
	destination: { number },
	labelKey: string,
	areaKey: string,
	available: boolean,
	near: boolean,
}
export type Job = {
	available: boolean,
	phase: string,
	jobId: string,
	workId: string,
	destination: { number }?,
	clientKey: string?,
}
export type Shop = { available: boolean, nearShop: boolean }
local Goal = {}
function Goal.job(s: Job?, near: boolean): Goal?
	if s == nil or s.destination == nil or s.phase == "Offer" or s.phase == "Completed" then
		return nil
	end
	local meeting = s.phase == "Inspect" or s.phase == "Ready"
	return {
		key = s.jobId .. ":" .. s.workId,
		kind = "Job",
		destination = s.destination,
		labelKey = if meeting then s.clientKey or "clientResident" else "workWall",
		areaKey = "clientApartment",
		available = s.available,
		near = near,
	}
end
function Goal.shop(active: boolean, s: Shop?, destination: { number }): Goal?
	if not active then
		return nil
	end
	return {
		key = "shop",
		kind = "Shop",
		destination = destination,
		labelKey = "shopTitle",
		areaKey = "shopTitle",
		available = s ~= nil and s.available,
		near = s ~= nil and s.nearShop,
	}
end
return table.freeze(Goal)
