## XPManager.gd
## Autoload — player XP, levels, and level-up rewards.
## XP is earned from every meaningful action in the garage.
## Levels unlock flavour perks and feed into ProgressionManager tiers.
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal xp_gained(amount: int, source: String)   ## Raw gain — for HUD ticker
signal level_up(new_level: int, reward: Dictionary)  ## Fires on each level-up

# ── Level curve ───────────────────────────────────────────────────────────────
## XP required to reach level N  =  BASE * N^EXPONENT  (rounded)
const BASE_XP   : float = 120.0
const EXPONENT  : float = 1.55
const MAX_LEVEL : int   = 50

## Pre-computed cumulative XP thresholds (index = level, value = total XP needed)
var _thresholds : Array[int] = []

# ── XP sources (amount per action) ────────────────────────────────────────────
## These are base values — some callers scale by quality/profit.
const XP_SOURCES : Dictionary = {
	# Vehicle sales
	"flip_sale":          30,    ## Sold a car for profit
	"flip_sale_profit":    1,    ## Extra XP per $100 profit (scaled)
	"service_complete":   45,    ## Finished a walk-in service order
	"service_bonus":       5,    ## Extra per rep point earned from service
	# Repairs
	"repair_manual":      20,    ## Completed a manual repair minigame
	"repair_free":         8,    ## Used a spare part (free repair)
	# Auction
	"auction_win":        35,    ## Won a vehicle at auction
	"auction_bargain":    15,    ## Won at < 70% of true value (bonus)
	# Daily
	"day_survived":       10,    ## Just making it through a day
	"day_clean_garage":    5,    ## Garage was clean at end of day
	# Negotiation
	"neg_hard_deal":      12,    ## Sold to a tough customer (honest mechanic, expert)
	"neg_fair_price":      6,    ## Sold within 10% of fair value
	# Junkyard
	"junkyard_run":       15,    ## Completed a junkyard scavenging run
	"rare_part_found":    20,    ## Found a rare part in the junkyard
}

# ── Level-up rewards ──────────────────────────────────────────────────────────
## Keyed by level reached. Missing levels give a generic "+rep cap" reward.
const LEVEL_REWARDS : Dictionary = {
	2:  {"type": "xp_rate",    "value": 0.05,  "desc": "+5% XP from all sources"},
	3:  {"type": "rep_cap",    "value": 5.0,   "desc": "Reputation cap +5"},
	5:  {"type": "xp_rate",    "value": 0.10,  "desc": "+10% XP from repairs"},
	7:  {"type": "money_bonus","value": 200,   "desc": "$200 cash bonus"},
	10: {"type": "unlock",     "value": "haggling_2", "desc": "Customers open 5% higher (stacks)"},
	12: {"type": "xp_rate",    "value": 0.15,  "desc": "+15% XP from auctions"},
	15: {"type": "money_bonus","value": 500,   "desc": "$500 cash bonus"},
	18: {"type": "unlock",     "value": "sixth_sense", "desc": "Sixth Sense — see customer budget hint"},
	20: {"type": "money_bonus","value": 1000,  "desc": "$1,000 cash bonus"},
	25: {"type": "unlock",     "value": "bulk_auction", "desc": "Auction: +2 lots per day"},
	30: {"type": "money_bonus","value": 2500,  "desc": "$2,500 cash bonus"},
	35: {"type": "unlock",     "value": "vip_customers","desc": "VIP customers start appearing"},
	40: {"type": "money_bonus","value": 5000,  "desc": "$5,000 cash bonus"},
	50: {"type": "unlock",     "value": "legend_badge", "desc": "🏆 LEGEND — max level reached!"},
}

# ── State ─────────────────────────────────────────────────────────────────────
var total_xp       : int   = 0
var current_level  : int   = 1
var _xp_rate_bonus : float = 0.0   ## Accumulated from level rewards
var unlocks        : Array = []    ## Strings of earned unlock IDs

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_thresholds()
	GameManager.day_ended.connect(_on_day_ended)

