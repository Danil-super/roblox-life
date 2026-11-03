--!strict
local RouteMath = {}
function RouteMath.bearing(dx: number, dz: number, lookX: number, lookZ: number): number
	return math.deg(math.atan2(lookX * dz - lookZ * dx, lookX * dx + lookZ * dz))
end
return table.freeze(RouteMath)
