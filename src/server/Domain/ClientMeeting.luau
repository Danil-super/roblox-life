--!strict
export type Facts = {
	ownerId: number,
	actorId: number,
	available: boolean,
	alive: boolean,
	distance: number,
	visible: boolean,
	phase: string,
}
local phases: { [string]: boolean } = {
	Inspect = true,
	Prepare = true,
	ChooseMaterial = true,
	Painting = true,
	SurfaceReady = true,
	Ready = true,
	Completed = true,
}
local Meeting = {}
function Meeting.allowed(f: Facts): boolean
	return f.ownerId == f.actorId
		and f.available
		and f.alive
		and f.visible
		and f.distance == f.distance
		and f.distance >= 0
		and f.distance <= 8
		and phases[f.phase] == true
end
return table.freeze(Meeting)
