--!strict
-- P0 hypotheses, tune after PC/touch playtests. Rewards remain server-only.
local config = {
	columns = 12,
	rows = 8,
	threshold = 0.8,
	minSeconds = 12,
	maxPoints = 12,
	packetInterval = 0.08,
	sendInterval = 0.12,
	maxSegment = 0.35,
	rollerRadius = 0.65,
	areaPerSecond = 8,
	areaBurst = 12,
	colorId = "warm-white",
	color = { 0.87, 0.82, 0.67 },
	wallId = "wall-a",
	maxDistance = 12,
}
table.freeze(config)
return config
