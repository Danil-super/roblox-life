--!strict
export type Item = { id: string, x: number, z: number, yaw: number }
export type Style = { accent: { number }, shirt: { number }, bed: boolean, furniture: { Item } }
local styles: { [string]: Style } = {
	intro = {
		accent = { 0.85, 0.78, 0.63 },
		shirt = { 0.39, 0.52, 0.66 },
		bed = false,
		furniture = {
			{ id = "floor-plant-v1", x = -11, z = -6, yaw = 0 },
			{ id = "side-table-v1", x = 11, z = 0, yaw = 0 },
		},
	},
	mint = {
		accent = { 0.56, 0.73, 0.64 },
		shirt = { 0.58, 0.39, 0.57 },
		bed = false,
		furniture = {
			{ id = "reading-chair-v1", x = -11, z = -3, yaw = 0 },
			{ id = "side-table-v1", x = -11, z = 1, yaw = 0 },
			{ id = "floor-plant-v1", x = 11, z = 1, yaw = 0 },
		},
	},
	rose = {
		accent = { 0.83, 0.63, 0.62 },
		shirt = { 0.35, 0.55, 0.42 },
		bed = true,
		furniture = {
			{ id = "floor-lamp-v1", x = -13, z = 1, yaw = 0 },
			{ id = "bookcase-v1", x = 12, z = 0, yaw = 90 },
		},
	},
}
return table.freeze(styles)
