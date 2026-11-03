--!strict
-- P0 test values from GDD §17.4, not final release balance.
local rewards: { [string]: { dollars: number, xp: number, reputation: number } } = {
	["paint-tutorial-v1"] = { dollars = 250, xp = 50, reputation = 1 },
	["paint-room-v1"] = { dollars = 250, xp = 50, reputation = 1 },
	["paint-mint-v1"] = { dollars = 300, xp = 70, reputation = 1 },
	["paint-rose-v1"] = { dollars = 350, xp = 90, reputation = 1 },
}
local contracts: {
	[string]: {
		titleKey: string,
		briefKey: string,
		colorId: string,
		minXP: number,
		offered: boolean,
	},
} =
	{
		["paint-tutorial-v1"] = {
			titleKey = "contractTutorial",
			briefKey = "briefTutorial",
			colorId = "warm-white",
			minXP = 0,
			offered = true,
		},
		["paint-room-v1"] = {
			titleKey = "contractTutorial",
			briefKey = "briefTutorial",
			colorId = "warm-white",
			minXP = 0,
			offered = false,
		},
		["paint-mint-v1"] = {
			titleKey = "contractMint",
			briefKey = "briefMint",
			colorId = "mint",
			minXP = 50,
			offered = true,
		},
		["paint-rose-v1"] = {
			titleKey = "contractRose",
			briefKey = "briefRose",
			colorId = "rose",
			minXP = 120,
			offered = true,
		},
	}
local catalog: {
	[string]: { dollars: number, modelVersion: number, width: number, depth: number, height: number },
} =
	{
		["floor-plant-v1"] = { dollars = 180, modelVersion = 1, width = 2, depth = 2, height = 4 },
		["side-table-v1"] = { dollars = 120, modelVersion = 1, width = 3, depth = 2, height = 2.5 },
		["floor-lamp-v1"] = { dollars = 220, modelVersion = 1, width = 2, depth = 2, height = 6 },
	}
for _, reward in rewards do
	table.freeze(reward)
end
for _, contract in contracts do
	table.freeze(contract)
end
for _, item in catalog do
	table.freeze(item)
end
return table.freeze({
	maxDollars = 1000000000,
	maxItems = 256,
	maxRecentOperations = 64,
	rewards = table.freeze(rewards),
	contracts = table.freeze(contracts),
	catalog = table.freeze(catalog),
})
