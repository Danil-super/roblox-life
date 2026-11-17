--!strict
export type Config = { enabled: boolean, universeId: number, placeId: number, runId: string? }
export type Plan = { preview: boolean, name: string, scope: string, blocked: string? }
local Policy = {}
local function id(n: number): boolean
	return n == n and n > 0 and n <= 9007199254740991 and n % 1 == 0
end
function Policy.select(studio: boolean, universeId: number, placeId: number, config: Config): Plan
	if not studio then
		return { preview = false, name = "NeighborhoodFixer_P0_v1", scope = "global" }
	end
	if not config.enabled then
		return { preview = true, name = "StudioMemoryPreview", scope = "global" }
	end
	local blocked: string? = nil
	local runId = config.runId or ""
	if
		not id(config.universeId)
		or not id(config.placeId)
		or (runId ~= "" and (#runId > 20 or not string.match(runId, "^[a-z0-9][a-z0-9-]*$")))
	then
		blocked = "CloudTestNotConfigured"
	elseif not id(universeId) or not id(placeId) then
		blocked = "CloudTestUnpublished"
	elseif universeId ~= config.universeId or placeId ~= config.placeId then
		blocked = "CloudTestWrongExperience"
	end
	return {
		preview = false,
		name = "NeighborhoodFixer_P0_StudioQA_v1",
		scope = if runId ~= "" and not blocked then "qa-" .. runId else "global",
		blocked = blocked,
	}
end
return table.freeze(Policy)
