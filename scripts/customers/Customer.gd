## Customer.gd
## Customer AI — personality, budget, negotiation logic.
## 7 flip-sale archetypes + 4 service/repair archetypes.
class_name Customer
extends RefCounted

# ── Enums ─────────────────────────────────────────────────────────────────────
enum Personality {
	# ── Flip-sale buyers (want to purchase your car) ──────────────────────────
	BUDGET_BUYER,       # Tight wallet, haggles hard
	COLLECTOR,          # Connoisseur, pays premium for quality
	RESTORER,           # Wants a project, buys damaged wrecks
	FLIPPER,            # Analytical reseller, knows the numbers
	CLUELESS_WIFE,      # Broke husband's car — easy to overcharge, no rep penalty
	RICH_KID,           # Dad's money — accepts any price instantly
	POOR_STUDENT,       # Broke student — help for free = +20 rep
	RETIRED_MECHANIC,   # Expert — knows exact value, fair price = bonus rep
	SHADY_GUY,          # Pays premium, no questions, -2 rep regardless
	# ── Service customers (bring their car in for repair) ─────────────────────
	SERVICE_MOM,        # Family car broke, stressed, pays fairly, very grateful
	SERVICE_COMMUTER,   # Just needs it running again today, impatient, pays well
	SERVICE_ENTHUSIAST, # Wants EVERYTHING done, high budget, very happy to pay
	SERVICE_PENSIONER,  # Old classic car owner, low budget, +rep if you're kind
}

# ── Properties ────────────────────────────────────────────────────────────────
var display_name : String      = ""
var personality  : Personality = Personality.BUDGET_BUYER
var budget       : int         = 0
var patience     : int         = 3
var current_offer: int         = 0

## Special flags ---------------------------------------------------------------
var overcharge_immune    : bool  = false  ## No rep penalty for overcharging (CLUELESS_WIFE)
var auto_accepts         : bool  = false  ## Accepts anything up to budget instantly (RICH_KID)
var gives_free_help      : bool  = false  ## Can be helped for free for big rep (POOR_STUDENT)
var honest_bonus         : bool  = false  ## Fair-price deal gives +5 rep (RETIRED_MECHANIC)
var shady_deal           : bool  = false  ## -2 rep regardless of price (SHADY_GUY)
var persistent           : bool  = false  ## Won't leave on first Refuse — needs kicking out

## Service flags ---------------------------------------------------------------
var is_service           : bool  = false  ## True = wants their car repaired (not buying)
var service_jobs         : Array = []     ## Job keys they need (from OrderSystem.JOB_TYPES)
var service_vehicle_id   : String = ""    ## Vehicle template to spawn in the bay
var service_budget_mult  : float = 1.0    ## How far over the estimate they'll accept (1.0 = exact estimate)
var service_rep_bonus    : float = 0.0    ## Extra rep on completion (SERVICE_PENSIONER etc.)

