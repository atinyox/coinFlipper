-- DataManager.luau
-- Server-side only. Handles:
--   1. Loading player data from DataStore on join → fires DataLoaded to client
--   2. Saving player data from client SaveData events (rate-limited)
--   3. GetServerInfo RemoteFunction → returns player list + friend status
-- This is the ONLY server-side gameplay module.

local Players        = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Shared   = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes  = require(Shared.Remotes)
local Config   = require(Shared.Config)

local DataManager = {}

local _storeOk, _store = pcall(function()
	return DataStoreService:GetDataStore("CoinFlipperData_v1")
end)
if not _storeOk then
	warn("[DataManager] DataStore unavailable (local play mode) — data will not persist")
	_store = nil
end
local _lastSave: {[number]: number} = {}  -- [userId] = tick()

local function _defaultData()
	return { money = 0, upgrades = {} }
end

local function _loadData(player: Player)
	if not _store then return _defaultData() end
	local ok, result = pcall(function()
		return _store:GetAsync(tostring(player.UserId))
	end)
	if ok and result then
		-- Ensure both keys exist in case of partial saves
		result.money    = result.money    or 0
		result.upgrades = result.upgrades or {}
		return result
	end
	return _defaultData()
end

local function _saveData(player: Player, data: {money: number, upgrades: {[string]: number}})
	if not _store then return end
	local ok, err = pcall(function()
		_store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("[DataManager] Save failed for", player.Name, ":", err)
	end
end

local function _onPlayerAdded(player: Player)
	_lastSave[player.UserId] = 0
	local data = _loadData(player)
	-- Wait a moment for client scripts to initialize before firing
	task.delay(1, function()
		if player.Parent then
			Remotes.DataLoaded:FireClient(player, data)
		end
	end)
end

local function _onPlayerRemoving(player: Player)
	-- Final save is triggered by the client firing SaveData just before leave,
	-- but we keep the entry until after the event is processed.
	_lastSave[player.UserId] = nil
end

function DataManager.init()
	Remotes.init()

	-- GetServerInfo: returns other players in server and friend status
	Remotes.GetServerInfo.OnServerInvoke = function(requestingPlayer: Player)
		local result = {}
		for _, player in Players:GetPlayers() do
			if player == requestingPlayer then continue end
			local isFriend = false
			local ok, friendResult = pcall(function()
				return requestingPlayer:IsFriendsWith(player.UserId)
			end)
			if ok then isFriend = friendResult end
			table.insert(result, {
				name     = player.DisplayName,
				userId   = player.UserId,
				isFriend = isFriend,
			})
		end
		return result
	end

	-- SaveData: client sends current state; rate-limited per player
	Remotes.SaveData.OnServerEvent:Connect(function(player: Player, data)
		-- Basic validation
		if type(data) ~= "table" then return end
		if type(data.money) ~= "number" then return end
		if type(data.upgrades) ~= "table" then return end

		local now = tick()
		if now - (_lastSave[player.UserId] or 0) < Config.SAVE_DEBOUNCE then return end
		_lastSave[player.UserId] = now

		_saveData(player, { money = data.money, upgrades = data.upgrades })
	end)

	Players.PlayerAdded:Connect(_onPlayerAdded)
	Players.PlayerRemoving:Connect(_onPlayerRemoving)

	-- Handle players already in server when script runs
	for _, player in Players:GetPlayers() do
		task.spawn(_onPlayerAdded, player)
	end
end

return DataManager
