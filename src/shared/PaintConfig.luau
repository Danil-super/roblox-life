--!strict
-- P0 hypotheses, tune after PC/touch playtests. Rewards remain server-only.
local palette: { [string]: { number } } = {
	["warm-white"] = { 0.87, 0.82, 0.67 },
	rose = { 0.83, 0.63, 0.62 },
	mint = { 0.56, 0.73, 0.64 },
}
local colorKeys: { [string]: string } =
	{ ["warm-white"] = "warmWhite", rose = "rose", mint = "mint" }
for _, color in palette do
	table.freeze(color)
end
local config = {
	columns = 12,
	rows = 8,
	threshold = 0.8,
	finishExcellentPercent = 95,
	minSeconds = 12,
	maxPoints = 12,
	packetInterval = 0.08,
	sendInterval = 0.12,
	maxSegment = 0.35,
	rollerRadius = 0.65,
	wideRollerRadius = 1.25,
	wideRollerXP = 50,
	edgeAssist = 0.35,
	areaPerSecond = 8,
	areaBurst = 12,
	colorId = "warm-white",
	color = palette["warm-white"],
	palette = table.freeze(palette),
	colorKeys = table.freeze(colorKeys),
	wallId = "wall-a",
	maxDistance = 12,
}
table.freeze(config)
return config