# ── Personality data ──────────────────────────────────────────────────────────
const PERSONALITY_DATA : Dictionary = {
	Personality.BUDGET_BUYER: {
		"label":  "💼  Budget Buyer",
		"color":  Color(0.70, 0.70, 0.70),
		"names":  ["Dave", "Mike", "Terry", "Karen", "Lisa", "Wayne", "Brenda"],
		"arrive": "A regular-looking guy just walked in.",
		"greet":  [
			"Hey, just looking for something to get me to work. Nothing fancy.",
			"I need a car that starts in the morning. That's literally all I need.",
			"My ex took the last one. Don't ask.",
		],
		"low":    [
			"Come on, that's way too steep for this thing.",
			"You're killing me here. That's my grocery budget.",
			"Can we meet in the middle? Please?",
		],
		"accept": [
			"Deal! My wife's gonna kill me but okay.",
			"Fine, fine. You drive a hard bargain.",
			"Alright. I'll skip lunch this week.",
		],
		"walk":   [
			"Forget it, I'll check the classifieds.",
			"That's too rich for me. Thanks anyway.",
			"My bus pass is looking pretty good right now.",
		],
		"budget_mul":  0.65,
		"haggle_step": 0.08,
		"opening_mul": 0.82,
		"patience":    3,
	},
	Personality.COLLECTOR: {
		"label":  "🎩  Collector",
		"color":  Color(0.72, 0.58, 1.0),
		"names":  ["Gerald", "Patricia", "Vincent", "Diane", "Reginald"],
		"arrive": "A well-dressed figure walks in slowly, inspecting everything.",
		"greet":  [
			"I appreciate a quality restoration. What are we working with here?",
			"I've been searching for something like this for months. Tell me everything.",
			"Provenance matters to me. What's the history on this piece?",
		],
		"low":    [
			"Hmm, let me consider. This is a significant piece.",
			"The price reflects the rarity, I understand. Still steep.",
			"My accountant will not be pleased with me.",
		],
		"accept": [
			"Excellent. You drive a hard bargain. Pleasure doing business.",
			"Done. A fair price for a remarkable vehicle.",
			"My collection will be complete. Thank you.",
		],
		"walk":   [
			"I'm afraid this isn't what I'm looking for today.",
			"Perhaps another time. I'll leave my card.",
			"At that price I'd rather restore one myself.",
		],
		"budget_mul":  1.15,
		"haggle_step": 0.05,
		"opening_mul": 0.90,
		"patience":    4,
	},
	Personality.RESTORER: {
		"label":  "🔨  Restorer",
		"color":  Color(0.90, 0.65, 0.35),
		"names":  ["Bobby", "Steve", "Hank", "Donna", "Earl"],
		"arrive": "A guy in overalls wanders in, eyeing the damage first.",
		"greet":  [
			"I'm looking for a project. The worse the shape, the better, honestly.",
			"Give me something I can take apart on weekends. That's my therapy.",
			"What's the most beat-up thing you've got? That's the one I want.",
		],
		"low":    [
			"It's a wreck. I'm paying for potential, not parts.",
			"I've got a garage full of these. It can't be that much.",
			"I'm going to spend triple this putting it back together. Be reasonable.",
		],
		"accept": [
			"Perfect. This is gonna look beautiful when I'm done with it.",
			"Deal. She'll be singing again by spring.",
			"My wife's going to hate this. Worth it.",
		],
		"walk":   [
			"Too rich for a car in this condition. I'll pass.",
			"I can find three wrecks for that price at the junkyard.",
			"No thanks. Not worth the effort at that price.",
		],
		"budget_mul":  0.45,
		"haggle_step": 0.06,
		"opening_mul": 0.80,
		"patience":    3,
	},
	Personality.FLIPPER: {
		"label":  "📊  Car Flipper",
		"color":  Color(0.40, 0.85, 0.85),
		"names":  ["Tony", "Raj", "Marcus", "Cindy", "Derek"],
		"arrive": "Someone with a phone out, checking prices online, walks in.",
		"greet":  [
			"I flip cars on the side. What's the margin look like here?",
			"I've got KBB open right now. Don't try anything funny.",
			"I do about six of these a month. Just give me a fair number.",
		],
		"low":    [
			"Numbers don't add up at that price. Be realistic.",
			"I ran the comps. You're high by at least 20%.",
			"That's not how this works. You know that.",
		],
		"accept": [
			"Works for me. Clean title?",
			"Fine. I'll move it by the weekend.",
			"Deal. I've seen worse margins.",
		],
		"walk":   [
			"Not enough upside. Moving on.",
			"There's a better deal two blocks down. Thanks.",
			"Doesn't pencil out. Good luck.",
		],
		"budget_mul":  0.80,
		"haggle_step": 0.07,
		"opening_mul": 0.83,
		"patience":    2,
	},
	Personality.CLUELESS_WIFE: {
		"label":  "😅  Completely Lost",
		"color":  Color(1.0, 0.65, 0.80),
		"names":  ["Sandra", "Debbie", "Janet", "Cheryl", "Tina", "Mandy", "Fiona"],
		"arrive": "A flustered woman rushes in, clutching her phone. She looks stressed.",
		"greet":  [
			"Okay so it just... stopped going. I don't know what I pressed. Is that bad?",
			"My husband is going to KILL me. Please, how much to fix—wait, I mean BUY a new one?",
			"Someone at work said you're the best. This is my husband's car. Please don't ask questions.",
			"The smoke was probably fine, right? ...right? How much are cars?",
		],
		"low":    [
			"Oh is that expensive? I don't really know what cars cost.",
			"My husband handles all this. Is that a normal price? It sounds normal.",
			"Mmm, okay, I'll just put it on the joint account. He won't notice.",
		],
		"accept": [
			"Great! You seem trustworthy. My husband will be so relieved.",
			"Wonderful! I'll Venmo you. Does that work? Is that how this works?",
			"Thank you! You're a lifesaver. He's going to be SO mad but at least I have a car!",
		],
		"walk":   [
			"Actually my neighbour said I should get a second opinion…",
			"I'll just call my husband. He knows people.",
			"That sounds like a lot. I need to think about it.",
		],
		"budget_mul":  1.10,
		"haggle_step": 0.04,
		"opening_mul": 0.88,
		"patience":    2,
		"overcharge_immune": true,   # No rep penalty — she just doesn't know
		"persistent":       true,    # She's desperate — won't leave on first refusal
	},
	Personality.RICH_KID: {
		"label":  "💸  Rich Kid",
		"color":  Color(1.0, 0.88, 0.20),
		"names":  ["Sebastian", "Chandler", "Brayden", "Ashton", "Tristan"],
		"arrive": "A kid in designer clothes walks in, not looking up from his phone.",
		"greet":  [
			"Dad's paying, so whatever. Just make it quick.",
			"I need something for the summer. What've you got?",
			"My last car got keyed. Third time this year. Just… give me something.",
			"My allowance came in. How much for the whole lot?",
		],
		"low":    [
			"Yeah sure whatever.",
			"Is that a lot? My accountant says I spend too much anyway.",
			"Fine.",
		],
		"accept": [
			"Cool. Can you deliver it?",
			"Sure. Dad's card is in the car.",
			"Whatever, I'm already late.",
		],
		"walk":   [
			"Actually my friend said there's a nicer one in Monaco.",
			"I'll just get a new one. Never mind.",
		],
		"budget_mul":  1.80,
		"haggle_step": 0.0,
		"opening_mul": 0.92,
		"patience":    10,
		"auto_accepts": true,   # Accepts anything up to budget without countering
	},
	Personality.POOR_STUDENT: {
		"label":  "🎓  Broke Student",
		"color":  Color(0.45, 0.90, 0.55),
		"names":  ["Emma", "Jake", "Priya", "Luca", "Yuki", "Amir", "Faye"],
		"arrive": "A young person shuffles in, looking hopeful but nervous.",
		"greet":  [
			"Hi… I know it's not much but I really need to get to uni. Is there anything…?",
			"My bus pass expired and the train's too far. I don't have a lot but I'll pay what I can.",
			"Someone said you sometimes help people out. I don't know if that's true… but I need a car.",
			"I saved up all summer. It's not much. I just need something that works.",
		],
		"low":    [
			"I know, I know… I just don't have more than that.",
			"That's more than my monthly rent.",
			"Could you maybe… come down a bit? Please?",
		],
		"accept": [
			"Thank you so much! I'll take really good care of it.",
			"Oh my gosh. You have no idea how much this helps. Thank you.",
			"I'll pay you back someday. I mean it.",
		],
		"walk":   [
			"I understand. Thanks for your time.",
			"It's okay. I'll figure something out.",
			"Maybe I'll just bike. It's only 40km.",
		],
		"budget_mul":  0.30,
		"haggle_step": 0.03,
		"opening_mul": 0.90,
		"patience":    2,
		"gives_free_help": true,   # "Help for Free" button gives rep instead of money
		"persistent":      true,   # Desperate student — hard to turn away
	},
	Personality.RETIRED_MECHANIC: {
		"label":  "🔧  Retired Mechanic",
		"color":  Color(0.70, 0.85, 0.55),
		"names":  ["Frank", "Lou", "Gus", "Walter", "Roy", "Norm"],
		"arrive": "An older man walks in slowly, peers at the car, then squints at you.",
		"greet":  [
			"Son, I rebuilt engines before you were born. I know what this is worth.",
			"I don't want any nonsense. What's the real price?",
			"I've been fixing these since the eighties. Don't try to impress me.",
			"I was a master mechanic at Ford for thirty-two years. So. How much?",
		],
		"low":    [
			"You're having a laugh. I know what parts cost.",
			"That's 40% over blue book. I'm not stupid.",
			"Try again. The valve seals alone aren't worth what you're asking.",
		],
		"accept": [
			"Fair price. I can respect that.",
			"Good. Honest work deserves honest money.",
			"That's a deal I can shake hands on.",
		],
		"walk":   [
			"You're in the wrong business if that's your price.",
			"I'll check the auction. You should too.",
			"I didn't drive here to be insulted.",
		],
		"budget_mul":  0.98,
		"haggle_step": 0.0,
		"opening_mul": 0.94,
		"patience":    1,
		"honest_bonus": true,   # Fair price (within 5%) gives +5 rep bonus
	},
	Personality.SHADY_GUY: {
		"label":  "🕶️  Shady Character",
		"color":  Color(0.60, 0.55, 0.50),
		"names":  ["Vinny", "T-Bone", "Slick", "Milo", "The Dutchman"],
		"arrive": "Someone in sunglasses walks in, looks over their shoulder, then at the car.",
		"greet":  [
			"Nice place. You ask questions around here?",
			"I need a car. Fast. The asking price is fine. Let's not drag this out.",
			"Double the price, we forget I was here. Simple.",
			"My associate said you're discreet. The car — what do you want for it?",
		],
		"low":    [
			"I said don't ask questions. Just tell me the number.",
			"I've got cash. Lots of it. What's the price?",
			"I'm in a hurry. Name a number and we're done.",
		],
		"accept": [
			"Good. Pleasure. You didn't see me.",
			"Done. The car leaves now.",
			"Smart. We're all friends here.",
		],
		"walk":   [
			"Too complicated. I'll find another way.",
			"You don't know what you're missing. Shame.",
			"My people will find something. Enjoy your day.",
		],
		"budget_mul":  1.35,
		"haggle_step": 0.0,
		"opening_mul": 0.95,
		"patience":    10,
		"auto_accepts": true,
		"shady_deal":   true,
		"persistent":   true,   # Won't take no for an answer
	},

	# ── SERVICE CUSTOMERS ─────────────────────────────────────────────────────
	Personality.SERVICE_MOM: {
		"label":  "👩  Stressed Mum",
		"color":  Color(1.0, 0.70, 0.75),
		"names":  ["Claire", "Maria", "Deborah", "Susan", "Natalie", "Angela"],
		"arrive": "A frazzled woman rushes in, kids' drawings visible in her bag.",
		"greet":  [
			"I just need it fixed today — I've got school runs, football practice… please.",
			"The warning light came on and I panicked. My husband said you'd know what to do.",
			"It started making a horrible sound this morning. The kids were terrified.",
			"I don't know anything about cars. I just need it back as soon as possible.",
		],
		"low":    [
			"Is there any way to bring that down? School fees are due.",
			"That's more than I budgeted for. Can you do anything?",
			"I believe you, I just… it's a lot right now.",
		],
		"accept": [
			"Bless you. I'll be back to pick it up. Thank you so much.",
			"Perfect. You're a lifesaver. Genuinely.",
			"Okay! I'll walk to school today. Thank you!",
		],
		"walk":   [
			"I'll have to try somewhere else. Thank you for your time.",
			"Maybe my husband can fix it this weekend…",
			"That's too much right now. I'm sorry.",
		],
		"budget_mul":  1.10,
		"haggle_step": 0.06,
		"opening_mul": 1.0,
		"patience":    3,
		"is_service":       true,
		"service_budget_mul": 1.10,
		"service_rep_bonus":  5.0,
		"service_jobs":      ["fix_brakes", "fix_engine", "clean"],
		"service_vehicle":   "rustbucket_sedan",
	},
	Personality.SERVICE_COMMUTER: {
		"label":  "🚌  Impatient Commuter",
		"color":  Color(0.55, 0.80, 1.0),
		"names":  ["James", "Derek", "Kevin", "Aisha", "Pat", "Nadia"],
		"arrive": "Someone in a suit checks their watch before they've even finished walking in.",
		"greet":  [
			"It wouldn't start this morning. I've already missed a meeting. How fast can you fix it?",
			"I need it back TODAY. I have a presentation tomorrow.",
			"The engine light's on and it's running rough. Charge me what you need, just be quick.",
			"Whatever it is, just fix it. I can't afford to be car-less right now.",
		],
		"low":    [
			"Fine, fine. I'll pay it. Just get it done today.",
			"Can you guarantee it by end of day? Then deal.",
			"I don't have time to shop around. Can we make this quick?",
		],
		"accept": [
			"Great. I'll be back at 5. Don't let me down.",
			"Perfect. Here's my number — text me when it's done.",
			"Good. Get it done. I'll sort the payment when I return.",
		],
		"walk":   [
			"I'll take it somewhere faster. Sorry.",
			"Never mind, I'll rent a car.",
			"Too slow. I needed it yesterday.",
		],
		"budget_mul":  1.25,
		"haggle_step": 0.0,
		"opening_mul": 1.0,
		"patience":    1,
		"is_service":       true,
		"auto_accepts":     true,
		"service_budget_mul": 1.25,
		"service_rep_bonus":  3.0,
		"service_jobs":      ["fix_engine", "fix_brakes"],
		"service_vehicle":   "rustbucket_sedan",
	},
	Personality.SERVICE_ENTHUSIAST: {
		"label":  "🏁  Car Enthusiast",
		"color":  Color(0.40, 1.0, 0.65),
		"names":  ["Marco", "Stefan", "Alexei", "Rupert", "Chase", "Blake"],
		"arrive": "A guy in a racing jacket wanders in, immediately starts eyeing the tools.",
		"greet":  [
			"I want the full works. Engine, brakes, body — don't hold back.",
			"She's been sitting in the garage for two years. I want her back to her best.",
			"I've been saving for this. Do everything on your checklist.",
			"My dream is to drive her to the track this summer. What's that going to take?",
		],
		"low":    [
			"Come on, you said you could do it all. What's the full package?",
			"I want top quality parts. Charge me for them.",
			"If you do it right, I'll recommend you to everyone at the club.",
		],
		"accept": [
			"Brilliant! Take your time and do it properly.",
			"Perfect. I'll bring some snacks while I wait.",
			"Excellent. Call me when she's ready and I'll come running.",
		],
		"walk":   [
			"That's not quite what I had in mind. I'll look elsewhere.",
			"I want more done for that price. Ring me if you change your mind.",
		],
		"budget_mul":  1.40,
		"haggle_step": 0.0,
		"opening_mul": 1.0,
		"patience":    4,
		"is_service":       true,
		"auto_accepts":     true,
		"service_budget_mul": 1.40,
		"service_rep_bonus":  8.0,
		"service_jobs":      ["fix_engine", "fix_brakes", "fix_body", "fix_interior", "clean"],
		"service_vehicle":   "old_pickup",
	},
	Personality.SERVICE_PENSIONER: {
		"label":  "👴  Old Timer",
		"color":  Color(0.85, 0.78, 0.55),
		"names":  ["Harold", "Bernard", "Dennis", "Reg", "Clive", "Arthur"],
		"arrive": "An elderly man walks in slowly, hat in hand, looking around fondly.",
		"greet":  [
			"She's been in the family forty years. Just needs a bit of TLC.",
			"The old girl's started knocking. Nothing serious I hope. What do you reckon?",
			"My late wife and I drove this on our honeymoon. I'd like her running again.",
			"I don't want to get rid of her. I just want her running nice. Can you help?",
		],
		"low":    [
			"I'm on a pension, son. That's rather a lot for me.",
			"Could we maybe do the most important bits only?",
			"I've been coming past here for years. Can you do an old man a favour?",
		],
		"accept": [
			"Wonderful. I'll wait over there if that's alright.",
			"Lovely. You remind me of my son, you know.",
			"Very kind. I'll bring you a tin of biscuits when I pick her up.",
		],
		"walk":   [
			"I see. Well, thank you for your time, young man.",
			"I'll have a think. Maybe my grandson can take a look.",
			"Ah. That's a shame. Good day to you.",
		],
		"budget_mul":  0.80,
		"haggle_step": 0.05,
		"opening_mul": 1.0,
		"patience":    3,
		"is_service":       true,
		"service_budget_mul": 0.80,
		"service_rep_bonus":  12.0,   # Big rep reward for treating him fairly
		"service_jobs":      ["fix_engine", "fix_body"],
		"service_vehicle":   "classic_coupe",
	},
}

