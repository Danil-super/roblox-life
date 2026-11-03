--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Store = require("./Domain/ProfileStore")
local Policy = require("./Domain/StoragePolicy")
local ServerStorage = game:GetService("ServerStorage")

local Storage = {}
-- These server-only settings are overridden only in an explicit QA build.
local settings = ServerStorage:WaitForChild("DevelopmentSettings")
local enabled = settings:WaitForChild("StudioDataStoreTest")
local universe = settings:WaitForChild("TestUniverseId")
local place = settings:WaitForChild("TestPlaceId")
assert(
	enabled:IsA("BoolValue") and universe:IsA("IntValue") and place:IsA("IntValue"),
	"Invalid development settings"
)
local config: Policy.Config =
	{ enabled = enabled.Value, universeId = universe.Value, placeId = place.Value }
local plan = Policy.select(RunService:IsStudio(), game.GameId, game.PlaceId, config)
Storage.preview = plan.preview
Storage.name = plan.name
Storage.blocked = plan.blocked

function Storage.create(): Store.Adapter
	local blocked = Storage.blocked
	if blocked then
		return {
			update = function(_key: string, _transform: (unknown) -> unknown): (boolean, unknown)
				return false, blocked
			end,
		}
	end
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
