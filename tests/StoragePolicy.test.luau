--!strict
local Policy = require("../src/server/Domain/StoragePolicy")
local config: Policy.Config = { enabled = false, universeId = 0, placeId = 0 }
local preview = Policy.select(true, 0, 0, config)
assert(preview.preview and preview.blocked == nil, "Default Studio must remain explicit preview")
local live = Policy.select(false, 123, 456, config)
assert(
	not live.preview and live.name == "NeighborhoodFixer_P0_v1" and live.blocked == nil,
	"Production must always use existing namespace"
)
config.enabled = true
assert(
	Policy.select(true, 0, 0, config).blocked == "CloudTestNotConfigured",
	"Unconfigured cloud mode must fail closed"
)
config.universeId = 123
config.placeId = 456
assert(
	Policy.select(true, 0, 0, config).blocked == "CloudTestUnpublished",
	"Local file must not touch a cloud store"
)
assert(
	Policy.select(true, 999, 456, config).blocked == "CloudTestWrongExperience",
	"Wrong universe accepted"
)
assert(
	Policy.select(true, 123, 999, config).blocked == "CloudTestWrongExperience",
	"Wrong place accepted"
)
local cloud = Policy.select(true, 123, 456, config)
assert(
	not cloud.preview and cloud.blocked == nil and cloud.name ~= live.name,
	"Studio QA must use an isolated namespace"
)
config.universeId = 0 / 0
assert(
	Policy.select(true, 123, 456, config).blocked == "CloudTestNotConfigured",
	"NaN test id accepted"
)
config.universeId = 123
config.placeId = math.huge
assert(
	Policy.select(true, 123, 456, config).blocked == "CloudTestNotConfigured",
	"Infinite test id accepted"
)
local stillLive = Policy.select(false, 123, 456, config)
assert(
	stillLive.name == live.name and not stillLive.preview and stillLive.blocked == nil,
	"Studio settings must not alter production"
)
print("StoragePolicy: 10 preview/cloud-isolation scenarios passed")
