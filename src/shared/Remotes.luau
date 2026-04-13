-- Remotes.luau
-- Central registry for all RemoteEvents and RemoteFunctions.
-- Server creates them; client waits for them.
--
-- Remote inventory:
--   GetServerInfo   RemoteFunction  client→server  {} → {players: [{name, isFriend}]}
--   DataLoaded      RemoteEvent     server→client  {money: number, upgrades: {[string]: number}}
--   SaveData        RemoteEvent     client→server  {money: number, upgrades: {[string]: number}}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local FOLDER_NAME = "CoinFlipperRemotes"

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	else
		return ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
	end
end

local function getOrCreate(className: string, name: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then return existing end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	else
		return folder:WaitForChild(name, 10)
	end
end

function Remotes.init()
	Remotes.GetServerInfo = getOrCreate("RemoteFunction", "GetServerInfo")
	Remotes.DataLoaded    = getOrCreate("RemoteEvent",    "DataLoaded")
	Remotes.SaveData      = getOrCreate("RemoteEvent",    "SaveData")
end

return Remotes
