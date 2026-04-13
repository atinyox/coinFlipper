-- HUD.luau
-- Top-left money counter. Reacts to PlayerState.changed.

local Players = game:GetService("Players")

local HUD = {}

local _moneyLabel: TextLabel = nil

local function _buildHUD()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name           = "HUD"
	gui.ResetOnSpawn   = false
	gui.IgnoreGuiInset = false
	gui.Parent         = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size             = UDim2.new(0, 180, 0, 50)
	frame.Position         = UDim2.new(0, 12, 0, 12)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel  = 0
	frame.Parent           = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local icon = Instance.new("TextLabel")
	icon.Size             = UDim2.new(0, 36, 1, 0)
	icon.Position         = UDim2.new(0, 4, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text             = "$"
	icon.TextColor3       = Color3.fromRGB(212, 175, 55)
	icon.TextSize         = 28
	icon.Font             = Enum.Font.GothamBold
	icon.Parent           = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(1, -44, 1, 0)
	lbl.Position          = UDim2.new(0, 40, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = "0"
	lbl.TextColor3        = Color3.fromRGB(240, 240, 240)
	lbl.TextSize          = 22
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextXAlignment    = Enum.TextXAlignment.Left
	lbl.Parent            = frame

	_moneyLabel = lbl
end

local function _refresh(playerState)
	if _moneyLabel then
		local money = playerState.getMoney()
		-- Format large numbers with commas
		local s = tostring(math.floor(money))
		local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if result:sub(1, 1) == "," then result = result:sub(2) end
		_moneyLabel.Text = result
	end
end

function HUD.init(playerState)
	_buildHUD()
	_refresh(playerState)
	playerState.changed:Connect(function()
		_refresh(playerState)
	end)
end

return HUD
