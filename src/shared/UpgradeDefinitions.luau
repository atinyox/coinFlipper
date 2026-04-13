-- UpgradeDefinitions.luau
-- Catalog of all purchasable upgrades.
-- cost(level) = baseCost * 1.5^level  (level is current level before purchase)
-- ShopUI reads this table to render cards dynamically — no UI changes needed
-- when adding new upgrades here.

export type UpgradeDef = {
	id:       string,
	name:     string,
	desc:     string,
	baseCost: number,
	maxLevel: number,
}

local Upgrades: {[string]: UpgradeDef} = {
	MORE_COINS = {
		id       = "MORE_COINS",
		name     = "More Coins",
		desc     = "+2 coins on the board",
		baseCost = 50,
		maxLevel = 5,
	},
	FASTER_MEEPLE = {
		id       = "FASTER_MEEPLE",
		name     = "Faster Meeple",
		desc     = "Meeple move 20% faster",
		baseCost = 100,
		maxLevel = 5,
	},
	MEEPLE_STAMINA = {
		id       = "MEEPLE_STAMINA",
		name     = "Meeple Stamina",
		desc     = "+5 flips before tiring",
		baseCost = 150,
		maxLevel = 5,
	},
	MORE_MEEPLE = {
		id       = "MORE_MEEPLE",
		name     = "More Meeple",
		desc     = "Spawn 1 additional meeple",
		baseCost = 200,
		maxLevel = 3,
	},
	LUCKY_FLIP = {
		id       = "LUCKY_FLIP",
		name     = "Lucky Flip",
		desc     = "+5% heads chance",
		baseCost = 500,
		maxLevel = 3,
	},
}

-- Ordered list for consistent UI rendering
local UpgradeOrder: {string} = {
	"MORE_COINS",
	"FASTER_MEEPLE",
	"MEEPLE_STAMINA",
	"MORE_MEEPLE",
	"LUCKY_FLIP",
}

return {
	defs  = Upgrades,
	order = UpgradeOrder,
}
