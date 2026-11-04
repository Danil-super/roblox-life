--!strict
export type Facts = {
	ownerId: number,
	actorId: number,
	available: boolean,
	alive: boolean,
	inside: boolean,
	owned: boolean,
	placed: boolean,
	visible: boolean,
	distance: number,
	catalogId: string,
}
local Use = {}
function Use.allowed(f: Facts): boolean
	return f.ownerId == f.actorId
		and f.available
		and f.alive
		and f.inside
		and f.owned
		and f.placed
		and f.visible
		and f.catalogId == "floor-lamp-v1"
		and f.distance == f.distance
		and f.distance >= 0
		and f.distance <= 8
end
return table.freeze(Use)
