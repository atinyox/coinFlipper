-- CoinManager.luau
-- Spawns coin Parts on the board and handles client-side flip logic.
-- Flip results are purely local RNG — no server round-trip.

local Workspace    = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local Shared       = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config       = require(Shared.Config)

local CoinManager = {}

-- Injected after init to avoid circular requires
local _PlayerState = nil
local _CoinRenderer = nil

export type CoinState = {
	id:        number,
	part:      BasePart,
	isHeads:   boolean,
	onCooldown: boolean,
}

local _coins: {[number]: CoinState} = {}
local _nextId = 1

local _board: BasePart = nil

local COIN_RADIUS   = 1.2   -- studs
local COIN_HEIGHT   = 0.25  -- studs (thin cylinder)
local COIN_COLOR_H  = Color3.fromRGB(212, 175, 55)   -- gold
local COIN_COLOR_T  = Color3.fromRGB(160, 130, 40)   -- slightly darker

local function _randomBoardPosition(): Vector3
	local half = Config.BOARD_SIZE.X / 2 - COIN_RADIUS - 0.5
	local x = math.random(-half * 100, half * 100) / 100
	local z = math.random(-half * 100, half * 100) / 100
	local boardTop = _board.Position.Y + Config.BOARD_SIZE.Y / 2
	return Vector3.new(x, boardTop + COIN_HEIGHT / 2, z)
end

local function _spawnCoin(): CoinState
	local id = _nextId
	_nextId += 1

	local part = Instance.new("Part")
	part.Name       = "Coin_" .. id
	part.Shape      = Enum.PartType.Cylinder
	part.Size       = Vector3.new(COIN_HEIGHT, COIN_RADIUS * 2, COIN_RADIUS * 2)
	-- Cylinder's axis is X by default; rotate so flat face is up
	part.CFrame     = CFrame.new(_randomBoardPosition()) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored   = true
	part.CanCollide = false
	part.Color      = COIN_COLOR_H
	part.Material   = Enum.Material.SmoothPlastic
	part.CastShadow = false
	part.Parent     = Workspace

	CollectionService:AddTag(part, "Coin")

	local state: CoinState = {
		id         = id,
		part       = part,
		isHeads    = true,
		onCooldown = false,
	}
	_coins[id] = state
	return state
end

-- Returns list of coin states not currently on cooldown
function CoinManager.getAvailableCoins(): {CoinState}
	local available = {}
	for _, coin in _coins do
		if not coin.onCooldown then
			table.insert(available, coin)
		end
	end
	return available
end

function CoinManager.getCoinById(id: number): CoinState?
	return _coins[id]
end

-- Main flip entry point — called by InputController (player click) or MeepleManager
-- Returns true if flip happened (not on cooldown), false otherwise
function CoinManager.flipCoin(coinId: number): boolean
	local coin = _coins[coinId]
	if not coin or coin.onCooldown then return false end

	coin.onCooldown = true
	-- Effective win chance is read from Config (ShopManager patches it on upgrade)
	local isHeads = math.random() < Config.FLIP_WIN_CHANCE

	coin.isHeads = isHeads

	if isHeads and _PlayerState then
		_PlayerState.addMoney(Config.BASE_PAYOUT)
	end

	if _CoinRenderer then
		task.spawn(_CoinRenderer.playFlip, coin, isHeads)
	end

	-- Release cooldown after configured delay
	task.delay(Config.COIN_COOLDOWN, function()
		if _coins[coinId] then
			_coins[coinId].onCooldown = false
		end
	end)

	return true
end

-- Called by ShopManager when MORE_COINS upgrade is purchased
function CoinManager.spawnExtraCoins(count: number)
	for _ = 1, count do
		_spawnCoin()
	end
end

function CoinManager.init(playerState, coinRenderer)
	_PlayerState  = playerState
	_CoinRenderer = coinRenderer

	_board = Workspace:WaitForChild("Board")

	for _ = 1, Config.INITIAL_COIN_COUNT do
		_spawnCoin()
	end
end

return CoinManager
