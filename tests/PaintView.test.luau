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
local before = View.progress(76, 96, 0.8)
assert(
	before.percent == 79 and before.target == 80 and before.remaining == 1 and not before.covered,
	"Rounded percent hid missing coverage"
)
local enough = View.progress(77, 96, 0.8)
assert(
	enough.percent == 80 and enough.remaining == 0 and enough.covered,
	"Exact cell boundary not ready"
)
assert(View.progress(96, 96, 0.8).fill == 1, "Full bar incomplete")
assert(View.progress(0, 96, 0.8).fill == 0, "Empty bar invented progress")
assert(View.progress(0 / 0, 96, 0.8).fill == 0, "Invalid count invented progress")
assert(View.progress(1, 3, 0.5).remaining == 1, "Fractional target rounded down")
print("PaintView: authoritative progress and threshold boundaries passed")
