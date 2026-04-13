-- ShopUI.luau
-- Always-visible right-side sidebar showing all upgrades.
-- Reacts to PlayerState.changed to refresh affordability.

local Players     = game:GetService("Players")

local Shared      = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UpgradeDefs = require(Shared.UpgradeDefinitions)

local ShopUI = {}

local _PlayerState  = nil
local _ShopManager  = nil

local _gui: ScreenGui      = nil
local _cards: {[string]: {button: TextButton, costLabel: TextLabel}} = {}

local SIDEBAR_WIDTH  = 220
local CARD_HEIGHT    = 70
local CARD_PAD       = 8
local HEADER_HEIGHT  = 40

local COLOR_BG       = Color3.fromRGB(30, 30, 30)
local COLOR_CARD     = Color3.fromRGB(50, 50, 50)
local COLOR_AFFORD   = Color3.fromRGB(70, 180, 70)
local COLOR_CANT     = Color3.fromRGB(100, 100, 100)
local COLOR_MAXED    = Color3.fromRGB(212, 175, 55)
local COLOR_TEXT     = Color3.fromRGB(240, 240, 240)
local COLOR_DIMTEXT  = Color3.fromRGB(160, 160, 160)

local function _makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number, color: Color3, bold: boolean): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size              = size
	lbl.Position          = pos
	lbl.BackgroundTransparency = 1
	lbl.Text              = text
	lbl.TextColor3        = color
	lbl.TextSize          = fontSize
	lbl.Font              = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lbl.TextXAlignment    = Enum.TextXAlignment.Left
	lbl.TextWrapped       = true
	lbl.Parent            = parent
	return lbl
end

local function _buildSidebar()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name            = "ShopUI"
	gui.ResetOnSpawn    = false
	gui.IgnoreGuiInset  = false
	gui.Parent          = player.PlayerGui

	-- Sidebar frame
	local sidebar = Instance.new("Frame")
	sidebar.Name              = "Sidebar"
	sidebar.Size              = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
	sidebar.Position          = UDim2.new(1, -SIDEBAR_WIDTH, 0, 0)
	sidebar.BackgroundColor3  = COLOR_BG
	sidebar.BorderSizePixel   = 0
	sidebar.Parent            = gui

	-- Header
	local header = Instance.new("Frame")
	header.Size             = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	header.BorderSizePixel  = 0
	header.Parent           = sidebar

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size              = UDim2.fromScale(1, 1)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text              = "UPGRADES"
	headerLabel.TextColor3        = COLOR_TEXT
	headerLabel.TextSize          = 16
	headerLabel.Font              = Enum.Font.GothamBold
	headerLabel.Parent            = header

	-- Scroll frame for cards
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name                  = "Cards"
	scroll.Size                  = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	scroll.Position              = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel       = 0
	scroll.ScrollBarThickness    = 4
	scroll.ScrollBarImageColor3  = Color3.fromRGB(120, 120, 120)
	scroll.CanvasSize            = UDim2.new(0, 0, 0, #UpgradeDefs.order * (CARD_HEIGHT + CARD_PAD) + CARD_PAD)
	scroll.Parent                = sidebar

	-- Upgrade cards
	for i, id in UpgradeDefs.order do
		local def = UpgradeDefs.defs[id]
		local yPos = CARD_PAD + (i - 1) * (CARD_HEIGHT + CARD_PAD)

		local card = Instance.new("Frame")
		card.Name             = id
		card.Size             = UDim2.new(1, -CARD_PAD * 2, 0, CARD_HEIGHT)
		card.Position         = UDim2.new(0, CARD_PAD, 0, yPos)
		card.BackgroundColor3 = COLOR_CARD
		card.BorderSizePixel  = 0
		card.Parent           = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = card

		-- Upgrade name
		_makeLabel(card, def.name,
			UDim2.new(1, -8, 0, 22),
			UDim2.new(0, 8, 0, 4),
			14, COLOR_TEXT, true)

		-- Description
		_makeLabel(card, def.desc,
			UDim2.new(1, -8, 0, 18),
			UDim2.new(0, 8, 0, 24),
			11, COLOR_DIMTEXT, false)

		-- Buy button
		local btn = Instance.new("TextButton")
		btn.Name              = "BuyBtn"
		btn.Size              = UDim2.new(0, 80, 0, 22)
		btn.Position          = UDim2.new(1, -88, 0, CARD_HEIGHT - 28)
		btn.BackgroundColor3  = COLOR_AFFORD
		btn.TextColor3        = COLOR_TEXT
		btn.TextSize          = 12
		btn.Font              = Enum.Font.GothamBold
		btn.Text              = "$0"
		btn.BorderSizePixel   = 0
		btn.Parent            = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = btn

		-- Level indicator
		local levelLbl = _makeLabel(card, "Lv 0/" .. def.maxLevel,
			UDim2.new(0, 80, 0, 18),
			UDim2.new(0, 8, 0, CARD_HEIGHT - 26),
			11, COLOR_DIMTEXT, false)

		_cards[id] = { button = btn, costLabel = btn, levelLabel = levelLbl }

		btn.Activated:Connect(function()
			_ShopManager.purchaseUpgrade(id)
		end)
	end

	_gui = gui
	return scroll
end

local function _refresh()
	for id, card in _cards do
		local def   = UpgradeDefs.defs[id]
		local level = _PlayerState.getUpgradeLevel(id)
		local cost  = _ShopManager.getCost(id)
		local money = _PlayerState.getMoney()

		card.levelLabel.Text = "Lv " .. level .. "/" .. def.maxLevel

		if level >= def.maxLevel then
			card.button.Text             = "MAX"
			card.button.BackgroundColor3 = COLOR_MAXED
			card.button.Active           = false
		elseif money >= cost then
			card.button.Text             = "$" .. cost
			card.button.BackgroundColor3 = COLOR_AFFORD
			card.button.Active           = true
		else
			card.button.Text             = "$" .. cost
			card.button.BackgroundColor3 = COLOR_CANT
			card.button.Active           = false
		end
	end
end

function ShopUI.init(playerState, shopManager)
	_PlayerState = playerState
	_ShopManager = shopManager

	_buildSidebar()
	_refresh()

	_PlayerState.changed:Connect(_refresh)
end

return ShopUI
