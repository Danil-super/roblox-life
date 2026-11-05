--!strict
local Finish = require("../src/shared/PaintFinish")
local function mask(count: number, total: number): string
	return string.rep("1", count) .. string.rep("0", total - count)
end
assert(Finish.evaluate(nil) == nil, "Legacy receipt invented a grade")
for _, count in { 0, 77, 91, 92, 95, 96 } do
	local f = { columns = 12, rows = 8, masks = { mask(count, 96) } }
	local result = Finish.evaluate(f)
	assert(result and result.percent == math.floor(count * 100 / 96), "Wrong confirmed coverage")
	assert(
		result.grade
			== (if count == 96 then "perfect" elseif count >= 92 then "excellent" else "accepted"),
		"Wrong quality threshold"
	)
	local preview = Finish.preview(f)
	assert(preview and preview.masks[1] == f.masks[1], "P0 preview changed its real mask")
end
local duo = Finish.evaluate({ columns = 12, rows = 8, masks = { mask(77, 96), mask(96, 96) } })
assert(duo and duo.percent == 80 and duo.grade == "accepted", "Better wall hid weaker wall")
local reverse = Finish.evaluate({ columns = 12, rows = 8, masks = { mask(96, 96), mask(77, 96) } })
assert(reverse and reverse.percent == duo.percent, "Wall order changed grade")
for _, bad in
	{
		{ columns = 0, rows = 8, masks = { "" } },
		{ columns = 12, rows = 8, masks = {} },
		{ columns = 12, rows = 8, masks = { "1" } },
		{ columns = 1, rows = 1, masks = { "x" } },
		{ columns = 1, rows = 1, masks = { "1", "1", "1" } },
		{ columns = 0 / 0, rows = 1, masks = { "1" } },
	}
do
	assert(Finish.evaluate(bad) == nil and Finish.preview(bad) == nil, "Malformed finish projected")
end
local large = { columns = 64, rows = 64, masks = { mask(4096, 4096) } }
local compact = Finish.preview(large)
assert(
	compact and compact.columns == 12 and compact.rows == 8 and #compact.masks[1] == 96,
	"Preview budget unbounded"
)
large.masks[1] = "0" .. string.rep("1", 4095)
local hole = Finish.preview(large)
assert(hole and hole.masks[1]:sub(1, 1) == "0", "Preview painted over a confirmed hole")
assert(compact.masks[1] == string.rep("1", 96), "Previews share mutable masks")
print(
	"PaintFinish: thresholds, worst wall, legacy, invalid data, bounded preview and no invented coverage passed"
)
