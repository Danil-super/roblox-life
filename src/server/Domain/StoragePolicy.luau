--!strict
export type Config = { enabled: boolean, universeId: number, placeId: number }
export type Plan = { preview: boolean, name: string, blocked: string? }
local Policy = {}
local function id(n: number): boolean
	return n == n and n > 0 and n <= 9007199254740991 and n % 1 == 0
end
function Policy.select(studio: boolean, universeId: number, placeId: number, config: Config): Plan
	if not studio then
		return { preview = false, name = "NeighborhoodFixer_P0_v1" }
	end
	if not config.enabled then
		return { preview = true, name = "StudioMemoryPreview" }
	end
	local blocked: string? = nil
	if not id(config.universeId) or not id(config.placeId) then
		blocked = "CloudTestNotConfigured"
	elseif not id(universeId) or not id(placeId) then
		blocked = "CloudTestUnpublished"
	elseif universeId ~= config.universeId or placeId ~= config.placeId then
		blocked = "CloudTestWrongExperience"
	end
	return { preview = false, name = "NeighborhoodFixer_P0_StudioQA_v1", blocked = blocked }
end
return table.freeze(Policy)