# ── Factory ───────────────────────────────────────────────────────────────────
## Alias for create_random_flip() — flip-sale buyers only.
static func create_random() -> Customer:
	return create_random_flip()

## Pick a random flip-sale buyer (does NOT include service types).
static func create_random_flip() -> Customer:
	var c := Customer.new()
	var flip_types : Array = [
		Personality.BUDGET_BUYER,    Personality.COLLECTOR,
		Personality.RESTORER,        Personality.FLIPPER,
		Personality.CLUELESS_WIFE,   Personality.RICH_KID,
		Personality.POOR_STUDENT,    Personality.RETIRED_MECHANIC,
		Personality.SHADY_GUY,
	]
	c.personality = flip_types[randi() % flip_types.size()]
	c._apply_personality_data()
	return c

## Pick a random walk-in service / repair customer.
static func create_random_service() -> Customer:
	var c := Customer.new()
	var svc_types : Array = [
		Personality.SERVICE_MOM,        Personality.SERVICE_COMMUTER,
		Personality.SERVICE_ENTHUSIAST, Personality.SERVICE_PENSIONER,
	]
	c.personality = svc_types[randi() % svc_types.size()]
	c._apply_personality_data()
	return c

static func create_type(p: Personality) -> Customer:
	var c := Customer.new()
	c.personality = p
	c._apply_personality_data()
	return c