func _build_thresholds() -> void:
	_thresholds.clear()
	_thresholds.append(0)   # level 1 starts at 0 XP
	for lvl in range(2, MAX_LEVEL + 1):
		var needed : int = int(BASE_XP * pow(float(lvl - 1), EXPONENT))
		_thresholds.append(_thresholds[-1] + needed)

# ── Public API ────────────────────────────────────────────────────────────────

## Award XP from a named source. `scale` lets callers multiply (e.g. profit-based).
func award(source: String, scale: float = 1.0) -> int:
	var base  : int = XP_SOURCES.get(source, 0)
	if base == 0:
		push_warning("[XP] Unknown source: %s" % source)
		return 0
	var amount : int = max(1, int(float(base) * scale * (1.0 + _xp_rate_bonus)))
	_add_xp(amount, source)
	return amount

## Award a raw amount of XP directly (for one-off events).
func award_raw(amount: int, source: String = "event") -> void:
	_add_xp(max(1, amount), source)

func get_level_progress() -> float:
	## Returns 0.0 … 1.0 progress toward the next level.
	if current_level >= MAX_LEVEL: return 1.0
	var current_floor : int = _thresholds[current_level - 1]
	var next_ceil     : int = _thresholds[current_level]
	if next_ceil <= current_floor: return 1.0
	return clampf(float(total_xp - current_floor) / float(next_ceil - current_floor), 0.0, 1.0)

func get_xp_for_next() -> int:
	if current_level >= MAX_LEVEL: return 0
	return _thresholds[current_level] - total_xp

func has_unlock(unlock_id: String) -> bool:
	return unlock_id in unlocks

## Additive offer bonus from levelling (stacks with ProgressionManager haggling)
func get_level_offer_bonus() -> float:
	return 0.05 if has_unlock("haggling_2") else 0.0

## Whether the player can see a vague budget hint in the negotiation panel
func can_see_budget_hint() -> bool:
	return has_unlock("sixth_sense")

## Extra auction lots from level perks
func get_bonus_auction_lots() -> int:
	return 2 if has_unlock("bulk_auction") else 0

# ── Internal ──────────────────────────────────────────────────────────────────
func _add_xp(amount: int, source: String) -> void:
	total_xp += amount
	emit_signal("xp_gained", amount, source)
	print("[XP] +%d XP  (%s)  total: %d  lvl: %d" % [amount, source, total_xp, current_level])
	_check_level_up()

func _check_level_up() -> void:
	while current_level < MAX_LEVEL and total_xp >= _thresholds[current_level]:
		current_level += 1
		var reward : Dictionary = _apply_level_reward(current_level)
		emit_signal("level_up", current_level, reward)
		print("[XP] ⬆️  Level %d!  Reward: %s" % [current_level, reward.get("desc", "—")])

func _apply_level_reward(lvl: int) -> Dictionary:
	var reward : Dictionary = LEVEL_REWARDS.get(lvl, {
		"type": "rep_cap", "value": 2.0,
		"desc": "Reputation cap +2 (level %d)" % lvl
	})
	match reward.get("type", ""):
		"xp_rate":
			_xp_rate_bonus += float(reward["value"])
		"money_bonus":
			EconomyManager.add_money(int(reward["value"]), "Level %d bonus" % lvl)
		"unlock":
			var uid : String = str(reward["value"])
			if uid not in unlocks:
				unlocks.append(uid)
		"rep_cap":
			EconomyManager.reputation_cap += float(reward["value"])
	return reward

func _on_day_ended(_day: int = 0) -> void:
	award("day_survived")

# ── Save / Load ───────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {
		"total_xp":      total_xp,
		"level":         current_level,
		"xp_rate_bonus": _xp_rate_bonus,
		"unlocks":       unlocks.duplicate(),
	}

func from_dict(data: Dictionary) -> void:
	total_xp       = data.get("total_xp",      0)
	current_level  = data.get("level",          1)
	_xp_rate_bonus = data.get("xp_rate_bonus",  0.0)
	unlocks.assign(data.get("unlocks",          []))
