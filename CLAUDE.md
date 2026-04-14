# coinFlipper — Claude Development Guide

## Build & Workflow
- `rojo serve` — live-sync source files into Roblox Studio
- `rojo build -o "coinFlipper.rbxlx"` — build a fresh place file from scratch
- Always edit `.luau` files on disk; Rojo syncs them to Studio. Never edit scripts via MCP Studio tools.

## Architecture
All gameplay logic is **client-side**. The server only handles:
1. DataStore load/save via `server/DataManager.luau`
2. Player list + friend status queries via `GetServerInfo` RemoteFunction

## Key Files
| File | Role |
|---|---|
| `shared/ConfigBase.luau` | All tunable constants. Tweak here first. |
| `shared/ConfigUpgrades.luau` | Upgrade catalog — per-level cost/value tables |
| `client/PlayerState.luau` | Single source of truth for money and upgrade levels |
| `client/CoinManager.luau` | Coin spawning + flip RNG + H/T face labels |
| `client/CoinRenderer.luau` | Coin flip arc animation (height, tumble, drift) |
| `client/MeepleManager.luau` | Meeple AI FSM + walk/flip/rest animations |
| `client/ShopManager.luau` | Purchase logic + applies upgrades to Config |
| `server/DataManager.luau` | DataStore persistence (server only) |

## Coordinate System
- Board is centered at world origin (0, 0.5, 0)
- Board surface: Y = 1
- Board XZ bounds: ±20 studs from origin (matches BOARD_SIZE 40×40)

## Camera Tuning
`ConfigBase.CAMERA_ANGLE` = degrees from vertical (0 = straight down). Default 40°.
Change this value and re-serve to see the effect without code changes.

## Meeple System
- Default model: `ReplicatedStorage.Noob` (cloned at spawn). Falls back to plain Part if missing.
- FSM states: IDLE → MOVING → FLIPPING → TIRED → (auto-wake or click) → IDLE
- Animations stored as KeyframeSequence instances in ReplicatedStorage (`CoinFlipR6`, `CoinFlipR15`, `MeepleRestR6`, `MeepleRestR15`). Registered at init via `KeyframeSequenceProvider`, loaded asynchronously in `_loadAnimationsAsync`. Animator is created manually for cloned models since Roblox only auto-creates it for player characters.
- `MEEPLE_FLIP_PAUSE` controls idle time between flips. `MEEPLE_REST_DURATION` controls auto-wake delay when tired.

## Coin Flip Animation
- Coins tumble around the world X axis (`CFrame.fromAxisAngle`) with a parabolic height arc.
- Heads: Right face (+X) up, showing "H". Tails: extra π rotation flips coin so Left face up, showing "T".
- Random XZ drift on each flip (`ConfigBase.FLIP_DRIFT`).
- Duration shared via `ConfigBase.FLIP_DURATION` (used by both CoinRenderer and MeepleManager).

## Naming Conventions
- PascalCase module files (`CoinManager.luau`)
- Private module members prefixed with `_` (`_coins`, `_cooldowns`)
- `export type` for public Luau types

## Adding Upgrades
1. Add a table to `shared/ConfigUpgrades.luau` with `name`, `desc`, `configKey`, and per-level `{cost, value}` entries
2. Add the upgrade id to the `UpgradeOrder` array for UI placement
3. If the upgrade needs side effects beyond setting Config (e.g. spawning coins/meeple), add a handler in `client/ShopManager.luau` (`_applyUpgrade`)
4. `ShopUI` picks up new upgrades automatically from the order list
