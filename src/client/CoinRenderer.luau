-- CoinRenderer.luau
-- Visual feedback for coin flips: dramatic launch/tumble/land animation + popup label.
-- Also manages hover highlights via SelectionBox.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.ConfigBase)

local CoinRenderer = {}

local FLIP_HEIGHT   = 9             -- studs the coin rises at peak
local FLIP_TURNS    = 3             -- full 360° tumbles while airborne
local FLIP_DURATION = Config.FLIP_DURATION
local FLIP_DRIFT    = Config.FLIP_DRIFT
local POPUP_TIME    = 0.8           -- seconds popup label is visible

-- Canonical flat orientation: cylinder axis was X, rotated 90° around Z so face is up
local BASE_FLAT = CFrame.Angles(0, 0, math.rad(90))

local _selectionBox: SelectionBox = nil
local _hoveredPart: BasePart?     = nil

local function _makePopup(part: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size         = UDim2.new(0, 80, 0, 30)
	billboard.StudsOffset  = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop  = false
	billboard.Adornee      = part
	billboard.Parent       = part

	local label = Instance.new("TextLabel")
	label.Size            = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text            = text
	label.TextColor3      = color
	label.TextScaled      = true
	label.Font            = Enum.Font.GothamBold
	label.Parent          = billboard

	-- Fade out
	TweenService:Create(label, TweenInfo.new(POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	}):Play()

	task.delay(POPUP_TIME, function()
		billboard:Destroy()
	end)
end

-- Called by CoinManager after a flip resolves.
-- Animates the coin flying up, tumbling FLIP_TURNS times, and landing heads or tails.
-- The coin tumbles around the world X axis so it flips face-to-face in the air.
function CoinRenderer.playFlip(coin, isHeads: boolean)
	local part: BasePart = coin.part
	local originPos = part.Position

	-- Random XZ drift so the coin lands slightly away from where it started
	local angle2D = math.random() * 2 * math.pi
	local driftMag = math.random() * FLIP_DRIFT
	local drift = Vector3.new(math.cos(angle2D) * driftMag, 0, math.sin(angle2D) * driftMag)
	local landPos = originPos + drift

	-- Final resting CFrame: drifted position, flat on board.
	-- Heads: Right face (+X) points up.  Tails: extra π around world X flips the coin
	-- so Left face (-X) points up, showing "T".
	local tailsFlip = isHeads and 0 or math.pi
	local finalCF = CFrame.new(landPos)
		* CFrame.fromAxisAngle(Vector3.xAxis, tailsFlip)
		* BASE_FLAT

	-- Total tumble: FLIP_TURNS full rotations + extra half-turn for tails so the
	-- mid-air animation ends close to the final orientation (minimal snap).
	local totalSpin = FLIP_TURNS * 2 * math.pi + tailsFlip

	local elapsed = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / FLIP_DURATION, 1)

		-- Parabolic height arc
		local height = FLIP_HEIGHT * math.sin(t * math.pi)

		-- Lerp XZ from origin to landing position through the arc
		local pos = originPos:Lerp(landPos, t) + Vector3.new(0, height, 0)

		-- Spin easing: quadratic ease-in then ease-out so it blurs in the middle
		local spinT = t < 0.5
			and (2 * t * t)
			or  (1 - 2 * (1 - t) * (1 - t))
		local angle = spinT * totalSpin

		-- Build CFrame: translate to arc position, tumble around world X, then lay flat
		part.CFrame = CFrame.new(pos)
			* CFrame.fromAxisAngle(Vector3.xAxis, angle)
			* BASE_FLAT

		if t >= 1 then
			conn:Disconnect()

			-- Snap to exact final orientation and position
			part.CFrame = finalCF

			if isHeads then
				_makePopup(part, "+" .. tostring(Config.BASE_PAYOUT), Color3.fromRGB(80, 220, 80))
			else
				_makePopup(part, "miss", Color3.fromRGB(200, 80, 80))
			end
		end
	end)
end

-- Hover highlight — called from InputController
function CoinRenderer.setHover(part: BasePart?)
	if part == _hoveredPart then return end
	_hoveredPart = part
	_selectionBox.Adornee = part
end

function CoinRenderer.init()
	_selectionBox = Instance.new("SelectionBox")
	_selectionBox.Color3        = Color3.fromRGB(255, 255, 100)
	_selectionBox.LineThickness = 0.04
	_selectionBox.SurfaceTransparency = 0.8
	_selectionBox.SurfaceColor3 = Color3.fromRGB(255, 255, 100)
	_selectionBox.Parent        = Workspace
end

return CoinRenderer
