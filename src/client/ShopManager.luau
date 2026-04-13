-- ShopManager.luau
-- Client-side purchase logic. Validates affordability, updates PlayerState,
-- applies upgrade effects to Config + live managers, then triggers a save.

local Shared           = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config           = require(Shared.Config)
local UpgradeDefs      = require(Shared.UpgradeDefinitions)
local Remotes          = require(Shared.Remotes)

local ShopManager = {}

local _PlayerState   = nil
local _CoinManager   = nil
local _MeepleManager = nil

-- Cost of the next level of an upgrade (current level before purchase)
function ShopManager.getCost(upgradeId: string): number
	local def = UpgradeDefs.defs[upgradeId]
	if not def then return math.huge end
	local level = _PlayerState.getUpgradeLevel(upgradeId)
	return math.floor(def.baseCost * (1.5 ^ level))
end

local function _applyUpgrade(upgradeId: string, newLevel: number)
	if upgradeId == "MORE_COINS" then
		_CoinManager.spawnExtraCoins(2)

	elseif upgradeId == "FASTER_MEEPLE" then
		Config.MEEPLE_SPEED = Config.MEEPLE_SPEED * 1.2

	elseif upgradeId == "MEEPLE_STAMINA" then
		Config.MEEPLE_MAX_ENERGY = Config.MEEPLE_MAX_ENERGY + 5
		_MeepleManager.updateMaxEnergy(Config.MEEPLE_MAX_ENERGY)

	elseif upgradeId == "MORE_MEEPLE" then
		_MeepleManager.spawnExtra(1)

	elseif upgradeId == "LUCKY_FLIP" then
		Config.FLIP_WIN_CHANCE = math.min(Config.FLIP_WIN_CHANCE + 0.05, 0.95)
	end
end

-- Returns true on success, false if cannot afford or at max level
function ShopManager.purchaseUpgrade(upgradeId: string): boolean
	local def = UpgradeDefs.defs[upgradeId]
	if not def then return false end

	local level = _PlayerState.getUpgradeLevel(upgradeId)
	if level >= def.maxLevel then return false end

	local cost = ShopManager.getCost(upgradeId)
	if not _PlayerState.spendMoney(cost) then return false end

	local newLevel = _PlayerState.incrementUpgrade(upgradeId)
	_applyUpgrade(upgradeId, newLevel)

	-- Persist after every purchase
	Remotes.SaveData:FireServer(_PlayerState.serialize())

	return true
end

function ShopManager.init(playerState, coinManager, meepleManager)
	_PlayerState   = playerState
	_CoinManager   = coinManager
	_MeepleManager = meepleManager
end

return ShopManager
