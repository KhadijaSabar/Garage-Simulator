## GameManager.gd
## Autoload singleton — manages game state, day system, and global signals.
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal day_started(day_number: int)
signal day_ended(day_number: int)
signal game_state_changed(new_state: GameState)

# ── Enums ─────────────────────────────────────────────────────────────────────
enum GameState {
	GARAGE,       # Player is working in the garage
	JUNKYARD,     # Player is scavenging the junkyard
	NEGOTIATING,  # Buy/sell negotiation in progress
	PAUSED
}

# ── State ─────────────────────────────────────────────────────────────────────
var current_state: GameState = GameState.GARAGE
var current_day: int = 1
var day_time: float = 0.0          # 0.0 = start of day, 1.0 = end of day
var DAY_LENGTH_SECONDS: float = 300.0  # 5 real minutes = 1 game day

var is_day_running: bool = false

## Snapshotted at start of each day for the day-summary delta display
var day_start_money: int = 0
var day_start_rep:   float = 50.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	print("[GameManager] Initialized — Day %d" % current_day)
	start_day()

func _process(delta: float) -> void:
	if not is_day_running:
		return
	day_time += delta / DAY_LENGTH_SECONDS
	if day_time >= 1.0:
		end_day()

# ── Day System ────────────────────────────────────────────────────────────────
func start_day() -> void:
	day_time = 0.0
	is_day_running = true
	day_start_money = EconomyManager.money
	day_start_rep   = EconomyManager.reputation
	emit_signal("day_started", current_day)
	print("[GameManager] Day %d started." % current_day)

func end_day() -> void:
	is_day_running = false
	day_time = 1.0
	emit_signal("day_ended", current_day)
	print("[GameManager] Day %d ended. Waiting for night phase…" % current_day)
	# Day does NOT auto-advance here.
	# ThiefSystem runs its night check, then emits night_phase_end.
	# Garage catches that and shows DaySummary, which calls advance_to_next_day().

func advance_to_next_day() -> void:
	current_day += 1
	start_day()

## Returns day progress as 0.0–1.0 float
func get_day_progress() -> float:
	return day_time

## Change game state and emit signal
func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	emit_signal("game_state_changed", new_state)
	print("[GameManager] State → %s" % GameState.keys()[new_state])
