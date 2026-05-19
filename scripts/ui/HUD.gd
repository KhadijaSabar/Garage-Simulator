## HUD.gd
## Main HUD overlay — shows money, day, time, and action buttons.
extends CanvasLayer

# ── Scene References ──────────────────────────────────────────────────────────
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var time_bar: ProgressBar = $TopBar/TimeBar
@onready var rep_label: Label = $TopBar/RepLabel

@onready var action_panel: PanelContainer = $ActionPanel
@onready var clean_btn: Button = $ActionPanel/VBox/CleanBtn
@onready var inspect_btn: Button = $ActionPanel/VBox/InspectBtn
@onready var sell_btn: Button = $ActionPanel/VBox/SellBtn

# ── References ────────────────────────────────────────────────────────────────
var garage: Node = null  # Set by Garage.gd after ready

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Initial display
	update_money(EconomyManager.money)
	update_day(GameManager.current_day)
	update_reputation(EconomyManager.reputation)

	# Connect signals
	EconomyManager.money_changed.connect(func(amount, _d): update_money(amount))
	EconomyManager.reputation_changed.connect(func(rep): update_reputation(rep))
	GameManager.day_started.connect(func(day): update_day(day))

	# Button connections
	if clean_btn:
		clean_btn.pressed.connect(_on_clean_pressed)
	if inspect_btn:
		inspect_btn.pressed.connect(_on_inspect_pressed)
	if sell_btn:
		sell_btn.pressed.connect(_on_sell_pressed)

func _process(_delta: float) -> void:
	# Update time bar every frame
	if time_bar:
		time_bar.value = GameManager.get_day_progress() * 100.0

# ── Update Methods ────────────────────────────────────────────────────────────
func update_money(amount: int) -> void:
	if money_label:
		money_label.text = "$%s" % _format_number(amount)

func update_day(day: int) -> void:
	if day_label:
		day_label.text = "Day %d" % day

func update_reputation(rep: float) -> void:
	if rep_label:
		rep_label.text = "Rep: %s" % EconomyManager.get_reputation_label()

# ── Button Handlers ───────────────────────────────────────────────────────────
func _on_clean_pressed() -> void:
	if garage and garage.has_method("do_clean"):
		garage.do_clean()

func _on_inspect_pressed() -> void:
	var panel = get_node_or_null("InspectionPanel")
	if panel and garage and garage.current_vehicle:
		panel.show_vehicle(garage.current_vehicle.data)

func _on_sell_pressed() -> void:
	# Quick-sell at current value (no negotiation)
	if garage and garage.current_vehicle:
		var value := garage.current_vehicle.data.get_sell_value()
		garage.sell_current_vehicle(value)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _format_number(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
