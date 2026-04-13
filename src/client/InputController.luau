-- InputController.luau
-- Handles all player click input via raycasting.
-- Routes clicks to CoinManager (flip) or MeepleManager (wake).
-- Also drives CoinRenderer hover highlights.

local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local InputController = {}

local _CoinManager   = nil
local _MeepleManager = nil
local _CoinRenderer  = nil

local _camera: Camera = workspace.CurrentCamera
local _lastHovered: BasePart? = nil

local function _raycastMouse(): RaycastResult?
	local mousePos = UserInputService:GetMouseLocation()
	local ray      = _camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params   = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.CurrentCamera }
	return workspace:Raycast(ray.Origin, ray.Direction * 200, params)
end

-- Hover updates every frame for highlight feedback
local function _onRenderStepped()
	local result = _raycastMouse()
	local hit = result and result.Instance

	if hit and CollectionService:HasTag(hit, "Coin") then
		if hit ~= _lastHovered then
			_lastHovered = hit
			_CoinRenderer.setHover(hit)
		end
	else
		if _lastHovered then
			_lastHovered = nil
			_CoinRenderer.setHover(nil)
		end
	end
end

local function _onClick()
	local result = _raycastMouse()
	if not result then return end

	local hit = result.Instance

	if CollectionService:HasTag(hit, "Coin") then
		-- Extract coin id from part name "Coin_N"
		local idStr = hit.Name:match("Coin_(%d+)")
		if idStr then
			_CoinManager.flipCoin(tonumber(idStr))
		end

	elseif CollectionService:HasTag(hit, "Meeple") then
		local meeple = _MeepleManager.getMeepleByPart(hit)
		if meeple and meeple.state == "TIRED" then
			_MeepleManager.wakeMeeple(meeple.id)
		end
	end
end

function InputController.init(coinManager, meepleManager, coinRenderer)
	_CoinManager   = coinManager
	_MeepleManager = meepleManager
	_CoinRenderer  = coinRenderer

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_onClick()
		end
	end)

	RunService.RenderStepped:Connect(_onRenderStepped)
end

return InputController
