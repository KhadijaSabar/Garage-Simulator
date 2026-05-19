## AudioManager.gd
## Autoload — synthesises all SFX in pure GDScript at startup.
## No external audio files needed. Streams are cached and reused.
## play()        — play a sound at default pitch
## play_varied() — play with randomised pitch (makes repeat sounds feel unique)
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────
const RATE      := 11025   ## Sample rate (Hz)
const POOL_SIZE := 12      ## Concurrent sounds allowed (bumped up from 8)

# ── State ─────────────────────────────────────────────────────────────────────
var _streams: Dictionary = {}
var _pool:    Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer = null
var sfx_enabled:     bool = true
var ambient_enabled: bool = true

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_player_pool()
	_build_all_streams()
	_start_ambient()
	_connect_signals()
	print("[AudioManager] Ready — %d streams, %d players." % [_streams.size(), POOL_SIZE])

# ── Public API ────────────────────────────────────────────────────────────────
func play(sound_id: String, volume_db: float = 0.0) -> void:
	if not sfx_enabled: return
	var stream: AudioStreamWAV = _streams.get(sound_id)
	if stream == null:
		push_warning("[AudioManager] Unknown sound: %s" % sound_id); return
	var player := _free_player()
	player.pitch_scale = 1.0
	player.stream      = stream
	player.volume_db   = volume_db
	player.play()

## Like play() but randomises pitch_scale in [pitch_min, pitch_max].
## Use for repair sounds, footsteps — keeps repeat SFX from sounding robotic.
func play_varied(sound_id: String, pitch_min: float = 0.88, pitch_max: float = 1.12,
				 volume_db: float = 0.0) -> void:
	if not sfx_enabled: return
	var stream: AudioStreamWAV = _streams.get(sound_id)
	if stream == null:
		push_warning("[AudioManager] Unknown sound: %s" % sound_id); return
	var player := _free_player()
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.stream      = stream
	player.volume_db   = volume_db
	player.play()

func set_sfx_volume(db: float) -> void:
	for p in _pool: p.volume_db = db

func set_ambient_volume(db: float) -> void:
	if _ambient: _ambient.volume_db = db

# ── Signal wiring ─────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	EconomyManager.money_changed.connect(_on_money_changed)
	OrderSystem.order_completed.connect(func(_o, _p): play("order_ok"))
	OrderSystem.order_expired.connect(func(_o):       play("error", -2.0))
	GameManager.day_started.connect(func(_d):         play("day_start", -8.0))
	ProgressionManager.tier_upgraded.connect(func(_t): play("tier_up", -4.0))

func _on_money_changed(_amount: int, delta: int) -> void:
	if delta > 500:    play("sell_car", -2.0)
	elif delta > 100:  play("cash")
	elif delta > 0:    play("cash", -6.0)
	elif delta < 0:    play("spend", -8.0)

