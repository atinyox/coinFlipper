-- init.server.luau
-- Server entry point. Boot order: DataManager
-- All other gameplay runs client-side.

game:GetService("Players").CharacterAutoLoads = false

local Server = script

local DataManager = require(Server.DataManager)

DataManager.init()
