-- PlayerState.luau
-- Client-side single source of truth for money and upgrade levels.
-- Other modules call addMoney / spendMoney / setUpgradeLevel.
-- Subscribe to the `changed` BindableEvent to react to updates (HUD, ShopUI).

local PlayerState = {}

local _money: number = 0
local _upgrades: {[string]: number} = {}

local _changed = Instance.new("BindableEvent")
PlayerState.changed = _changed.Event  -- fire signature: ()

local function _notify()
	_changed:Fire()
end

function PlayerState.getMoney(): number
	return _money
end

function PlayerState.addMoney(amount: number)
	_money = _money + amount
	_notify()
end

-- Returns true if successful, false if insufficient funds
function PlayerState.spendMoney(amount: number): boolean
	if _money < amount then return false end
	_money = _money - amount
	_notify()
	return true
end

function PlayerState.getUpgradeLevel(id: string): number
	return _upgrades[id] or 0
end

function PlayerState.setUpgradeLevel(id: string, level: number)
	_upgrades[id] = level
	_notify()
end

function PlayerState.incrementUpgrade(id: string): number
	local next = (_upgrades[id] or 0) + 1
	_upgrades[id] = next
	_notify()
	return next
end

-- Returns a snapshot suitable for serialization / saving
function PlayerState.serialize(): {money: number, upgrades: {[string]: number}}
	local upgradesCopy = {}
	for k, v in _upgrades do
		upgradesCopy[k] = v
	end
	return { money = _money, upgrades = upgradesCopy }
end

-- Called by init.client once DataLoaded fires
function PlayerState.load(data: {money: number, upgrades: {[string]: number}})
	_money    = data.money    or 0
	_upgrades = data.upgrades or {}
	_notify()
end

return PlayerState