# ── Stream construction ───────────────────────────────────────────────────────
func _build_all_streams() -> void:
	# ── Money ─────────────────────────────────────────────────────────────────
	# 💰 Cash register — ascending arpeggio (E, G#, B, E5)
	_streams["cash"]        = _arpeggio([330, 415, 494, 660], 0.10, 0.70)
	# 🪙 Light spend — short descending blip
	_streams["spend"]       = _arpeggio([330, 247], 0.07, 0.35)
	# 🚗💰 Big sale — sweeping win fanfare (used for sells > $500)
	_streams["sell_car"]    = _sell_fanfare()

	# ── Repair sounds — 6 variants, picked randomly + pitch-varied ────────────
	_streams["repair"]         = _noise_burst(0.14, 0.60, true)       # wrench grab
	_streams["repair_clang"]   = _clang(380.0, 0.22, 0.55)            # metal clang
	_streams["repair_ratchet"] = _ratchet(0.30, 14, 0.50)             # socket ratchet
	_streams["repair_impact"]  = _impact(0.18, 0.65)                  # hammer thud
	_streams["repair_grinder"] = _grinder(0.45, 0.52)                 # angle grinder
	_streams["repair_drill"]   = _drill(0.35, 0.48)                   # power drill

	# ── Cleaning ──────────────────────────────────────────────────────────────
	# 🧹 Clean spray — soft noise sweep
	_streams["clean"]       = _spray(0.40, 0.45)
	# 🎨 Paint spray — louder, longer, more pressurised hiss
	_streams["paint_spray"] = _paint_spray(0.70, 0.55)

	# ── Feedback / result ────────────────────────────────────────────────────
	# ✅ Order complete — bright 3-note win jingle
	_streams["order_ok"]    = _arpeggio([523, 659, 784, 1046], 0.13, 0.65)
	# ❌ Error / fail — low buzzer
	_streams["error"]       = _tone(140, 0.28, 0.55, "square")
	# 🤝 Negotiation accept — warm major chord swell
	_streams["neg_accept"]  = _chord_swell([523, 659, 784], 0.45, 0.55)
	# ❌ Negotiation refuse — descending two-tone bwamp
	_streams["neg_refuse"]  = _arpeggio([220, 156], 0.14, 0.60)

	# ── Events ────────────────────────────────────────────────────────────────
	# 🔔 Day start — crisp bell
	_streams["day_start"]   = _bell(880, 0.70, 0.50)
	# 🚀 Tier upgrade — triumphant 5-note fanfare
	_streams["tier_up"]     = _arpeggio([523, 587, 659, 784, 1047], 0.14, 0.72)
	# 🚨 Thief alarm — urgent alternating beeps
	_streams["alarm"]       = _alarm(0.60, 800.0, 1200.0, 0.10)
	# 🐕 Thief caught — positive two-tone blip
	_streams["caught"]      = _arpeggio([440, 660], 0.12, 0.60)

	# ── UI & interaction ──────────────────────────────────────────────────────
	# 🖱️ UI click — tiny tick
	_streams["click"]       = _noise_burst(0.035, 0.25, false)
	# 🟡 Zone E-key confirm — short confirm tick + brief tone
	_streams["zone_enter"]  = _zone_confirm()
	# 🛎️ Customer arrives — friendly door chime (two bells)
	_streams["customer_arrive"] = _door_chime()

	# ── Junkyard finds ───────────────────────────────────────────────────────
	# 💵 Cash find — bright coin jingle
	_streams["cash_find"]   = _cash_jingle()
	# ⭐ Rare find — triumphant shimmer fanfare
	_streams["rare_find"]   = _rare_shimmer()

	# ── Movement & ambience ───────────────────────────────────────────────────
	# 👣 Footstep — soft concrete thud
	_streams["footstep"]    = _footstep()
	# 🚗 Vehicle arrive — low engine rumble (short)
	_streams["engine"]      = _rumble(0.50, 80.0, 0.40)

# ── New synthesis functions ───────────────────────────────────────────────────

