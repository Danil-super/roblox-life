--!strict
local Types = require("./JobTypes")
local Config = require("./PaintConfig")
local View = require("./PaintView")
local Plan = {}
export type Status = "Done" | "Current" | "Next"
export type Progress = {
	current: number,
	states: { Status },
	surfaceIndex: number,
	surfaceTotal: number,
	noteKey: string,
	percent: number?,
}
local phases: { [string]: number? } =
	{ Inspect = 1, Prepare = 2, ChooseMaterial = 3, Painting = 4, SurfaceReady = 0, Ready = 5 }
local notes = {
	Inspect = "meetClientHint",
	Prepare = "prepareHint",
	ChooseMaterial = "colorHint",
	Painting = "workPlanPaintHint",
	SurfaceReady = "workPlanNextHint",
	Ready = "handoverClientHint",
}
function Plan.evaluate(s: Types.Snapshot?, ready: boolean): Progress?
	if not s or not ready or not s.available or s.jobId == "" or s.workId == "" then
		return nil
	end
	local current = phases[s.phase]
	if current == nil then
		return nil
	end
	local index, total = s.surfaceIndex or 1, s.surfaceTotal or 1
	if (total ~= 1 and total ~= 2) or index % 1 ~= 0 or index < 1 or index > total then
		return nil
	end
	if
		(s.phase == "Ready" and index ~= total) or (s.phase == "SurfaceReady" and index >= total)
	then
		return nil
	end
	local states: { Status } = {}
	for step = 1, 5 do
		states[step] = if step < (if current == 0 then 5 else current)
			then "Done"
			elseif step == current then "Current"
			else "Next"
	end
	local coverage = View.progress(s.count, Config.columns * Config.rows, Config.threshold)
	return {
		current = current,
		states = states,
		surfaceIndex = index,
		surfaceTotal = total,
		noteKey = if s.phase == "Painting" and coverage.covered
			then "workPlanReviewHint"
			else notes[s.phase],
		percent = if s.phase == "Painting" then coverage.percent else nil,
	}
end
return table.freeze(Plan)
