# coinFlipper — Claude Development Guide

## Build & Workflow
- `rojo serve` — live-sync source files into Roblox Studio
- `rojo build -o "coinFlipper.rbxlx"` — build a fresh place file from scratch

## Architecture
All gameplay logic is **client-side**. The server only handles:
1. DataStore load/save via `server/DataManager.luau`
2. Player list + friend status queries via `GetServerInfo` RemoteFunction

## Key Files
| File | Role |
|---|---|
| `shared/Config.luau` | All tunable constants. Tweak here first. |
| `shared/UpgradeDefinitions.luau` | Upgrade catalog — costs, effects, max levels |
| `client/PlayerState.luau` | Single source of truth for money and upgrade levels |
| `client/CoinManager.luau` | Coin spawning + flip RNG |
| `client/MeepleManager.luau` | Meeple AI FSM |
| `server/DataManager.luau` | DataStore persistence (server only) |

## Coordinate System
- Board is centered at world origin (0, 0.5, 0)
- Board surface: Y = 1
- Board XZ bounds: ±20 studs from origin (matches BOARD_SIZE 40×40)

## Camera Tuning
`Config.CAMERA_ANGLE` = degrees from vertical (0 = straight down). Default 20°.
Change this value and re-serve to see the effect without code changes.

## Naming Conventions
- PascalCase module files (`CoinManager.luau`)
- Private module members prefixed with `_` (`_coins`, `_cooldowns`)
- `export type` for public Luau types

## Adding Upgrades
1. Add an entry to `shared/UpgradeDefinitions.luau`
2. Add the effect application in `client/ShopManager.luau` (`_applyUpgrade`)
3. `ShopUI` picks up new upgrades automatically
