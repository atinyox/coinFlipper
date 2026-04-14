-- MeepleManager.luau
-- Client-side meeple AI. Each meeple is a simple colored Part with a face
-- decal. Meeple find nearby coins and flip them, tiring after several flips.
-- Players can click tired meeple to wake them.
--
-- FSM per meeple: IDLE → MOVING → FLIPPING → TIRED → (click) → IDLE

local Workspace           = game:GetService("Workspace")
local RunService          = game:GetService("RunService")
local CollectionService   = game:GetService("CollectionService")
local TweenService        = game:GetService("TweenService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared      = ReplicatedStorage:WaitForChild("Shared")
local Config      = require(Shared.ConfigBase)

-- Register KeyframeSequence assets stored in ReplicatedStorage and cache their content IDs
local _animIds: {[string]: string} = {}
local function _registerAnim(name: string)
	local kfs = ReplicatedStorage:FindFirstChild(name)
	if not kfs then return end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
	end)
	if ok then
		_animIds[name] = id
	else
		warn("[MeepleManager] Failed to register " .. name .. ": " .. tostring(id))
	end
end

local _noobDummyTemplate: Model? = ReplicatedStorage:FindFirstChild("Noob") :: Model?

local MeepleManager = {}

local _CoinManager  = nil  -- injected on init
local _PlayerState  = nil  -- injected on init

export type MeepleState = {
	id:        number,
	part:      BasePart,        -- HumanoidRootPart for character meeples, plain Part otherwise
	model:     Model?,          -- set for character-based meeples; nil for plain Part meeples
	label:     BillboardGui,
	energy:    number,
	maxEnergy: number,
	state:     string,          -- "IDLE" | "MOVING" | "FLIPPING" | "TIRED"
	targetCoinId:    number?,
	lastFlippedCoinId: number?,       -- avoid re-flipping the same coin twice in a row
	isFriend:        boolean,
	walkTrack:       AnimationTrack?,
	flipTrack:       AnimationTrack?,
	restTrack:       AnimationTrack?,
	nextTargetTime:  number,          -- earliest tick() when meeple may acquire a new coin
}

local _meeples: {[number]: MeepleState} = {}
local _nextId = 1

local MEEPLE_SIZE  = Vector3.new(1.5, 2, 1.5)
local BOARD_Y_SURF = 1  -- top surface Y of board

-- Loads walk / flip / rest AnimationTracks onto `meeple` asynchronously.
-- Must run after the model is parented so Roblox can create the Animator.
local function _loadAnimationsAsync(humanoid: Humanoid, meeple: MeepleState, isR15: boolean)
	task.spawn(function()
		-- Animator is auto-created for player characters but NOT for cloned models.
		-- Create it explicitly if absent so LoadAnimation works on both paths.
		local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		local function load(id: string, looped: boolean): AnimationTrack?
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			anim:Destroy()
			if ok and track then
				(track :: AnimationTrack).Looped = looped
				return track :: AnimationTrack
			end
			return nil
		end

		local walkId = isR15 and Config.ANIM_R15_WALK or Config.ANIM_R6_WALK
		local flipId = _animIds[if isR15 then "CoinFlipR15" else "CoinFlipR6"]
		local restId = _animIds[if isR15 then "MeepleRestR15" else "MeepleRestR6"]

		meeple.walkTrack = load(walkId, true)
		meeple.flipTrack = load(flipId, false)
		meeple.restTrack = load(restId, true)
	end)
end

local function _makeBillboard(part: BasePart, text: string): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 100, 0, 40)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Adornee     = part
	bb.AlwaysOnTop = false
	bb.Parent      = part

	local label = Instance.new("TextLabel")
	label.Size              = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text              = text
	label.TextColor3        = Color3.fromRGB(255, 255, 255)
	label.TextScaled        = true
	label.Font              = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent            = bb

	return bb
end

