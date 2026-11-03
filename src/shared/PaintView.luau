--!strict
local View = {}
-- FieldOfView is vertical. Fit inside the area above the work toolbar.
function View.fit(
	w: number,
	h: number,
	vw: number,
	vh: number,
	top: number,
	bottom: number
): (number, number)
	local distance = math.max(w / math.max(1, vw - 32), h / math.max(1, bottom - top))
		* vh
		/ (2 * math.tan(math.rad(25)))
		* 1.08
	local scale = vh / (2 * distance * math.tan(math.rad(25)))
	return distance, ((top + bottom) / 2 - vh / 2) / scale
end
return table.freeze(View)
