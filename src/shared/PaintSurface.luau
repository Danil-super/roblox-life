--!strict
local Config = require("./PaintConfig")
local detail = 3
local columns, rows = Config.columns * detail, Config.rows * detail
assert(columns * rows <= 1024, "Paint visual field exceeds its GUI budget")
local Surface = { columns = columns, rows = rows, fadeSeconds = 0.14, predictionLimit = 16 }
-- Cosmetic interpolation only. Count, threshold and acceptance stay on the server grid.
function Surface.build(mask: string): { number }
	local valid = #mask == Config.columns * Config.rows and string.find(mask, "[^01]") == nil
	local coarse: { number } = {}
	for i = 1, Config.columns * Config.rows do
		coarse[i] = if valid and string.byte(mask, i) == 49 then 1 else 0
	end
	local function value(x: number, y: number): number
		return coarse[math.clamp(y, 0, Config.rows - 1) * Config.columns + math.clamp(
			x,
			0,
			Config.columns - 1
		) + 1]
	end
	local result: { number } = {}
	for row = 0, rows - 1 do
		local y = (row + 0.5) / detail - 0.5
		local y0 = math.floor(y)
		local fy = y - y0
		for col = 0, columns - 1 do
			local x = (col + 0.5) / detail - 0.5
			local x0 = math.floor(x)
			local fx = x - x0
			local top = value(x0, y0) * (1 - fx) + value(x0 + 1, y0) * fx
			local bottom = value(x0, y0 + 1) * (1 - fx) + value(x0 + 1, y0 + 1) * fx
			local coverage = top * (1 - fy) + bottom * fy
			local opacity = coverage * coverage * (3 - 2 * coverage)
			table.insert(result, 1 - opacity)
		end
	end
	return result
end
return table.freeze(Surface)