local function _spawnMeeple(name: string, isFriend: boolean): MeepleState
	local id = _nextId
	_nextId += 1

	-- Random position on board
	local half = Config.BOARD_SIZE.X / 2 - 1.5
	local x = math.random(-half * 10, half * 10) / 10
	local z = math.random(-half * 10, half * 10) / 10

	-- Use NoobDummy model if available; otherwise fall back to a plain Part
	if _noobDummyTemplate then
		local clone = _noobDummyTemplate:Clone()
		clone.Name = "Meeple_" .. id

		-- Remove scripts
		for _, obj in clone:GetDescendants() do
			if obj:IsA("BaseScript") then obj:Destroy() end
		end

		-- Neuter Humanoid movement but keep it alive so Animator works
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed  = 0
			humanoid.JumpHeight = 0
			humanoid.AutoRotate = false
		end

		-- Disable collisions/shadows; tag all parts
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CastShadow = false
				CollectionService:AddTag(part, "Meeple")
			end
		end

		local hrp: BasePart = clone:FindFirstChild("HumanoidRootPart", true)
			or clone:FindFirstChildWhichIsA("BasePart", true)
		if not hrp then
			clone:Destroy()
			warn("MeepleManager: Noob has no BasePart — falling back to plain meeple")
			return _spawnMeeple(name, isFriend)
		end
		clone.PrimaryPart = hrp
		hrp.Anchored = true

		-- Compute floor-to-HRP offset so feet land on the board surface
		local minY = math.huge
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				minY = math.min(minY, part.Position.Y - part.Size.Y / 2)
			end
		end
		local hrpFloorOffset = hrp.Position.Y - minY

		clone:PivotTo(CFrame.new(x, BOARD_Y_SURF + hrpFloorOffset, z))
		clone.Parent = Workspace

		local label = _makeBillboard(hrp, name)

		local meeple: MeepleState = {
			id             = id,
			part           = hrp,
			model          = clone,
			label          = label,
			energy         = Config.MEEPLE_MAX_ENERGY,
			maxEnergy      = Config.MEEPLE_MAX_ENERGY,
			state          = "IDLE",
			targetCoinId       = nil,
			lastFlippedCoinId  = nil,
			isFriend           = isFriend,
			walkTrack      = nil,
			flipTrack      = nil,
			restTrack      = nil,
			nextTargetTime = 0,
		}
		_meeples[id] = meeple

		-- Load animations after parenting so Animator exists
		if humanoid then
			local isR15 = clone:FindFirstChild("UpperTorso") ~= nil
			_loadAnimationsAsync(humanoid, meeple, isR15)
		end

		return meeple
	end

	-- Fallback: plain colored Part
	local pos  = Vector3.new(x, BOARD_Y_SURF + MEEPLE_SIZE.Y / 2, z)
	local part = Instance.new("Part")
	part.Name     = "Meeple_" .. id
	part.Size     = MEEPLE_SIZE
	part.CFrame   = CFrame.new(pos)
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color    = isFriend
		and Color3.fromRGB(80, 150, 255)
		or  Color3.fromRGB(200, 120, 60)
	part.Parent   = Workspace

	CollectionService:AddTag(part, "Meeple")

	local label = _makeBillboard(part, name)

	local meeple: MeepleState = {
		id              = id,
		part            = part,
		model           = nil,
		label           = label,
		energy          = Config.MEEPLE_MAX_ENERGY,
		maxEnergy       = Config.MEEPLE_MAX_ENERGY,
		state           = "IDLE",
		targetCoinId       = nil,
		lastFlippedCoinId  = nil,
		isFriend           = isFriend,
		walkTrack          = nil,
		flipTrack          = nil,
		restTrack          = nil,
		nextTargetTime     = 0,
	}
	_meeples[id] = meeple
	return meeple
end

-- Spawns a meeple using a cloned player character model as the visual.
local function _spawnCharacterMeeple(name: string, characterModel: Model): MeepleState
	local id = _nextId
	_nextId += 1

	local clone = characterModel:Clone()
	clone.Name = "Meeple_" .. id

	-- Remove scripts (Animate, etc.) — we drive animation manually
	for _, obj in clone:GetDescendants() do
		if obj:IsA("BaseScript") then obj:Destroy() end
	end

	-- Neuter Humanoid movement but keep it alive so Animator works
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed  = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end

	-- Disable collisions/shadows; tag all parts for click detection
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CastShadow = false
			CollectionService:AddTag(part, "Meeple")
		end
	end

	local hrp: BasePart = clone:FindFirstChild("HumanoidRootPart", true)
		or clone:FindFirstChildWhichIsA("BasePart", true)
	assert(hrp, "MeepleManager: character model has no BasePart")
	clone.PrimaryPart = hrp
	-- Only anchor HRP — Motor6D joints hold all other parts relative to it
	hrp.Anchored = true

	-- Compute floor-to-HRP offset so feet land on the board surface
	local minY = math.huge
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			minY = math.min(minY, part.Position.Y - part.Size.Y / 2)
		end
	end
	local hrpFloorOffset = hrp.Position.Y - minY

	-- Random spawn position on board
	local half = Config.BOARD_SIZE.X / 2 - 1.5
	local x = math.random(-half * 10, half * 10) / 10
	local z = math.random(-half * 10, half * 10) / 10
	clone:PivotTo(CFrame.new(x, BOARD_Y_SURF + hrpFloorOffset, z))
	clone.Parent = Workspace

	local label = _makeBillboard(hrp, name)

	local meeple: MeepleState = {
		id             = id,
		part           = hrp,
		model          = clone,
		label          = label,
		energy         = Config.MEEPLE_MAX_ENERGY,
		maxEnergy      = Config.MEEPLE_MAX_ENERGY,
		state          = "IDLE",
		targetCoinId       = nil,
		lastFlippedCoinId  = nil,
		isFriend           = false,
		walkTrack          = nil,
		flipTrack          = nil,
		restTrack          = nil,
		nextTargetTime     = 0,
	}
	_meeples[id] = meeple

	-- Load animations after parenting so Animator exists
	if humanoid then
		local isR15 = clone:FindFirstChild("UpperTorso") ~= nil
		_loadAnimationsAsync(humanoid, meeple, isR15)
	end

	return meeple
