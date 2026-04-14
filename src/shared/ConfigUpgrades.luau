-- UpgradeDefinitions.luau
-- Each upgrade is keyed by its matching ConfigBase key name.
-- The array part holds per-level entries (index = level).
-- Every entry has `cost` (price to reach that level) and `value` (what the Config
-- key gets set to). maxLevel is implicit: #upgrade.

export type UpgradeLevel = {
	cost:  number,
	value: number,
}

export type UpgradeDef = {
	name:      string,
	desc:      string,
}

local Upgrades: {[string]: UpgradeDef} = {
	INITIAL_COIN_COUNT = {
		name      = "More Coins",
		desc      = "add coins on the board",
		{ cost = 5,   value = 2 },
		{ cost = 25,   value = 3 },
		{ cost = 75,  value = 4 },
		{ cost = 127,  value = 5 },
		{ cost = 203,  value = 6 },
	},
	MEEPLE_SPEED = {
		name      = "Faster Meeple",
		desc      = "Meeple move faster",
		{ cost = 100, value = 12 },
		{ cost = 150, value = 14 },
		{ cost = 225, value = 17 },
		{ cost = 337, value = 20 },
		{ cost = 506, value = 24 },
	},
	MEEPLE_MAX_ENERGY = {
		name      = "Meeple Stamina",
		desc      = "+5 flips before tiring",
		{ cost = 150, value = 15 },
		{ cost = 225, value = 20 },
		{ cost = 337, value = 25 },
		{ cost = 506, value = 30 },
		{ cost = 759, value = 35 },
	},
	MEEPLE_COUNT = {
		name      = "More Meeple",
		desc      = "Spawn 1 additional meeple",
		{ cost = 10, value = 2 },
		{ cost = 50, value = 3 },
		{ cost = 200, value = 4 },
	},
	MEEPLE_FLIP_PAUSE = {
		name      = "Quick Flip",
		desc      = "Meeple flip coins faster",
		{ cost = 75,  value = 2.9 },
		{ cost = 112, value = 2.8 },
		{ cost = 168, value = 2.7 },
		{ cost = 253, value = 2.6 },
		{ cost = 379, value = 2.5 },
	},
	FLIP_WIN_CHANCE = {
		name      = "Lucky Flip",
		desc      = "+1% heads chance",
		{ cost = 500,  value = 0.51 },
		{ cost = 750,  value = 0.52 },
		{ cost = 1125, value = 0.53 },
	},
	BASE_PAYOUT = {
		name      = "Coin Value",
		desc      = "Each heads pays more",
		{ cost = 100, value = 2 },
		{ cost = 300, value = 3 },
		{ cost = 900, value = 4 },
		{ cost = 1740, value = 5 },
		{ cost = 2703, value = 6 },
	},
}

-- Ordered list for consistent UI rendering
local UpgradeOrder: {string} = {
	"INITIAL_COIN_COUNT",
	"MEEPLE_SPEED",
	"MEEPLE_MAX_ENERGY",
	"MEEPLE_COUNT",
	"MEEPLE_FLIP_PAUSE",
	"FLIP_WIN_CHANCE",
	"BASE_PAYOUT",
}

return {
	defs  = Upgrades,
	order = UpgradeOrder,
}
