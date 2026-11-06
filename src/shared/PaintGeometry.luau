--!strict
export type Size = { width: number, height: number }
local layouts: { [string]: { Size } } = {
	["paint-tutorial-v1"] = { { width = 12, height = 8 } },
	["paint-room-v1"] = { { width = 12, height = 8 } },
	["paint-mint-v1"] = { { width = 8, height = 8 } },
	["paint-rose-v1"] = { { width = 8, height = 9 } },
	["paint-duo-v1"] = { { width = 16, height = 8 }, { width = 8, height = 8 } },
	["paint-sunroom-v1"] = { { width = 16, height = 6 }, { width = 10, height = 8 } },
	["paint-atelier-v1"] = { { width = 8, height = 9 }, { width = 16, height = 6 } },
}
for _, layout in layouts do
	for _, size in layout do
		table.freeze(size)
	end
	table.freeze(layout)
end
table.freeze(layouts)
local Geometry = {}
function Geometry.layout(templateId: string?): { Size }?
	return if templateId then layouts[templateId] else nil
end
return table.freeze(Geometry)
