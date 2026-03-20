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
	var timer = node.get_tree().create_timer(0.1)
	timer.timeout.connect(func(): _play_tone(node, 1000.0, 0.06, _volume_db - 3.0))

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
	var t1 = node.get_tree().create_timer(0.12)
	t1.timeout.connect(func(): _play_tone(node, 800.0, 0.1, _volume_db - 4.0))
	var t2 = node.get_tree().create_timer(0.24)
	t2.timeout.connect(func(): _play_tone(node, 1000.0, 0.15, _volume_db - 4.0))

static func play_as400_key(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 400.0, 0.02, _volume_db - 10.0)

static func play_unload_warning(node: Node) -> void:
	if not _enabled: return
	_play_tone(node, 300.0, 0.1, _volume_db - 2.0)
	var t1 = node.get_tree().create_timer(0.15)
	t1.timeout.connect(func(): _play_tone(node, 250.0, 0.1, _volume_db - 2.0))

static func _play_tone(node: Node, freq: float, duration: float, volume: float) -> void:
	if node == null or not is_instance_valid(node): return
	
	var sample_rate = 22050.0
	var num_samples = int(sample_rate * duration)
	
	var audio_stream = AudioStreamWAV.new()
	audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
	audio_stream.mix_rate = int(sample_rate)
	audio_stream.stereo = false
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit = 2 bytes per sample
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		# Simple sine wave with envelope
		var envelope = 1.0
		var attack = 0.005
		var release = mini(duration * 0.3, 0.05)
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release
		
		var sample = sin(t * freq * TAU) * envelope
		var sample_int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		
		# Little-endian 16-bit
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	audio_stream.data = data
	
	var player = AudioStreamPlayer.new()
	player.stream = audio_stream
	player.volume_db = volume
	player.bus = "Master"
	node.add_child(player)
	player.play()
	
	# Auto-cleanup after playback
	player.finished.connect(func(): player.queue_free())
