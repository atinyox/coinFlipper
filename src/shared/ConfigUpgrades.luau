-- UpgradeDefinitions.luau
-- Each upgrade is a table whose array part holds per-level entries (index = level).
-- Every entry has `cost` (price to reach that level) and `value` (what the Config
-- key gets set to). maxLevel is implicit: #upgrade.

export type UpgradeLevel = {
	cost:  number,
	value: number,
}

export type UpgradeDef = {
	name:      string,
	desc:      string,
	configKey: string,
}

local Upgrades: {[string]: UpgradeDef} = {
	MORE_COINS = {
		name      = "More Coins",
		desc      = "add coins on the board",
		configKey = "INITIAL_COIN_COUNT",
		{ cost = 50,   value = 2 },
		{ cost = 75,   value = 3 },
		{ cost = 112,  value = 4 },
		{ cost = 168,  value = 5 },
		{ cost = 253,  value = 6 },
	},
	FASTER_MEEPLE = {
		name      = "Faster Meeple",
		desc      = "Meeple move faster",
		configKey = "MEEPLE_SPEED",
		{ cost = 100, value = 12 },
		{ cost = 150, value = 14 },
		{ cost = 225, value = 17 },
		{ cost = 337, value = 20 },
		{ cost = 506, value = 24 },
	},
	MEEPLE_STAMINA = {
		name      = "Meeple Stamina",
		desc      = "+5 flips before tiring",
		configKey = "MEEPLE_MAX_ENERGY",
		{ cost = 150, value = 15 },
		{ cost = 225, value = 20 },
		{ cost = 337, value = 25 },
		{ cost = 506, value = 30 },
		{ cost = 759, value = 35 },
	},
	MORE_MEEPLE = {
		name      = "More Meeple",
		desc      = "Spawn 1 additional meeple",
		configKey = "MEEPLE_COUNT",
		{ cost = 200, value = 3 },
		{ cost = 300, value = 4 },
		{ cost = 450, value = 5 },
	},
	MEEPLE_FLIP_PAUSE = {
		name      = "Quick Flip",
		desc      = "Meeple flip coins faster",
		configKey = "MEEPLE_FLIP_PAUSE",
		{ cost = 75,  value = 2.9 },
		{ cost = 112, value = 2.8 },
		{ cost = 168, value = 2.7 },
		{ cost = 253, value = 2.6 },
		{ cost = 379, value = 2.5 },
	},
	LUCKY_FLIP = {
		name      = "Lucky Flip",
		desc      = "+1% heads chance",
		configKey = "FLIP_WIN_CHANCE",
		{ cost = 500,  value = 0.51 },
		{ cost = 750,  value = 0.52 },
		{ cost = 1125, value = 0.53 },
	},
}

-- Ordered list for consistent UI rendering
local UpgradeOrder: {string} = {
	"MORE_COINS",
	"FASTER_MEEPLE",
	"MEEPLE_STAMINA",
	"MORE_MEEPLE",
	"MEEPLE_FLIP_PAUSE",
	"LUCKY_FLIP",
}

return {
	defs  = Upgrades,
	order = UpgradeOrder,
}
