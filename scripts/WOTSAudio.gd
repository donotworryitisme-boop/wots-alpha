extends Node
class_name WOTSAudio

# Procedural audio system for WOTS
# All sounds generated in GDScript — no external files needed
# Toggle-able via _enabled flag

static var _enabled: bool = true
static var _volume_db: float = -12.0

static func set_enabled(enabled: bool) -> void:
	_enabled = enabled

static func play_scan_beep(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 1200.0, 0.08, _volume_db)

static func play_load_confirm(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 800.0, 0.06, _volume_db - 3.0)
	# Second tone slightly delayed for a "bip-bip" feel
	var timer: SceneTreeTimer = node.get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void: _play_tone(node, 1000.0, 0.06, _volume_db - 3.0))

static func play_error_buzz(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 200.0, 0.15, _volume_db - 2.0)

static func play_panel_click(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 600.0, 0.03, _volume_db - 8.0)

static func play_seal_confirm(node: Node) -> void:
	if not _enabled: return
	# Rising three-tone confirmation
	_play_tone(node, 600.0, 0.1, _volume_db - 4.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.12)
	t1.timeout.connect(func() -> void: _play_tone(node, 800.0, 0.1, _volume_db - 4.0))
	var t2: SceneTreeTimer = node.get_tree().create_timer(0.24)
	t2.timeout.connect(func() -> void: _play_tone(node, 1000.0, 0.15, _volume_db - 4.0))

static func play_as400_key(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 400.0, 0.02, _volume_db - 10.0)

static func play_unload_warning(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 300.0, 0.1, _volume_db - 2.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.15)
	t1.timeout.connect(func() -> void: _play_tone(node, 250.0, 0.1, _volume_db - 2.0))


static func play_phone_ring(node: Node) -> void:
	if not _enabled: return
	# Three ascending tones — phone call incoming
	_play_tone(node, 523.0, 0.12, _volume_db - 4.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.15)
	t1.timeout.connect(func() -> void: _play_tone(node, 659.0, 0.12, _volume_db - 4.0))
	var t2: SceneTreeTimer = node.get_tree().create_timer(0.30)
	t2.timeout.connect(func() -> void: _play_tone(node, 784.0, 0.15, _volume_db - 4.0))


static func play_undo_confirm(node: Node) -> void:
	if not _enabled: return
	# Descending two-tone — undo action
	_play_tone(node, 800.0, 0.08, _volume_db - 4.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.1)
	t1.timeout.connect(func() -> void: _play_tone(node, 500.0, 0.1, _volume_db - 4.0))


static func play_success_chime(node: Node) -> void:
	if not _enabled: return
	# Four-note ascending major chord — scenario complete
	_play_tone(node, 523.0, 0.15, _volume_db - 3.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.15)
	t1.timeout.connect(func() -> void: _play_tone(node, 659.0, 0.15, _volume_db - 3.0))
	var t2: SceneTreeTimer = node.get_tree().create_timer(0.30)
	t2.timeout.connect(func() -> void: _play_tone(node, 784.0, 0.15, _volume_db - 3.0))
	var t3: SceneTreeTimer = node.get_tree().create_timer(0.50)
	t3.timeout.connect(func() -> void: _play_tone(node, 1047.0, 0.25, _volume_db - 2.0))


static func play_dock_open(node: Node) -> void:
	## Mechanical rumble + clunk — dock leveler opening.
	if not _enabled: return
	_play_tone(node, 120.0, 0.18, _volume_db - 3.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.12)
	t1.timeout.connect(func() -> void: _play_tone(node, 180.0, 0.12, _volume_db - 5.0))
	var t2: SceneTreeTimer = node.get_tree().create_timer(0.28)
	t2.timeout.connect(func() -> void: _play_tone(node, 95.0, 0.06, _volume_db - 1.0))


static func play_dock_close(node: Node) -> void:
	## Heavier clunk — dock leveler closing.
	if not _enabled: return
	_play_tone(node, 90.0, 0.08, _volume_db - 1.0)
	var t1: SceneTreeTimer = node.get_tree().create_timer(0.1)
	t1.timeout.connect(func() -> void: _play_tone(node, 140.0, 0.15, _volume_db - 4.0))
	var t2: SceneTreeTimer = node.get_tree().create_timer(0.22)
	t2.timeout.connect(func() -> void: _play_tone(node, 100.0, 0.1, _volume_db - 6.0))


static func play_emballage_click(node: Node) -> void:
	## Quick tick — removing an empty pallet from the truck.
	if not _enabled: return
	_play_tone(node, 450.0, 0.04, _volume_db - 6.0)


static func _play_tone(node: Node, freq: float, duration: float, volume: float) -> void:
	if node == null or not is_instance_valid(node): return

	var sample_rate: float = 22050.0
	var num_samples: int = int(sample_rate * duration)

	var audio_stream: AudioStreamWAV = AudioStreamWAV.new()
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = int(sample_rate)
	audio_stream.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit = 2 bytes per sample

	for i: int in range(num_samples):
		var t: float = float(i) / sample_rate
		# Simple sine wave with envelope
		var envelope: float = 1.0
		var attack: float = 0.005
		var release: float = minf(duration * 0.3, 0.05)
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release

		var sample: float = sin(t * freq * TAU) * envelope
		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767.0)

		# Little-endian 16-bit
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio_stream.data = data

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = audio_stream
	player.volume_db = volume
	player.bus = "Master"
	node.add_child(player)
	player.play()

	# Auto-cleanup after playback
	player.finished.connect(func() -> void: player.queue_free())
