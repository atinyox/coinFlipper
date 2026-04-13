-- Config.luau
-- All tunable game constants. Change values here to tweak gameplay without
-- touching logic files. CAMERA_ANGLE especially is meant to be dialed in
-- during playtesting.

local Config = {}

-- Board
Config.BOARD_SIZE         = Vector3.new(40, 1, 40)   -- XYZ dimensions of the board Part

-- Coins
Config.INITIAL_COIN_COUNT = 2       -- coins spawned at game start
Config.COIN_COOLDOWN      = 1       -- seconds a coin is locked after being flipped
Config.FLIP_WIN_CHANCE    = 0.5     -- base probability of heads (0–1)
Config.BASE_PAYOUT        = 1      -- money earned per successful flip

-- Meeple
Config.MEEPLE_COUNT       = 1       -- default meeple before server friend data loads
Config.MEEPLE_SPEED       = 10      -- studs per second movement speed
Config.MEEPLE_MAX_ENERGY  = 10      -- number of flips before a meeple tires
Config.MEEPLE_REST_DURATION = 10    -- seconds before a tired meeple wakes automatically
Config.MEEPLE_FLIP_PAUSE    = 3  -- seconds a meeple idles after flipping before seeking the next coin

-- Coin flip animation (shared by CoinRenderer and MeepleManager)
Config.FLIP_DURATION      = 0.9    -- seconds for the full coin arc animation
Config.FLIP_DRIFT         = 2.2   -- max studs the coin drifts from its start on landing

-- Meeple animation IDs — R6 defaults (Noob is R6)
Config.ANIM_R6_WALK       = "rbxassetid://180426354"
Config.ANIM_R6_FLIP       = "rbxassetid://125750702"  -- Jump: energetic pop matching coin toss
Config.ANIM_R6_REST       = "rbxassetid://178130996"  -- Sit: meeple sits when tired
Config.ANIM_R15_WALK      = "rbxassetid://507777826"
Config.ANIM_R15_FLIP      = "rbxassetid://507765644"  -- Jump (R15)
Config.ANIM_R15_REST      = "rbxassetid://507768133"  -- Sit (R15)

-- Camera
Config.CAMERA_HEIGHT      = 25      -- studs above the board center
Config.CAMERA_ANGLE       = 40      -- degrees from vertical (0 = straight down, 90 = horizontal)

-- Persistence
Config.SAVE_DEBOUNCE      = 30      -- minimum seconds between DataStore writes

return Config