end

local _setAwake  -- forward declaration (defined below _setTired)

local function _setTired(meeple: MeepleState)
	meeple.state        = "TIRED"
	meeple.targetCoinId = nil
	if not meeple.model then
		meeple.part.Color = Color3.fromRGB(120, 120, 120)
	end
	if meeple.walkTrack and meeple.walkTrack.IsPlaying then
		meeple.walkTrack:Stop()
	end
	if meeple.restTrack then
		meeple.restTrack:Play()
	end

	-- Auto-wake after rest duration
	task.delay(Config.MEEPLE_REST_DURATION, function()
		if _meeples[meeple.id] and meeple.state == "TIRED" then
			_setAwake(meeple)
		end
	end)

	-- Show Zzz billboard above normal name label
	local zzz = Instance.new("BillboardGui")
	zzz.Name       = "ZzzGui"
	zzz.Size       = UDim2.new(0, 60, 0, 30)
	zzz.StudsOffset = Vector3.new(0, 4, 0)
	zzz.Adornee    = meeple.part
	zzz.AlwaysOnTop = false
	zzz.Parent     = meeple.part

	local zLabel = Instance.new("TextLabel")
	zLabel.Size              = UDim2.fromScale(1, 1)
	zLabel.BackgroundTransparency = 1
	zLabel.Text              = "Zzz"
	zLabel.TextColor3        = Color3.fromRGB(200, 200, 255)
	zLabel.TextScaled        = true
	zLabel.Font              = Enum.Font.GothamBold
	zLabel.Parent            = zzz
end

_setAwake = function(meeple: MeepleState)
	-- Remove Zzz gui
	local zzz = meeple.part:FindFirstChild("ZzzGui")
	if zzz then zzz:Destroy() end

	if meeple.restTrack and meeple.restTrack.IsPlaying then
		meeple.restTrack:Stop()
	end

	meeple.energy = meeple.maxEnergy
	meeple.state  = "IDLE"
	if not meeple.model then
		meeple.part.Color = meeple.isFriend
			and Color3.fromRGB(80, 150, 255)
			or  Color3.fromRGB(200, 120, 60)
	end
end

-- Called by InputController when player clicks a tired meeple
function MeepleManager.wakeMeeple(meepleId: number)
	local meeple = _meeples[meepleId]
	if meeple and meeple.state == "TIRED" then
		_setAwake(meeple)
	end
end

-- Returns the MeepleState whose part (or character model) contains the given BasePart
function MeepleManager.getMeepleByPart(part: BasePart): MeepleState?
	for _, meeple in _meeples do
		if meeple.part == part then return meeple end
		-- For character meeples, any body part should resolve to the meeple
		if meeple.model and part:IsDescendantOf(meeple.model) then
			return meeple
		end
	end
	return nil
end

-- Called by ShopManager when MEEPLE_COUNT or MEEPLE_MAX_ENERGY is upgraded
function MeepleManager.spawnExtra(count: number)
	for _ = 1, count do
		_spawnMeeple("Meeple", false)
	end
end

function MeepleManager.updateMaxEnergy(newMax: number)
	for _, meeple in _meeples do
		meeple.maxEnergy = newMax
		-- Don't change current energy mid-life
	end
end