## Angle grinder — high-pitched whirring noise with slight freq wobble
func _grinder(dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		# Frequency-modulated high noise
		var freq: float = 3200.0 + sin(TAU * 18.0 * t) * 400.0
		var raw: float  = sin(TAU * freq * t) * 0.4
		raw += randf_range(-0.6, 0.6)
		# High-pass-ish: subtract a low-passed version
		prev = prev * 0.85 + raw * 0.15
		var s: float = (raw - prev) * vol
		# Envelope: ramp up fast, hold, ramp down
		var env: float = minf(float(i) / float(int(RATE * 0.04)), 1.0)
		env *= minf(float(n - i) / float(int(RATE * 0.08)), 1.0)
		s *= env
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Power drill — rapid mechanical buzz at mid frequency
func _drill(dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(RATE)
		# Sawtooth base at drill frequency (~280 Hz) + harmonics
		var s: float = 0.0
		for h: int in [1, 2, 3, 5]:
			s += sin(TAU * 280.0 * float(h) * t) / float(h)
		s *= 0.4
		# Rapid amplitude modulation (the "rr-rr-rr" effect at 40Hz)
		s *= 0.5 + 0.5 * abs(sin(TAU * 40.0 * t))
		s += randf_range(-0.05, 0.05)
		s *= vol
		var env: float = minf(float(i) / float(int(RATE * 0.03)), 1.0)
		env *= minf(float(n - i) / float(int(RATE * 0.06)), 1.0)
		s *= env
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Paint spray — longer pressurised hiss (more sibilant than clean spray)
func _paint_spray(dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var hp: float = 0.0   # high-pass state
	var lp: float = 0.0   # low-pass state
	for i in n:
		var raw: float = randf_range(-1.0, 1.0)
		lp = lp * 0.60 + raw * 0.40
		hp = raw - lp          # high-pass = signal minus low-pass
		# Swell: slow ramp up, hold, slow ramp down
		var env: float = sin(PI * float(i) / float(n))
		# Add intermittent "splatter" pulses
		var spatter: float = 0.0
		if fmod(float(i) / float(RATE), 0.07) < 0.015:
			spatter = randf_range(-0.3, 0.3)
		var s: float = (hp * 0.7 + spatter) * vol * env
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Big sell fanfare — short whoosh followed by a sparkling ascending run
func _sell_fanfare() -> AudioStreamWAV:
	var dur  := 0.90
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	# Ascending note sequence for the fanfare part
	var notes: Array = [523, 659, 784, 1047, 1319]
	var note_dur: float = 0.10
	var _note_n: int = int(RATE * note_dur)
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Whoosh (filtered noise sweep upward)
		if t < 0.30:
			var raw: float = randf_range(-1.0, 1.0)
			var freq_env: float = t / 0.30   # sweeps noise "brighter"
			s += raw * freq_env * 0.35 * (t / 0.30)
		# Arpeggio fanfare after the whoosh
		if t >= 0.25:
			var note_t: float = t - 0.25
			var note_idx: int = int(note_t / note_dur)
			if note_idx < notes.size():
				var local_t: float = fmod(note_t, note_dur)
				var freq: float = float(notes[note_idx])
				var decay: float = 1.0 - local_t / note_dur
				s += sin(TAU * freq * local_t) * 0.55 * decay
				s += sin(TAU * freq * 2.0 * local_t) * 0.18 * decay  # octave shimmer
		s *= 0.68
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Major chord swell — warm stacked sine waves (negotiation accept)
func _chord_swell(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float   = float(i) / float(RATE)
		var s: float   = 0.0
		for freq in freqs:
			s += sin(TAU * float(freq) * t) / float(freqs.size())
		var env: float = sin(PI * float(i) / float(n))  # swell up and back
		s *= vol * env
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Door chime — two bell strikes (high then lower)
func _door_chime() -> AudioStreamWAV:
	var dur  := 0.70
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(RATE)
		# First bell at t=0, second at t=0.22
		var s: float = 0.0
		var d1: float = exp(-7.0 * t / dur)
		s += sin(TAU * 1480.0 * t) * 0.55 * d1
		s += sin(TAU * 1480.0 * 2.76 * t) * 0.25 * d1
		if t >= 0.22:
			var t2: float  = t - 0.22
			var d2: float  = exp(-7.0 * t2 / (dur - 0.22))
			s += sin(TAU * 1175.0 * t2) * 0.50 * d2
			s += sin(TAU * 1175.0 * 2.76 * t2) * 0.22 * d2
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Zone E-key confirm — brief pitch click + short tone
func _zone_confirm() -> AudioStreamWAV:
	var dur  := 0.12
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = sin(TAU * 880.0 * t) * 0.5
		s += randf_range(-0.2, 0.2) * exp(-80.0 * t)   # initial click
		var decay: float = exp(-18.0 * t / dur)
		s *= 0.55 * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Cash find — bright coin jingle: three quick ascending tones with shimmer
func _cash_jingle() -> AudioStreamWAV:
	var dur  := 0.55
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	# Three coin-like bell strikes at 0.0, 0.12, 0.24 s
	var strikes: Array = [
		{"t": 0.00, "freq": 1047.0, "freq2": 2093.0},
		{"t": 0.12, "freq": 1319.0, "freq2": 2637.0},
		{"t": 0.24, "freq": 1568.0, "freq2": 3136.0},
	]
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		for st in strikes:
			if t >= st["t"]:
				var lt: float = t - float(st["t"])
				var decay: float = exp(-12.0 * lt)
				s += sin(TAU * float(st["freq"]) * lt) * 0.42 * decay
				s += sin(TAU * float(st["freq2"]) * lt) * 0.18 * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Rare find — sparkling 5-note shimmer: slow glittery ascending run with reverb tail
func _rare_shimmer() -> AudioStreamWAV:
	var dur  := 1.10
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes: Array = [
		{"t": 0.00, "freq": 659.0},
		{"t": 0.14, "freq": 784.0},
		{"t": 0.28, "freq": 988.0},
		{"t": 0.42, "freq": 1319.0},
		{"t": 0.56, "freq": 1568.0},
	]
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		for note in notes:
			if t >= float(note["t"]):
				var lt: float   = t - float(note["t"])
				var decay: float = exp(-5.5 * lt)
				var f: float    = float(note["freq"])
				s += sin(TAU * f * lt) * 0.38 * decay
				s += sin(TAU * f * 2.0 * lt) * 0.14 * decay   # octave shimmer
				# Subtle vibrato tail
				s += sin(TAU * f * lt + sin(TAU * 6.5 * lt) * 0.10) * 0.08 * decay
		# Star-dust sparkle (high noise transients)
		if fmod(t, 0.09) < 0.006:
			s += randf_range(-0.3, 0.3) * exp(-60.0 * fmod(t, 0.09))
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Footstep — soft low-frequency thud (concrete floor)
func _footstep() -> AudioStreamWAV:
	var dur  := 0.09
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = sin(TAU * 65.0 * t) * 0.45
		s += sin(TAU * 130.0 * t) * 0.20
		s += randf_range(-1.0, 1.0) * exp(-90.0 * t) * 0.55  # transient click
		var decay: float = exp(-30.0 * t / dur)
		s *= 0.62 * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

# ── Existing synthesis primitives (unchanged) ─────────────────────────────────

func _tone(freq: float, dur: float, vol: float,
		   wave: String = "sine", fade_out: bool = true) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		match wave:
			"sine":     s = sin(TAU * freq * t)
			"square":   s = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
			"sawtooth": s = 2.0 * fmod(freq * t, 1.0) - 1.0
			"noise":    s = randf_range(-1.0, 1.0)
		var attack: float = min(1.0, float(i) / float(max(1, int(RATE * 0.008))))
		var decay:  float = 1.0 - float(i) / float(n) if fade_out else 1.0
		s *= vol * attack * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _arpeggio(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_n := int(RATE * note_dur)
	var data   := PackedByteArray()
	data.resize(note_n * freqs.size() * 2)
	var offset := 0
	for freq in freqs:
		var f: float = float(freq)
		for i in note_n:
			var t: float    = float(i) / float(RATE)
			var fade: float = 1.0 - float(i) / float(note_n)
			var s: float    = sin(TAU * f * t) * vol * fade
			var s16: int    = int(clamp(s * 32767.0, -32768.0, 32767.0))
			data[offset * 2]     = s16 & 0xFF
			data[offset * 2 + 1] = (s16 >> 8) & 0xFF
			offset += 1
	return _wav(data)

func _noise_burst(dur: float, vol: float, with_click: bool) -> AudioStreamWAV:
	var n            := int(RATE * dur)
	var data         := PackedByteArray()
	data.resize(n * 2)
	var click_samples := int(RATE * 0.004)
	for i in n:
		var s: float = randf_range(-1.0, 1.0) * vol * (1.0 - float(i) / float(n))
		if with_click and i < click_samples:
			s += 0.7 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - float(i) / float(click_samples))
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _spray(dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev: float = 0.0
	for i in n:
		var raw: float = randf_range(-1.0, 1.0)
		prev = prev * 0.75 + raw * 0.25
		var env: float = sin(PI * float(i) / float(n))
		var s: float   = prev * vol * env
		var s16: int   = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _bell(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float     = float(i) / float(RATE)
		var s: float     = sin(TAU * freq * t) * 0.7
		s += sin(TAU * freq * 2.756 * t) * 0.3
		var decay: float = exp(-5.0 * t / dur)
		s *= vol * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _alarm(dur: float, freq_lo: float, freq_hi: float, period: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float    = float(i) / float(RATE)
		var freq: float = freq_hi if fmod(t, period) < period * 0.5 else freq_lo
		var s: float    = sin(TAU * freq * t) * 0.65
		var s16: int    = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _rumble(dur: float, base_freq: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float   = float(i) / float(RATE)
		var s: float   = sin(TAU * base_freq * t) * 0.5
		s += sin(TAU * base_freq * 3.0 * t) * 0.25
		s += sin(TAU * base_freq * 5.0 * t) * 0.12
		s += randf_range(-0.08, 0.08)
		var env: float = sin(PI * float(i) / float(n))
		s *= vol * env
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _clang(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float     = float(i) / float(RATE)
		var s: float     = sin(TAU * freq * t) * 0.6
		s += sin(TAU * freq * 2.41 * t) * 0.3
		s += sin(TAU * freq * 3.83 * t) * 0.1
		var decay: float = exp(-9.0 * t / dur)
		s *= vol * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _ratchet(dur: float, clicks: int, vol: float) -> AudioStreamWAV:
	var n              := int(RATE * dur)
	var data           := PackedByteArray()
	data.resize(n * 2)
	var click_interval: float = dur / float(clicks)
	var click_len: int        = int(RATE * 0.018)
	for i in n:
		var t: float     = float(i) / float(RATE)
		var phase: float = fmod(t, click_interval) / click_interval
		var s: float     = 0.0
		if phase < (float(click_len) / float(RATE)) / click_interval:
			var local: int = int(fmod(t, click_interval) * float(RATE))
			s = randf_range(-1.0, 1.0) * (1.0 - float(local) / float(click_len))
			s += sin(TAU * 900.0 * t) * 0.3
		s *= vol
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

func _impact(dur: float, vol: float) -> AudioStreamWAV:
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float     = float(i) / float(RATE)
		var s: float     = sin(TAU * 55.0 * t) * 0.5
		s += sin(TAU * 110.0 * t) * 0.25
		s += randf_range(-1.0, 1.0) * exp(-60.0 * t) * 0.8
		var decay: float = exp(-14.0 * t / dur)
		s *= vol * decay
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _wav(data)

## Improved ambient — warm garage hum with subtle ventilation layer (4s loop)
func _build_ambient() -> AudioStreamWAV:
	var dur  := 4.0
	var n    := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var vent_prev: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		# Mains hum + harmonics
		var s: float = sin(TAU * 60.0  * t) * 0.22
		s += sin(TAU * 120.0 * t) * 0.11
		s += sin(TAU * 180.0 * t) * 0.05
		# Ventilation/air layer (low-passed noise, slightly modulated)
		var raw: float = randf_range(-1.0, 1.0)
		vent_prev = vent_prev * 0.92 + raw * 0.08
		s += vent_prev * (0.06 + 0.02 * sin(TAU * 0.3 * t))
		var s16: int = int(clamp(s * 32767.0, -32768.0, 32767.0))
		data[i * 2]     = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := _wav(data)
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = n - 1
	return wav

# ── Helpers ───────────────────────────────────────────────────────────────────
func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s       := AudioStreamWAV.new()
	s.data      = data
	s.format    = AudioStreamWAV.FORMAT_16_BITS
	s.stereo    = false
	s.mix_rate  = RATE
	return s

func _build_player_pool() -> void:
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

func _start_ambient() -> void:
	_ambient           = AudioStreamPlayer.new()
	_ambient.volume_db = -20.0
	_ambient.bus       = "Master"
	add_child(_ambient)
	_ambient.stream = _build_ambient()
	_ambient.play()

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing: return p
	return _pool[0]
