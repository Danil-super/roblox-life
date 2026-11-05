--!strict
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
local Furniture = {}
export type Pose = { x: number, z: number, rotationY: number }
type Box = { x: number, z: number, w: number, d: number, angle: number }
local fixed: { Box & { id: string, labelKey: string? } } = {
	{ id = "Bed", x = -10, z = -6, w = 5, d = 7, angle = 0 },
	{ id = "Desk", x = 10, z = -8, w = 6, d = 3, angle = 0 },
	{ id = "Chair", x = 10, z = -4.5, w = 2.5, d = 2.5, angle = 0 },
	{ id = "Passage", labelKey = "buildPassage", x = 0, z = 5.5, w = 5, d = 13, angle = 0 },
	{ id = "Spawn", labelKey = "buildSpawn", x = 0, z = 0, w = 6, d = 6, angle = 0 },
}
for _, region in fixed do
	table.freeze(region)
end
local Layout = table.freeze({ halfWidth = 15.3, halfDepth = 11.3, fixed = table.freeze(fixed) })
Furniture.layout = Layout
local MAX = 9007199254740991
local function finite(n: unknown): boolean
	return type(n) == "number" and n == n and math.abs(n) <= 10000
end
function Furniture.pose(raw: unknown): Pose?
	if type(raw) ~= "table" then
		return nil
	end
	local p = raw :: { [string]: unknown }
	for key in next, p do
		if key ~= "x" and key ~= "z" and key ~= "rotationY" and key ~= "mode" then
			return nil
		end
	end
	if
		not finite(p.x)
		or not finite(p.z)
		or not finite(p.rotationY)
		or (p.mode ~= "Grid" and p.mode ~= "Free")
	then
		return nil
	end
	local step = if p.mode == "Grid" then 1 else 0.1
	local angle = if p.mode == "Grid" then 90 else 15
	return {
		x = math.round((p.x :: number) / step) * step,
		z = math.round((p.z :: number) / step) * step,
		rotationY = (math.round((p.rotationY :: number) / angle) * angle) % 360,
	}
end
local function radius(box: Box, x: number, z: number): number
	local a = math.rad(box.angle)
	local c, s = math.cos(a), math.sin(a)
	return math.abs(x * c - z * s) * box.w / 2 + math.abs(x * s + z * c) * box.d / 2
end
local function overlaps(a: Box, b: Box): boolean
	for _, angle in { a.angle, a.angle + 90, b.angle, b.angle + 90 } do
		local rad = math.rad(angle)
		local x, z = math.cos(rad), -math.sin(rad)
		local separation = math.abs((a.x - b.x) * x + (a.z - b.z) * z)
		local reach = radius(a, x, z) + radius(b, x, z) + 0.15
		if separation >= reach then
			return false
		end
	end
	return true
end
function Furniture.validate(
	p: Profile.Profile,
	id: string,
	raw: unknown,
	revision: number
): (Pose?, string?)
	local item = p.inventory[id]
	if not Profile.identifier(id) or item == nil then
		return nil, "NotOwned"
	end
	local spec = Config.catalog[item.catalogItemId]
	if spec == nil or spec.modelVersion ~= item.modelVersion then
		return nil, "UnknownProduct"
	end
	if
		p.housing.roomTemplateId ~= "StarterDormTemplate_v1"
		or p.housing.roomTemplateVersion ~= 1
	then
		return nil, "RoomVersion"
	end
	if not Profile.integer(revision, 0, MAX) then
		return nil, "StaleRevision"
	end
	local pose = Furniture.pose(raw)
	if pose == nil then
		return nil, "InvalidPose"
	end
	for placedId, placed in p.housing.placements do
		local owned = p.inventory[placedId]
		local product = if owned then Config.catalog[owned.catalogItemId] else nil
		if placed.y ~= 0 or placed.roomTemplateVersion ~= 1 then
			return nil, "RoomVersion"
		end
		if owned == nil or product == nil or owned.modelVersion ~= product.modelVersion then
			return nil, "UnknownProduct"
		end
	end
	local old = p.housing.placements[id]
	local same = old ~= nil
		and old.x == pose.x
		and old.z == pose.z
		and old.rotationY == pose.rotationY
	if revision ~= p.housing.revision and not same then
		return nil, "StaleRevision"
	end
	local box: Box =
		{ x = pose.x, z = pose.z, w = spec.width, d = spec.depth, angle = pose.rotationY }
	if
		math.abs(box.x) + radius(box, 1, 0) > Layout.halfWidth
		or math.abs(box.z) + radius(box, 0, 1) > Layout.halfDepth
	then
		return nil, "Bounds"
	end
	for _, obstacle in Layout.fixed do
		if overlaps(box, obstacle) then
			return nil, "Blocked"
		end
	end
	for otherId, placed in p.housing.placements do
		if otherId ~= id then
			local owned = p.inventory[otherId]
			local product = if owned then Config.catalog[owned.catalogItemId] else nil
			if product == nil then
				return nil, "UnknownProduct"
			end
			local obstacle: Box = {
				x = placed.x,
				z = placed.z,
				w = product.width,
				d = product.depth,
				angle = placed.rotationY,
			}
			if overlaps(box, obstacle) then
				return nil, "Collision"
			end
		end
	end
	return pose, nil
end
function Furniture.place(
	p: Profile.Profile,
	id: string,
	raw: unknown,
	revision: number
): (boolean, string?)
	local pose, reason = Furniture.validate(p, id, raw, revision)
	if pose == nil then
		return false, reason
	end
	local old = p.housing.placements[id]
	if old and old.x == pose.x and old.z == pose.z and old.rotationY == pose.rotationY then
		return true, nil
	end
	if p.revision >= MAX or p.housing.revision >= MAX then
		return false, "LimitReached"
	end
	p.housing.placements[id] =
		{ x = pose.x, y = 0, z = pose.z, rotationY = pose.rotationY, roomTemplateVersion = 1 }
	p.housing.revision += 1
	p.revision += 1
	if not p.onboarding.completed and p.jobs.completedCount > 0 then
		p.onboarding.step = "DONE"
		p.onboarding.completed = true
	end
	return true, nil
end
function Furniture.store(p: Profile.Profile, id: string, revision: number): (boolean, string?)
	if not Profile.identifier(id) or p.inventory[id] == nil then
		return false, "NotOwned"
	end
	if not Profile.integer(revision, 0, MAX) then
		return false, "StaleRevision"
	end
	if p.housing.placements[id] == nil then
		return true, nil
	end
	if revision ~= p.housing.revision then
		return false, "StaleRevision"
	end
	if p.revision >= MAX or p.housing.revision >= MAX then
		return false, "LimitReached"
	end
	p.housing.placements[id] = nil
	p.housing.revision += 1
	p.revision += 1
	return true, nil
end
return Furniture
