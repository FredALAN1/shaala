extends Node
## Procedural audio & ambience manager for SHAALA (شعلة).
## Generates melancholic desert wind + Hijaz-scale oud pluck placeholders and lightweight SFX.
## Fully guarded against headless or dummy-driver execution.

const SAMPLE_RATE: int = 22050
const SFX_POOL_SIZE: int = 8

# Hijaz-inspired frequencies (Hz) around D3 / A3 for desert ambience.
const OUD_SCALE_HZ: Array = [
	146.83, 155.56, 185.00, 196.00, 220.00, 233.08, 277.18, 293.66
]

var _audio_enabled: bool = false
var _current_mood: String = "title"
var _wind_player: AudioStreamPlayer = null
var _wind_playback: AudioStreamGeneratorPlayback = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _sfx_bank: Dictionary = {}

# Procedural desert wind & oud synthesis state.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wind_filter_state: float = 0.0
var _wind_lfo_phase: float = 0.0
var _oud_phase: float = 0.0
var _oud_freq: float = 146.83
var _oud_env: float = 0.0
var _oud_timer: float = 2.4
var _wind_gain: float = 0.08
var _oud_interval_min: float = 3.2
var _oud_interval_max: float = 6.5
var _ambient_buffer: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_buses()
	_audio_enabled = _can_output_audio()

	if _audio_enabled:
		_setup_sfx_pool()
		_build_placeholder_sfx_bank()
		_setup_ambient_generator()

	SettingsManager.apply_audio_volumes()

	EventBus.room_loaded.connect(_on_room_loaded)
	EventBus.boss_encounter_started.connect(_on_boss_encounter_started)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.shrine_rested.connect(_on_shrine_rested)
	EventBus.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if not _audio_enabled or _wind_playback == null:
		return
	if _current_mood == "silent":
		return
	_oud_timer -= delta
	if _oud_timer <= 0.0:
		_trigger_ambient_oud_note()
		_oud_timer = _rng.randf_range(_oud_interval_min, _oud_interval_max)
	_fill_ambient_buffer()


func play_sfx(sfx_id: String) -> void:
	if not _audio_enabled or _sfx_players.is_empty():
		return
	var stream: AudioStreamWAV = _sfx_bank.get(sfx_id, _sfx_bank.get("ui_click")) as AudioStreamWAV
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = _rng.randf_range(0.96, 1.04)
	player.play()


func set_music_mood(mood: String) -> void:
	_current_mood = mood
	match mood:
		"title":
			_wind_gain = 0.085
			_oud_interval_min = 3.5
			_oud_interval_max = 6.5
		"desert_camp":
			_wind_gain = 0.10
			_oud_interval_min = 3.0
			_oud_interval_max = 6.0
		"empty_highway":
			_wind_gain = 0.12
			_oud_interval_min = 4.0
			_oud_interval_max = 7.5
		"empty_riyadh":
			_wind_gain = 0.09
			_oud_interval_min = 2.8
			_oud_interval_max = 5.5
		"boss":
			_wind_gain = 0.13
			_oud_interval_min = 1.1
			_oud_interval_max = 2.2
		"vignette":
			_wind_gain = 0.04
			_oud_interval_min = 2.2
			_oud_interval_max = 4.0
		"silent":
			_wind_gain = 0.0
		_:
			_wind_gain = 0.08
			_oud_interval_min = 3.5
			_oud_interval_max = 6.5


func _can_output_audio() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if AudioServer.get_mix_rate() <= 0.0:
		return false
	return true


func _ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_sfx_pool() -> void:
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


func _setup_ambient_generator() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = float(SAMPLE_RATE)
	gen.buffer_length = 0.25

	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "AmbientDesertPlayer"
	_wind_player.bus = "Music"
	_wind_player.stream = gen
	add_child(_wind_player)
	_wind_player.play()
	_wind_playback = _wind_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _trigger_ambient_oud_note() -> void:
	var note_idx: int = _rng.randi_range(0, OUD_SCALE_HZ.size() - 1)
	_oud_freq = OUD_SCALE_HZ[note_idx]
	_oud_env = 0.22 if _current_mood != "boss" else 0.30


func _fill_ambient_buffer() -> void:
	var frames_available: int = _wind_playback.get_frames_available()
	if frames_available <= 0:
		return
	var inv_sr: float = 1.0 / float(SAMPLE_RATE)
	# Fill one batch and hand it to the engine in a single push_buffer() call
	# instead of ~22k push_frame() calls per second.
	if _ambient_buffer.size() != frames_available:
		_ambient_buffer.resize(frames_available)
	for i: int in range(frames_available):
		# Soft low-pass filtered desert wind with slow gust swell.
		var white: float = _rng.randf_range(-1.0, 1.0)
		_wind_filter_state += (white - _wind_filter_state) * 0.035
		_wind_lfo_phase = fmod(_wind_lfo_phase + 0.14 * inv_sr, 1.0)
		var gust: float = 0.65 + 0.35 * sin(_wind_lfo_phase * TAU)
		var sample: float = _wind_filter_state * _wind_gain * gust

		# Subtle warm oud pluck harmonic overlay.
		if _oud_env > 0.0005:
			_oud_phase = fmod(_oud_phase + _oud_freq * inv_sr, 1.0)
			var fundamental: float = sin(_oud_phase * TAU)
			var harmonic2: float = 0.35 * sin(_oud_phase * TAU * 2.0)
			var harmonic3: float = 0.12 * sin(_oud_phase * TAU * 3.0)
			sample += (fundamental + harmonic2 + harmonic3) * _oud_env * 0.45
			_oud_env *= 0.99975

		sample = clampf(sample, -0.8, 0.8)
		_ambient_buffer[i] = Vector2(sample, sample)
	_wind_playback.push_buffer(_ambient_buffer)


