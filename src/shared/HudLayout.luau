--!strict
local Theme = require("./Theme")
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	compact: boolean,
	minimal: boolean,
	hintVisible: boolean,
	wallet: Rect,
	language: Rect,
	home: Rect,
	objective: Rect,
	navigation: Rect,
}
local Layout = {}
function Layout.compute(
	width: number,
	height: number,
	touch: boolean,
	ready: boolean?,
	hints: boolean?,
	homeQuiet: boolean?
): Layout
	local quiet = homeQuiet == true and ready ~= false
	if not touch and quiet then
		return {
			compact = true,
			minimal = false,
			hintVisible = false,
			wallet = { x = 16, y = 12, w = 184, h = 76 },
			language = { x = width - 86, y = 12, w = 70, h = 44 },
			home = { x = width - 104, y = height - 68, w = 88, h = 52 },
			objective = { x = 16, y = height - 116, w = math.min(360, width - 136), h = 100 },
			navigation = { x = 16, y = 100, w = 242, h = 64 },
		}
	end
	if not touch then
		return {
			compact = false,
			minimal = false,
			hintVisible = ready ~= false and hints ~= false,
			wallet = { x = 16, y = 12, w = 184, h = 76 },
			language = { x = width - 86, y = 12, w = 70, h = 44 },
			home = { x = width - 104, y = height - 68, w = 88, h = 52 },
			objective = { x = 16, y = height - 172, w = math.min(520, width - 136), h = 156 },
			navigation = { x = 16, y = 100, w = 242, h = 64 },
		}
	end
	local margin, gap = Theme.margin, Theme.gap
	local compact = (height < 560 or quiet) and ready ~= false
	local landscape = width > height and height < 560 and ready ~= false
	local minimal = landscape and height < 300
	local objectiveWidth = if landscape
		then math.min(440, width - 280)
		else math.min(520, width - margin * 2)
	local objectiveY = if landscape then margin else 88
	local objectiveHeight = if minimal then 60 elseif compact then 100 else 156
	local routeY = objectiveY + objectiveHeight + gap
	return {
		compact = compact,
		minimal = minimal,
		hintVisible = ready ~= false and not compact and hints ~= false,
		wallet = { x = margin, y = margin, w = 116, h = 64 },
		language = { x = width - margin - 44, y = margin, w = 44, h = 44 },
		home = { x = width - margin - 44 - gap - 64, y = margin, w = 64, h = 44 },
		objective = {
			x = (width - objectiveWidth) / 2,
			y = objectiveY,
			w = objectiveWidth,
			h = objectiveHeight,
		},
		navigation = { x = (width - 242) / 2, y = routeY, w = 242, h = 64 },
	}
end
return table.freeze(Layout)
