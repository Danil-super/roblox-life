--!strict
export type Goal = {
	key: string,
	kind: "Job" | "Shop" | "Home",
	roomName: string?,
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
export type Home = { available: boolean, nearHome: boolean, homeName: string, origin: { number } }
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
function Goal.home(active: boolean, s: Home?): Goal?
	if not active or s == nil or s.homeName == "" or #s.origin ~= 3 then
		return nil
	end
	for _, value in s.origin do
		if value ~= value or math.abs(value) >= 1e6 then
			return nil
		end
	end
	return {
		key = "home:" .. s.homeName,
		kind = "Home",
		roomName = s.homeName,
		destination = { s.origin[1], s.origin[2] + 3, s.origin[3] },
		labelKey = "home",
		areaKey = "home",
		available = s.available,
		near = s.nearHome,
	}
end
return table.freeze(Goal)