-- Heartbeat loop: move meeple toward target coin, flip on arrival
local function _tick(dt: number)
	for _, meeple in _meeples do
		if meeple.state == "TIRED" or meeple.state == "FLIPPING" then continue end

		-- Find a target coin if we don't have one (with post-flip cooldown)
		if meeple.state == "IDLE" or meeple.targetCoinId == nil then
			if tick() < meeple.nextTargetTime then continue end

			local available = _CoinManager.getAvailableCoins()
			if #available == 0 then continue end

			-- Pick nearest available coin, avoiding the last flipped coin unless it's the only option
			local nearest, nearestDist = nil, math.huge
			for _, coin in available do
				if coin.id == meeple.lastFlippedCoinId and #available > 1 then continue end
				local dist = (coin.part.Position - meeple.part.Position).Magnitude
				if dist < nearestDist then
					nearest     = coin
					nearestDist = dist
				end
			end

			if nearest then
				meeple.targetCoinId = nearest.id
				meeple.state        = "MOVING"

				-- Immediately face the new target so the meeple doesn't
				-- linger pointing at the last flipped coin
				local faceDir = Vector3.new(
					nearest.part.Position.X - meeple.part.Position.X,
					0,
					nearest.part.Position.Z - meeple.part.Position.Z
				)
				if faceDir.Magnitude > 0.001 then
					faceDir = faceDir.Unit
					local faceCF = CFrame.lookAt(meeple.part.Position, meeple.part.Position + faceDir)
					if meeple.model then
						meeple.model:PivotTo(faceCF)
					else
						meeple.part.CFrame = faceCF
					end
				end
			end
		end

		if meeple.state == "MOVING" and meeple.targetCoinId then
			local coin = _CoinManager.getCoinById(meeple.targetCoinId)
			if not coin then
				meeple.state        = "IDLE"
				meeple.targetCoinId = nil
				continue
			end

			-- If the coin got picked up by cooldown mid-walk, re-target next tick
			if coin.onCooldown then
				meeple.state        = "IDLE"
				meeple.targetCoinId = nil
				continue
			end

			local targetPos = Vector3.new(
				coin.part.Position.X,
				meeple.part.Position.Y,
				coin.part.Position.Z
			)
			local dist = (targetPos - meeple.part.Position).Magnitude

			local speed = Config.MEEPLE_SPEED
			local step  = math.min(speed * dt, dist)

			if dist <= 2.5 then
				-- Arrived — stop slightly outside the coin and flip
				local coinId = meeple.targetCoinId
				meeple.state            = "FLIPPING"
				meeple.targetCoinId     = nil
				meeple.lastFlippedCoinId = coinId
				meeple.nextTargetTime = tick() + Config.MEEPLE_FLIP_PAUSE

				-- Stop walking, play flip animation
				if meeple.walkTrack and meeple.walkTrack.IsPlaying then
					meeple.walkTrack:Stop()
				end
				if meeple.flipTrack then
					meeple.flipTrack:Play()
				end

				local flipped = _CoinManager.flipCoin(coinId)
				if flipped then
					meeple.energy -= 1
				end
				local shouldTire = meeple.energy <= 0

				-- Hold FLIPPING for the coin arc duration, then transition
				task.delay(Config.FLIP_DURATION, function()
					if not _meeples[meeple.id] then return end
					if meeple.flipTrack and meeple.flipTrack.IsPlaying then
						meeple.flipTrack:Stop()
					end
					if shouldTire then
						_setTired(meeple)
					else
						meeple.state = "IDLE"
					end
				end)
			else
				local dir = (targetPos - meeple.part.Position).Unit
				local newPos = meeple.part.Position + dir * step
				local newCFrame = CFrame.lookAt(newPos, newPos + dir)
				if meeple.model then
					meeple.model:PivotTo(newCFrame)
				else
					meeple.part.CFrame = newCFrame
				end
			end
		end

		-- Sync walk animation to movement state
		if meeple.walkTrack then
			if meeple.state == "MOVING" then
				if not meeple.walkTrack.IsPlaying then
					meeple.walkTrack:Play()
				end
			else
				if meeple.walkTrack.IsPlaying then
					meeple.walkTrack:Stop()
				end
			end
		end
	end
end

function MeepleManager.init(coinManager, playerState, playerCharacter: Model?)
	_CoinManager = coinManager
	_PlayerState = playerState

	-- Register KeyframeSequence animations from ReplicatedStorage
	_registerAnim("CoinFlipR6")
	_registerAnim("CoinFlipR15")
	_registerAnim("MeepleRestR6")
	_registerAnim("MeepleRestR15")

	-- First meeple: use the player's character model if provided
	if playerCharacter then
		_spawnCharacterMeeple("You", playerCharacter)
	end

	-- Spawn remaining plain meeples to fill MEEPLE_COUNT
	local remaining = playerCharacter and (Config.MEEPLE_COUNT - 1) or Config.MEEPLE_COUNT
	for i = 1, remaining do
		_spawnMeeple("Meeple " .. i, false)
	end

	-- Query server for other players / friends and replace/add meeple
	local Shared2    = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Remotes    = require(Shared2.Remotes)

	task.spawn(function()
		local ok, serverPlayers = pcall(function()
			return Remotes.GetServerInfo:InvokeServer()
		end)
		if not ok or type(serverPlayers) ~= "table" then return end

		for _, info in serverPlayers do
			_spawnMeeple(info.name, info.isFriend)
		end
	end)

	RunService.Heartbeat:Connect(_tick)
end

return MeepleManager
