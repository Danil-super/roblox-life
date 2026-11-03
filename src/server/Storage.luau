--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Store = require("./Domain/ProfileStore")

local Storage = {}
-- Explicit local preview. Never fall back to memory after a production load error.
local STUDIO_USE_DATASTORE = false
Storage.preview = RunService:IsStudio() and not STUDIO_USE_DATASTORE
Storage.name = "NeighborhoodFixer_P0_v1"

function Storage.create(): Store.Adapter
	if Storage.preview then
		local records: { [string]: unknown } = {}
		return {
			update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
				local result = transform(records[key])
				if result ~= nil then
					records[key] = result
				end
				return true, result
			end,
		}
	end
	local store = DataStoreService:GetDataStore(Storage.name)
	return {
		update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
			local ok, result = pcall(function(): unknown
				return store:UpdateAsync(
					key,
					function(current: unknown, info: DataStoreKeyInfo?): ...unknown
						local nextValue = transform(current)
						if nextValue == nil then
							return nil
						end
						local owner = tonumber(string.sub(key, 8))
						assert(owner ~= nil, "Expected player:<UserId> key")
						return nextValue, { owner }, if info ~= nil then info:GetMetadata() else {}
					end
				)
			end)
			return ok, result
		end,
	}
end

return Storage
