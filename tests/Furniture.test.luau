--!strict
local Profile = require("../src/server/Domain/Profile")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print("PASS", name)
end
local function profile(): Profile.Profile
	local p = Profile.new(1)
	p.wallet.dollars = 1000
	assert(Economy.purchase(p, "buy-a", "floor-plant-v1", "plant-a", 1), "Purchase failed")
	assert(Economy.purchase(p, "buy-b", "floor-plant-v1", "plant-b", 2), "Purchase failed")
	return p
end
local function pose(x: number, z: number, rotation: number?, mode: string?): { [string]: unknown }
	return { x = x, z = z, rotationY = rotation or 0, mode = mode or "Grid" }
end
test("owned plant commits once in room-local coordinates", function()
	local p = profile()
	local dollars = p.wallet.dollars
	assert(Furniture.place(p, "plant-a", pose(5, 3), 0), "Place failed")
	assert(
		p.housing.placements["plant-a"].x == 5 and p.housing.placements["plant-a"].y == 0,
		"Wrong local pose"
	)
	assert(
		p.housing.revision == 1 and p.wallet.dollars == dollars,
		"Placement changes only housing"
	)
	local revision = p.revision
	assert(Furniture.place(p, "plant-a", pose(5, 3), 0), "Same retry should be harmless")
	assert(p.housing.revision == 1 and p.revision == revision, "Duplicate changed revision")
end)
test("grid and free have separate bounded precision", function()
	local p = profile()
	assert(Furniture.place(p, "plant-a", pose(5.23, 3.27, 91), 0), "Grid place")
	assert(
		p.housing.placements["plant-a"].x == 5 and p.housing.placements["plant-a"].rotationY == 90,
		"Grid snap"
	)
	assert(Furniture.place(p, "plant-a", pose(5.23, 3.27, 29, "Free"), 1), "Free place")
	local a = p.housing.placements["plant-a"]
	assert(
		math.abs(a.x - 5.2) < 0.0001 and math.abs(a.z - 3.3) < 0.0001 and a.rotationY == 30,
		"Free precision"
	)
end)
test("outside walls and mandatory doorway or spawn paths are rejected", function()
	for _, point in { pose(16, 0), pose(0, 12), pose(0, 8), pose(0, 0), pose(15, 0, 45, "Free") } do
		local p = profile()
		assert(not Furniture.place(p, "plant-a", point, 0), "Unsafe position accepted")
		assert(
			p.housing.revision == 0 and next(p.housing.placements) == nil,
			"Rejection mutated housing"
		)
	end
end)
test("fixed bed desk and chair block furniture", function()
	for _, point in { pose(-10, -6), pose(10, -8), pose(10, -4.5, 0, "Free") } do
		assert(not Furniture.place(profile(), "plant-a", point, 0), "Fixed furniture overlaps")
	end
end)
test("oriented footprints reject overlap and permit separated objects", function()
	local p = profile()
	assert(Furniture.place(p, "plant-a", pose(5, 3, 45, "Free"), 0), "First place")
	assert(not Furniture.place(p, "plant-b", pose(6, 3, 45, "Free"), 1), "Rotated overlap accepted")
	assert(Furniture.place(p, "plant-b", pose(9, 3), 1), "Separated item rejected")
	assert(Furniture.place(p, "plant-a", pose(5, 6), 2), "Moving own item treated as collision")
end)
test("stale housing revision cannot overwrite later work", function()
	local p = profile()
	assert(Furniture.place(p, "plant-a", pose(5, 3), 0), "Initial place")
	assert(not Furniture.place(p, "plant-a", pose(5, 6), 0), "Stale write accepted")
	assert(p.housing.placements["plant-a"].z == 3, "Stale write changed pose")
end)
test("unknown item model version and room cannot be placed", function()
	local p = profile()
	assert(not Furniture.place(p, "foreign", pose(5, 3), 0), "Foreign item accepted")
	p.inventory["plant-a"].modelVersion = 2
	assert(not Furniture.place(p, "plant-a", pose(5, 3), 0), "Future model accepted")
	p.inventory["plant-a"].modelVersion = 1
	p.housing.roomTemplateVersion = 2
	assert(not Furniture.place(p, "plant-a", pose(5, 3), 0), "Future room accepted")
end)
test("non-finite numbers malformed pose and revision fail closed", function()
	for _, raw in
		{
			pose(0 / 0, 3),
			pose(5, math.huge),
			pose(5, 3, math.huge),
			pose(5, 3, 0, "hack"),
			{ x = 5, z = 3, rotationY = 0, mode = "Grid", y = 99 },
		}
	do
		assert(not Furniture.place(profile(), "plant-a", raw, 0), "Malformed pose accepted")
	end
	assert(not Furniture.place(profile(), "plant-a", pose(5, 3), 0 / 0), "NaN revision")
end)
test("storing item preserves ownership money and permanent purchase proof", function()
	local p = profile()
	assert(Furniture.place(p, "plant-a", pose(5, 3), 0), "Initial place")
	local balance = p.wallet.dollars
	assert(Furniture.store(p, "plant-a", 1), "Store failed")
	assert(
		p.housing.placements["plant-a"] == nil and p.inventory["plant-a"] ~= nil,
		"Store lost ownership"
	)
	assert(
		p.wallet.dollars == balance
			and (p.inventory["plant-a"] :: Profile.Item).purchaseOperationId == "purchase:buy-a",
		"Store changed money"
	)
	assert(Furniture.store(p, "plant-a", 1), "Repeated store should be harmless")
	assert(p.housing.revision == 2, "Repeated store changed revision")
end)
test("one player's editor does not change another and onboarding completes after a job", function()
	local a, b = profile(), profile()
	a.jobs.completedCount = 1
	a.jobs.issuedSequence = 1
	a.jobs.settledSequence = 1
	assert(Furniture.place(a, "plant-a", pose(5, 3), 0), "Place failed")
	assert(a.onboarding.completed and a.onboarding.step == "DONE", "Onboarding not complete")
	assert(not b.onboarding.completed and next(b.housing.placements) == nil, "Other player changed")
	assert(Profile.decode(a, 1) ~= nil, "Placed profile must remain serializable")
end)
test("persisted placement and neighboring model versions cannot bypass validation", function()
	local p = profile()
	assert(Furniture.place(p, "plant-a", pose(5, 3), 0), "Place")
	p.housing.placements["plant-a"].y = 9
	p.housing.placements["plant-a"].roomTemplateVersion = 2
	assert(
		not Furniture.place(p, "plant-a", pose(5, 3), 0),
		"Unsupported placement acknowledged as no-op"
	)
	p.housing.placements["plant-a"].y = 0
	p.housing.placements["plant-a"].roomTemplateVersion = 1
	p.inventory["plant-a"].modelVersion = 2
	assert(
		not Furniture.place(p, "plant-b", pose(9, 3), 1),
		"Unknown neighboring footprint accepted"
	)
	assert(
		Furniture.store(p, "plant-a", 1),
		"Owner must be able to recover unsupported placement to storage"
	)
end)
test("rectangular table footprint changes wall clearance when rotated", function()
	local p = profile()
	assert(Economy.purchase(p, "buy-table", "side-table-v1", "table-a", 3), "Buy table")
	assert(Furniture.place(p, "table-a", pose(5, 10.2, 0, "Free"), 0), "Unrotated table should fit")
	assert(
		not Furniture.place(p, "table-a", pose(5, 10.2, 90, "Free"), 1),
		"Rotated long edge crosses wall"
	)
	assert(
		Furniture.place(p, "table-a", pose(5, 9, 90, "Free"), 1),
		"Rotated table moved inward should fit"
	)
end)
print(passed .. " furniture tests passed")
