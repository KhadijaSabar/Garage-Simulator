# 🔧 Grease & Glory — Setup Guide

## Prerequisites

1. **Download Godot 4** (free): https://godotengine.org/download
   - Get **Godot Engine - .NET** version if you want C# later, otherwise standard is fine
   - Recommended: Godot 4.2 or newer

## Opening the Project

1. Launch Godot 4
2. Click **"Import"** on the Project Manager screen
3. Navigate to this folder: `GarageGame/`
4. Select `project.godot` and click **"Import & Edit"**

## First-Time Setup in the Editor

When you open the project, Godot will scan and import all files. Then:

### Fix the Vehicle ClickArea collision (one-time setup)

The vehicle's click detection needs a collision shape:

1. Open `scenes/vehicles/Vehicle.tscn`
2. Click on `ClickArea > CollisionShape2D` in the Scene panel
3. In the Inspector, set **Shape** → `New RectangleShape2D`
4. Set **Size** to `(120, 60)`
5. Save the scene (Ctrl+S)

### Connect the HUD garage reference

1. Open `scenes/garage/Garage.tscn`
2. Select the `HUD` node
3. In the Inspector, drag the `Garage` root node into the **Garage** property
   *(or this can be done via code — the HUD.gd finds garage nodes automatically in the group)*

## Running the Game

- Press **F5** or click the ▶ Play button
- The game will start with a rusty sedan in the garage bay
- **Click** the vehicle to inspect it
- Use the **Action Panel** (right side) to Clean, Inspect, or Quick Sell
- Wait for a **customer** to arrive (~30–60 seconds) and negotiate a sale

## Controls

| Action | How |
|--------|-----|
| Select vehicle | Left click on it |
| Clean vehicle | Click "🧹 Clean" button |
| Inspect parts | Click "🔍 Inspect" button |
| Quick sell | Click "💰 Quick Sell" |
| Negotiate | Wait for customer popup |

## Project Structure

```
GarageGame/
├── project.godot          ← Open this in Godot
├── scenes/
│   ├── Main.tscn          ← Entry point
│   ├── garage/
│   │   └── Garage.tscn    ← Main gameplay scene
│   └── vehicles/
│       └── Vehicle.tscn   ← Vehicle prefab
├── scripts/
│   ├── autoloads/         ← GameManager, EconomyManager, VehicleDatabase
│   ├── vehicles/          ← VehicleData, Vehicle logic
│   ├── garage/            ← Garage controller
│   ├── ui/                ← HUD, InspectionPanel, NegotiationDialog
│   └── customers/         ← Customer AI
└── assets/                ← (sprites and audio go here later)
```

## What's Working in Phase 1

- ✅ Vehicle spawns with randomized damage
- ✅ Click to inspect — see all parts and their condition
- ✅ Clean action — reduces dirt, raises condition score
- ✅ Repair parts — spend money to fix individual parts
- ✅ Customer arrives — full negotiation dialog (accept/counter/refuse)
- ✅ Money system — earn/spend, tracked in HUD
- ✅ Day/time system — day progresses, resets each cycle
- ✅ Reputation — changes based on deal fairness

## Next Steps (Phase 2)

- Add 2 more vehicle types (pickup truck, vintage coupe)
- Junkyard scavenging scene
- Proper isometric art (replace placeholder ColorRects)
- Sound effects
- Buy vehicle from seller flow
