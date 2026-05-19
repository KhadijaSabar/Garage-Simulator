## SaveManager.gd
## Autoload — handles saving and loading all game state to/from a JSON file.
## Save file lives in user:// (Godot's app data folder, platform-appropriate).
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────
const SAVE_PATH := "user://grease_glory_save.json"
const SAVE_VERSION := 1

# ── Signals ───────────────────────────────────────────────────────────────────
signal game_saved
signal game_loaded

# ── Auto-save ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Hook into key events for auto-save
	EconomyManager.transaction_completed.connect(_on_transaction)
	GameManager.day_ended.connect(func(_d): auto_save())

func _on_transaction(_desc: String, _amount: int) -> void:
	# Auto-save after every 3rd transaction (don't save every single click)
	_tx_count += 1
	if _tx_count >= 3:
		_tx_count = 0
		auto_save()

var _tx_count: int = 0

# ── Save ──────────────────────────────────────────────────────────────────────
func auto_save() -> void:
	save_game()

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"economy": {
			"money": EconomyManager.money,
			"reputation": EconomyManager.reputation,
		},
		"game": {
			"day": GameManager.current_day,
		},
		"inventory": InventoryManager.to_dict(),
		"progression": ProgressionManager.to_dict(),
		"auction": AuctionSystem.to_dict(),
		"xp":        XPManager.to_dict(),
		"employees": EmployeeManager.to_dict(),
		"towing":    TowingManager.to_dict(),
	}

	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing: %s" % SAVE_PATH)
		return false

	file.store_string(json_str)
	file.close()
	emit_signal("game_saved")
	print("[SaveManager] Game saved ✓ (Day %d, $%d)" % [GameManager.current_day, EconomyManager.money])
	return true

# ── Load ──────────────────────────────────────────────────────────────────────
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file found — starting fresh.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot open save file for reading.")
		return false

	var json_str := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_str)
	if parsed == null or not parsed is Dictionary:
		push_error("[SaveManager] Save file is corrupt.")
		return false

	var data: Dictionary = parsed

	# Economy
	var eco: Dictionary = data.get("economy", {})
	EconomyManager.money = eco.get("money", EconomyManager.STARTING_MONEY)
	EconomyManager.reputation = eco.get("reputation", 50.0)

	# Game state
	var game: Dictionary = data.get("game", {})
	GameManager.current_day = game.get("day", 1)

	# Subsystems
	InventoryManager.from_dict(data.get("inventory", {}))
	ProgressionManager.from_dict(data.get("progression", {}))
	AuctionSystem.from_dict(data.get("auction", {}))
	XPManager.from_dict(data.get("xp", {}))
	EmployeeManager.from_dict(data.get("employees", {}))
	TowingManager.from_dict(data.get("towing", {}))

	emit_signal("game_loaded")
	print("[SaveManager] Game loaded ✓ (Day %d, $%d)" % [GameManager.current_day, EconomyManager.money])
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveManager] Save file deleted.")