func _build_placeholder_sfx_bank() -> void:
	_sfx_bank["dagger_swing"] = _make_noise_sweep_wav(0.11, 0.28, 0.18)
	_sfx_bank["dagger_hit"] = _make_tone_wav(220.0, 95.0, 0.12, 0.42, true)
	_sfx_bank["spell_cast"] = _make_tone_wav(520.0, 260.0, 0.22, 0.34, true)
	_sfx_bank["parry_success"] = _make_chime_wav(660.0, 990.0, 0.28, 0.45)
	_sfx_bank["parry_whiff"] = _make_tone_wav(240.0, 190.0, 0.09, 0.22, false)
	_sfx_bank["dash"] = _make_noise_sweep_wav(0.16, 0.32, 0.25)
	_sfx_bank["jump"] = _make_tone_wav(190.0, 340.0, 0.10, 0.24, false)
	_sfx_bank["land"] = _make_tone_wav(120.0, 65.0, 0.08, 0.26, true)
	_sfx_bank["player_hurt"] = _make_tone_wav(180.0, 75.0, 0.22, 0.46, true)
	_sfx_bank["player_death"] = _make_tone_wav(220.0, 55.0, 0.45, 0.48, false)
	_sfx_bank["enemy_hurt"] = _make_tone_wav(260.0, 140.0, 0.10, 0.34, true)
	_sfx_bank["enemy_death"] = _make_tone_wav(210.0, 70.0, 0.26, 0.40, true)
	_sfx_bank["boss_roar"] = _make_tone_wav(130.0, 62.0, 0.48, 0.50, true)
	_sfx_bank["shrine_rest"] = _make_chime_wav(293.66, 440.0, 0.45, 0.36)
	_sfx_bank["orb_collect"] = _make_chime_wav(392.0, 587.33, 0.48, 0.40)
	_sfx_bank["page_collect"] = _make_noise_sweep_wav(0.14, 0.22, 0.35)
	_sfx_bank["shortcut_open"] = _make_tone_wav(146.83, 293.66, 0.35, 0.38, false)
	_sfx_bank["time_shift"] = _make_chime_wav(440.0, 293.66, 0.42, 0.40)
	_sfx_bank["grey_eye"] = _make_chime_wav(311.13, 466.16, 0.30, 0.32)
	_sfx_bank["ui_click"] = _make_tone_wav(480.0, 360.0, 0.05, 0.20, false)
	_sfx_bank["ui_hover"] = _make_tone_wav(560.0, 520.0, 0.04, 0.12, false)
	_sfx_bank["ui_talk"] = _make_tone_wav(320.0, 290.0, 0.07, 0.18, false)
	_sfx_bank["camel_grunt"] = _make_tone_wav(115.0, 82.0, 0.28, 0.26, true)


func _make_tone_wav(start_hz: float, end_hz: float, duration: float, gain: float, add_grit: bool) -> AudioStreamWAV:
	var frame_count: int = maxi(int(duration * float(SAMPLE_RATE)), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count * 2)
	var phase: float = 0.0
	for i: int in range(frame_count):
		var t: float = float(i) / float(frame_count)
		var hz: float = lerpf(start_hz, end_hz, t)
		phase += hz / float(SAMPLE_RATE)
		var env: float = pow(1.0 - t, 1.8) * minf(t * 25.0, 1.0)
		var sample: float = sin(phase * TAU)
		if add_grit:
			sample = sample * 0.75 + _rng.randf_range(-0.25, 0.25)
		var pcm: int = clampi(int(sample * env * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, pcm)
	return _pack_wav(data)


func _make_chime_wav(hz_a: float, hz_b: float, duration: float, gain: float) -> AudioStreamWAV:
	var frame_count: int = maxi(int(duration * float(SAMPLE_RATE)), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count * 2)
	var inv_sr: float = 1.0 / float(SAMPLE_RATE)
	for i: int in range(frame_count):
		var t: float = float(i) / float(frame_count)
		var sec: float = float(i) * inv_sr
		var env: float = pow(1.0 - t, 2.0) * minf(t * 40.0, 1.0)
		var sample: float = 0.6 * sin(sec * hz_a * TAU) + 0.4 * sin(sec * hz_b * TAU)
		var pcm: int = clampi(int(sample * env * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, pcm)
	return _pack_wav(data)


func _make_noise_sweep_wav(duration: float, gain: float, smoothing: float) -> AudioStreamWAV:
	var frame_count: int = maxi(int(duration * float(SAMPLE_RATE)), 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count * 2)
	var lp: float = 0.0
	for i: int in range(frame_count):
		var t: float = float(i) / float(frame_count)
		var env: float = sin(t * PI)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * smoothing
		var pcm: int = clampi(int(lp * env * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, pcm)
	return _pack_wav(data)


func _pack_wav(pcm_bytes: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm_bytes
	return wav


func _on_room_loaded(_room_id: String, area_id: String, _room_title_key: String) -> void:
	set_music_mood(area_id)


func _on_boss_encounter_started(_boss_id: String, _name_key: String, _max_hp: int) -> void:
	set_music_mood("boss")
	play_sfx("boss_roar")


func _on_boss_defeated(_boss_id: String) -> void:
	set_music_mood("empty_riyadh")


func _on_shrine_rested(_shrine_id: String, _room_id: String) -> void:
	play_sfx("shrine_rest")


func _on_settings_changed() -> void:
	SettingsManager.apply_audio_volumes()
