--!strict
export type Dialogue = {
	speakerKey: string,
	lineKey: string,
	action: string?,
	actionKey: string?,
	gesture: string,
}
local phases: { [string]: { line: string, action: string?, label: string?, gesture: string } } = {
	Inspect = {
		line = "residentWelcome",
		action = "inspect",
		label = "inspectWall",
		gesture = "wave",
	},
	Prepare = {
		line = "residentProtect",
		action = "prepare",
		label = "protectFloor",
		gesture = "point",
	},
	ChooseMaterial = {
		line = "residentColour",
		action = "palette",
		label = "choosePaint",
		gesture = "point",
	},
	Painting = {
		line = "residentWorking",
		action = "paint",
		label = "useRoller",
		gesture = "point",
	},
	Ready = { line = "residentReview", action = "submit", label = "submitJob", gesture = "nod" },
	Completed = { line = "residentThanks", gesture = "wave" },
}
local Dialogue = {}
function Dialogue.describe(speakerKey: string, phase: string): Dialogue?
	local p = phases[phase]
	if p == nil then
		return nil
	end
	return {
		speakerKey = speakerKey,
		lineKey = p.line,
		action = p.action,
		actionKey = p.label,
		gesture = p.gesture,
	}
end
return table.freeze(Dialogue)
