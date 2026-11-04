--!strict
local View = {}
export type Progress = {
	fill: number,
	percent: number,
	target: number,
	remaining: number,
	covered: boolean,
}
function View.progress(count: number, total: number, threshold: number): Progress
	local confirmed = if count == count and math.abs(count) < math.huge
		then math.clamp(math.floor(count), 0, total)
		else 0
	return {
		fill = confirmed / total,
		percent = math.floor(confirmed / total * 100),
		target = math.ceil(threshold * 100),
		remaining = math.max(0, math.ceil(total * threshold) - confirmed),
		covered = confirmed / total >= threshold,
	}
end
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
