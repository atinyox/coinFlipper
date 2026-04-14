-- init.client.luau
-- Client entry point.
-- Boot order:
--   1. Remotes (creates/finds remote instances)
--   2. PlayerState (wait for DataLoaded from server)
--   3. CoinRenderer (needs to exist before CoinManager)
--   4. CoinManager (spawns coins, needs CoinRenderer + PlayerState)
--   5. MeepleManager (needs CoinManager + PlayerState)
--   6. InputController (needs CoinManager + MeepleManager + CoinRenderer)
--   7. ShopManager (needs PlayerState + CoinManager + MeepleManager)
--   8. ShopUI (needs PlayerState + ShopManager)
--   9. HUD (needs PlayerState)
--  10. Camera lock (RenderStepped)

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local Client  = script
local Shared  = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config       = require(Shared.ConfigBase)
local Remotes      = require(Shared.Remotes)
local PlayerState  = require(Client.PlayerState)
local CoinRenderer = require(Client.CoinRenderer)
local CoinManager  = require(Client.CoinManager)
local MeepleManager= require(Client.MeepleManager)
local InputController = require(Client.InputController)
local ShopManager  = require(Client.ShopManager)
local ShopUI       = require(Client.ShopUI)
local HUD          = require(Client.HUD)

-- ── Camera setup ──────────────────────────────────────────────────────────────
local camera = workspace.CurrentCamera

if not Config.FREE_CAMERA then
	camera.CameraType = Enum.CameraType.Scriptable

	local function _updateCamera()
		local angleRad   = math.rad(Config.CAMERA_ANGLE)  -- tilt from vertical
		local height     = Config.CAMERA_HEIGHT
		-- Offset: tilt backward along Z axis
		local zOffset    = height * math.tan(angleRad)
		local camPos     = Vector3.new(0, height, zOffset)
		local lookTarget = Vector3.new(0, 0, 0)  -- board center
		camera.CFrame    = CFrame.lookAt(camPos, lookTarget)
	end

	RunService.RenderStepped:Connect(_updateCamera)
	_updateCamera()
end

-- ── Fetch player appearance without spawning a character ─────────────────────
-- CharacterAutoLoads is false server-side, so no character ever spawns.
-- We build the meeple model from the player's HumanoidDescription instead.
local localPlayer    = Players.LocalPlayer
local characterModel = nil  -- filled in concurrently below

task.spawn(function()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(localPlayer.UserId)
	end)
	if ok and model then
		characterModel = model
	end
end)

-- ── Boot sequence ─────────────────────────────────────────────────────────────
Remotes.init()

-- Wait for server to send saved data before starting gameplay
local _dataLoaded = false
Remotes.DataLoaded.OnClientEvent:Connect(function(data)
	if _dataLoaded then return end  -- only load once
	_dataLoaded = true
	PlayerState.load(data)
end)

-- Timeout: if server doesn't respond in 5s, start with defaults
task.delay(5, function()
	if not _dataLoaded then
		_dataLoaded = true
		PlayerState.load({ money = 0, upgrades = {} })
	end
end)

-- Wait for data (and give the appearance fetch a moment to complete)
repeat task.wait(0.05) until _dataLoaded

-- Init all systems
CoinRenderer.init()
CoinManager.init(PlayerState, CoinRenderer)
MeepleManager.init(CoinManager, PlayerState, characterModel)
InputController.init(CoinManager, MeepleManager, CoinRenderer)
ShopManager.init(PlayerState, CoinManager, MeepleManager)
ShopUI.init(PlayerState, ShopManager)
HUD.init(PlayerState)

-- Re-apply any upgrades that were loaded from save data
-- (ShopManager applies effects on purchase; on load we replay them)
local UpgradeDefs = require(Shared.ConfigUpgrades)
for _, id in UpgradeDefs.order do
	local level = PlayerState.getUpgradeLevel(id)
	for _ = 1, level do
		-- Re-apply without spending money or saving
		if id == "MORE_COINS" then
			CoinManager.spawnExtraCoins(2)
		elseif id == "FASTER_MEEPLE" then
			Config.MEEPLE_SPEED = Config.MEEPLE_SPEED * 1.2
		elseif id == "MEEPLE_STAMINA" then
			Config.MEEPLE_MAX_ENERGY = Config.MEEPLE_MAX_ENERGY + 5
			MeepleManager.updateMaxEnergy(Config.MEEPLE_MAX_ENERGY)
		elseif id == "MORE_MEEPLE" then
			MeepleManager.spawnExtra(1)
		elseif id == "LUCKY_FLIP" then
			Config.FLIP_WIN_CHANCE = math.min(Config.FLIP_WIN_CHANCE + 0.05, 0.95)
		end
	end
end
