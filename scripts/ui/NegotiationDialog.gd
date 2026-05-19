## NegotiationDialog.gd
## Buy/sell negotiation popup.
## Shows customer offer, player can accept, counter, or refuse.
extends PanelContainer

# ── Scene References ──────────────────────────────────────────────────────────
@onready var customer_name_label: Label = $VBox/CustomerNameLabel
@onready var personality_label: Label = $VBox/PersonalityLabel
@onready var greeting_label: Label = $VBox/GreetingLabel
@onready var offer_label: Label = $VBox/OfferLabel
@onready var vehicle_value_label: Label = $VBox/VehicleValueLabel
@onready var counter_slider: HSlider = $VBox/CounterRow/CounterSlider
@onready var counter_value_label: Label = $VBox/CounterRow/CounterValueLabel
@onready var accept_btn: Button = $VBox/Buttons/AcceptBtn
@onready var counter_btn: Button = $VBox/Buttons/CounterBtn
@onready var refuse_btn: Button = $VBox/Buttons/RefuseBtn
@onready var result_label: Label = $VBox/ResultLabel

# ── State ─────────────────────────────────────────────────────────────────────
var active_customer: Customer = null
var active_vehicle: VehicleData = null
var current_customer_offer: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	hide()
	if accept_btn:
		accept_btn.pressed.connect(_on_accept)
	if counter_btn:
		counter_btn.pressed.connect(_on_counter)
	if refuse_btn:
		refuse_btn.pressed.connect(_on_refuse)
	if counter_slider:
		counter_slider.value_changed.connect(_on_slider_changed)

# ── Public API ────────────────────────────────────────────────────────────────
func open(customer: Customer, vehicle: VehicleData) -> void:
	active_customer = customer
	active_vehicle = vehicle
	current_customer_offer = customer.current_offer

	_refresh_ui()
	if result_label:
		result_label.hide()
	_set_buttons_enabled(true)
	show()

# ── UI Refresh ────────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	if not active_customer or not active_vehicle:
		return

	if customer_name_label:
		customer_name_label.text = active_customer.display_name

	if personality_label:
		personality_label.text = "(%s)" % active_customer.get_personality_label()

	if greeting_label:
		greeting_label.text = '"%s"' % active_customer.get_greeting()

	if offer_label:
		offer_label.text = "Their offer: $%d" % current_customer_offer

	if vehicle_value_label:
		var value := active_vehicle.get_sell_value()
		vehicle_value_label.text = "Your vehicle is worth ~$%d" % value

	# Counter slider: range from customer offer to 150% of vehicle value
	if counter_slider:
		var vehicle_value := active_vehicle.get_sell_value()
		counter_slider.min_value = current_customer_offer
		counter_slider.max_value = int(vehicle_value * 1.5)
		counter_slider.value = vehicle_value  # default ask = fair value
		_on_slider_changed(counter_slider.value)

func _on_slider_changed(value: float) -> void:
	if counter_value_label:
		counter_value_label.text = "$%d" % int(value)

# ── Button Handlers ───────────────────────────────────────────────────────────
func _on_accept() -> void:
	# Accept customer's current offer
	_complete_sale(current_customer_offer, active_customer.get_accept_comment())

func _on_counter() -> void:
	if not active_customer or not counter_slider:
		return

	var asking: int = int(counter_slider.value)

	if active_customer.will_accept(asking):
		_complete_sale(asking, active_customer.get_accept_comment())
		return

	# Customer didn't accept — they counter back or walk
	if active_customer.has_walked():
		_customer_walks()
		return

	current_customer_offer = active_customer.counter_offer()

	if offer_label:
		offer_label.text = "Their counter: $%d" % current_customer_offer

	if greeting_label:
		greeting_label.text = '"%s"' % active_customer.get_low_offer_comment()

	# Update slider minimum to new offer
	if counter_slider:
		counter_slider.min_value = current_customer_offer

func _on_refuse() -> void:
	_customer_walks()

# ── Resolution ────────────────────────────────────────────────────────────────
func _complete_sale(price: int, comment: String) -> void:
	_set_buttons_enabled(false)

	if result_label:
		result_label.text = '"%s"\nSold for $%d!' % [comment, price]
		result_label.modulate = Color.GREEN
		result_label.show()

	# Tell garage to process the sale
	var garage = get_tree().get_first_node_in_group("garage")
	if garage and garage.has_method("sell_current_vehicle"):
		garage.sell_current_vehicle(price)

	await get_tree().create_timer(2.0).timeout
	hide()

func _customer_walks() -> void:
	_set_buttons_enabled(false)

	if result_label:
		result_label.text = '"%s"' % active_customer.get_walk_comment()
		result_label.modulate = Color.RED
		result_label.show()

	await get_tree().create_timer(2.0).timeout
	hide()

func _set_buttons_enabled(enabled: bool) -> void:
	if accept_btn: accept_btn.disabled = not enabled
	if counter_btn: counter_btn.disabled = not enabled
	if refuse_btn: refuse_btn.disabled = not enabled
