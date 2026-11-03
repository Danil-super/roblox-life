--!strict
local View = require("../src/shared/PaintView")
for _, viewport in { { 646, 566 }, { 1920, 1080 }, { 320, 700 }, { 700, 320 }, { 320, 320 } } do
	local width, height = viewport[1], viewport[2]
	local top, bottom = 70, height - 140
	local distance, offset = View.fit(12, 8, width, height, top, bottom)
	local scale = height / (2 * distance * math.tan(math.rad(25)))
	local center = height / 2 + offset * scale
	assert(center - 4 * scale >= top, "Wall top overlaps core UI")
	assert(center + 4 * scale <= bottom, "Wall bottom overlaps toolbar")
	assert(12 * scale <= width - 32, "Wall is clipped horizontally")
end
print("PaintView: 5 work-area framing scenarios passed")