func _apply_personality_data() -> void:
	var pdata : Dictionary = PERSONALITY_DATA[personality]
	var names : Array      = pdata["names"]
	display_name = names[randi() % names.size()]
	patience     = pdata.get("patience", 3)
	# Special flags (flip-sale)
	overcharge_immune = pdata.get("overcharge_immune", false)
	auto_accepts      = pdata.get("auto_accepts",      false)
	gives_free_help   = pdata.get("gives_free_help",   false)
	honest_bonus      = pdata.get("honest_bonus",      false)
	shady_deal        = pdata.get("shady_deal",        false)
	persistent        = pdata.get("persistent",        false)
	# Service fields
	is_service          = pdata.get("is_service",        false)
	service_jobs.assign(pdata.get("service_jobs",        []))
	service_vehicle_id  = pdata.get("service_vehicle",   "")
	service_budget_mult = pdata.get("service_budget_mul", 1.0)
	service_rep_bonus   = pdata.get("service_rep_bonus",  0.0)

# ── Negotiation ───────────────────────────────────────────────────────────────
func make_opening_offer(vehicle: VehicleData) -> int:
	var pdata : Dictionary = PERSONALITY_DATA[personality]
	var value : int        = vehicle.get_sell_value()
	var ratio : float      = pdata["budget_mul"] * pdata.get("opening_mul", 0.85)
	current_offer = int(value * ratio)
	budget        = int(value * pdata["budget_mul"])
	return current_offer

func counter_offer() -> int:
	if patience <= 0: return current_offer
	patience -= 1
	var pdata : Dictionary = PERSONALITY_DATA[personality]
	var step  : float      = pdata["haggle_step"]
	if step <= 0.0: return current_offer   # Doesn't budge
	current_offer = min(int(current_offer * (1.0 + step)), budget)
	return current_offer

func will_accept(asking: int) -> bool:
	return asking <= budget

func has_walked() -> bool:
	return patience <= 0

# ── Dialogue ──────────────────────────────────────────────────────────────────
func _pick(key: String) -> String:
	var pool : Array = PERSONALITY_DATA[personality][key]
	return pool[randi() % pool.size()]

func get_arrival_message() -> String:
	return PERSONALITY_DATA[personality]["arrive"]

func get_greeting() -> String:
	return _pick("greet")

func get_low_offer_comment() -> String:
	return _pick("low")

func get_accept_comment() -> String:
	return _pick("accept")

func get_walk_comment() -> String:
	return _pick("walk")

func get_personality_label() -> String:
	return PERSONALITY_DATA[personality]["label"]

func get_personality_color() -> Color:
	return PERSONALITY_DATA[personality]["color"]
