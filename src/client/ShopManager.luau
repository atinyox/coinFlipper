-- ShopManager.luau
-- Client-side purchase logic. Validates affordability, updates PlayerState,
-- applies upgrade effects to Config + live managers, then triggers a save.

local Shared           = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config           = require(Shared.ConfigBase)
local UpgradeDefs      = require(Shared.ConfigUpgrades)
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
	local next = def[level + 1]
	if not next then return math.huge end
	return next.cost
end

-- Set the Config key to the level's value, then run any side effects
local function _applyUpgrade(upgradeId: string, newLevel: number)
	local def   = UpgradeDefs.defs[upgradeId]
	local entry = def[newLevel]
	if not entry then return end

	local oldValue  = Config[def.configKey]
	Config[def.configKey] = entry.value

	-- Side effects that live managers need beyond the Config write
	local delta = entry.value - oldValue
	if upgradeId == "MORE_COINS" then
		_CoinManager.spawnExtraCoins(delta)
	elseif upgradeId == "MEEPLE_STAMINA" then
		_MeepleManager.updateMaxEnergy(entry.value)
	elseif upgradeId == "MORE_MEEPLE" then
		_MeepleManager.spawnExtra(delta)
	end
end

-- Returns true on success, false if cannot afford or at max level
function ShopManager.purchaseUpgrade(upgradeId: string): boolean
	local def = UpgradeDefs.defs[upgradeId]
	if not def then return false end

	local level = _PlayerState.getUpgradeLevel(upgradeId)
	if level >= #def then return false end

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
