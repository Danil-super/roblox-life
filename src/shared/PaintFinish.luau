--!strict
local Config = require("./PaintConfig")
export type Data = { columns: number, rows: number, masks: { string } }
export type Report = { grade: string, percent: number, surfaces: { number } }
local Finish = {}
local function integer(n: number, low: number, high: number): boolean
	return n == n and n >= low and n <= high and n % 1 == 0
end
local function valid(data: Data): boolean
	if
		not integer(data.columns, 1, 64)
		or not integer(data.rows, 1, 64)
		or type(data.masks) ~= "table"
	then
		return false
	end
	local count = 0
	for index, mask in data.masks do
		if
			type(index) ~= "number"
			or not integer(index, 1, #data.masks)
			or type(mask) ~= "string"
			or #mask ~= data.columns * data.rows
			or not string.match(mask, "^[01]+$")
		then
			return false
		end
		count += 1
	end
	return count >= 1 and count <= 2 and count == #data.masks
end
function Finish.evaluate(data: Data?): Report?
	if data == nil or not valid(data) then
		return nil
	end
	local result: Report = { grade = "accepted", percent = 100, surfaces = {} }
	for _, mask in data.masks do
		local _, count = string.gsub(mask, "1", "")
		local percent = math.floor(count * 100 / #mask)
		table.insert(result.surfaces, percent)
		result.percent = math.min(result.percent, percent)
	end
	result.grade = if result.percent == 100
		then "perfect"
		elseif result.percent >= Config.finishExcellentPercent then "excellent"
		else "accepted"
	return result
end
-- A bin is painted only when every source cell is painted; never hide a hole.
function Finish.preview(data: Data?): Data?
	if data == nil or not valid(data) then
		return nil
	end
	local columns, rows = math.min(12, data.columns), math.min(8, data.rows)
	local result: Data = { columns = columns, rows = rows, masks = {} }
	for _, mask in data.masks do
		local pixels: { string } = {}
		for r = 0, rows - 1 do
			for c = 0, columns - 1 do
				local painted = true
				for y = math.floor(r * data.rows / rows), math.floor((r + 1) * data.rows / rows) - 1 do
					for x = math.floor(c * data.columns / columns), math.floor((c + 1) * data.columns / columns) - 1 do
						painted = painted
							and mask:sub(y * data.columns + x + 1, y * data.columns + x + 1)
								== "1"
					end
				end
				table.insert(pixels, if painted then "1" else "0")
			end
		end
		table.insert(result.masks, table.concat(pixels))
	end
	return result
end
return table.freeze(Finish)
