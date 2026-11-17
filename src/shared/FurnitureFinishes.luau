--!strict
type Accent = "Coral" | "Lagoon"
type Variant = { baseId: string, accent: Accent }
type Options = { Coral: string, Lagoon: string }

local options: { [string]: Options } = {
	["floor-plant-v1"] = { Coral = "floor-plant-coral-v1", Lagoon = "floor-plant-lagoon-v1" },
	["reading-chair-v1"] = { Coral = "reading-chair-coral-v1", Lagoon = "reading-chair-lagoon-v1" },
	["cozy-sofa-v1"] = { Coral = "cozy-sofa-coral-v1", Lagoon = "cozy-sofa-lagoon-v1" },
}
local variants: { [string]: Variant } = {}
for baseId, pair in options do
	table.freeze(pair)
	local coral: Variant = { baseId = baseId, accent = "Coral" }
	local lagoon: Variant = { baseId = baseId, accent = "Lagoon" }
	variants[pair.Coral], variants[pair.Lagoon] = coral, lagoon
	table.freeze(coral)
	table.freeze(lagoon)
end

local Finishes = {
	options = table.freeze(options),
	variants = table.freeze(variants),
	colors = table.freeze({
		Coral = table.freeze({ 221, 128, 110 }),
		Lagoon = table.freeze({ 66, 166, 158 }),
	}),
}

function Finishes.baseId(id: string): string
	local variant = variants[id]
	return if variant then variant.baseId else id
end

return table.freeze(Finishes)
