class_name AudioManager
extends Node

static var instance: AudioManager

var _player_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
const POOL_SIZE: int = 16

var sfx_rifle: AudioStreamWAV
var sfx_pistol: AudioStreamWAV
var sfx_aoe_shot: AudioStreamWAV
var sfx_knife: AudioStreamWAV
var sfx_explosion: AudioStreamWAV
var sfx_reload: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_headshot: AudioStreamWAV
var sfx_kamikaze_beep: AudioStreamWAV
var sfx_roll: AudioStreamWAV
var sfx_capture: AudioStreamWAV
var sfx_wind: AudioStreamWAV
var _ambient_wind_player: AudioStreamPlayer

func _init() -> void:
	instance = self

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_player_pool.append(p)
	
	_generate_all_sfx()

func _generate_all_sfx() -> void:
	sfx_rifle = _create_wav(0.12, func(t: float) -> float:
		var noise: float = randf_range(-1.0, 1.0) * exp(-t * 35.0)
		var punch: float = sin(2.0 * PI * 180.0 * exp(-t * 20.0) * t) * exp(-t * 25.0)
		return clampf(noise * 0.7 + punch * 0.5, -1.0, 1.0)
	)
	
	sfx_pistol = _create_wav(0.15, func(t: float) -> float:
		var noise: float = randf_range(-1.0, 1.0) * exp(-t * 28.0)
		var tone: float = sin(2.0 * PI * 240.0 * exp(-t * 15.0) * t) * exp(-t * 20.0)
		return clampf(noise * 0.8 + tone * 0.4, -1.0, 1.0)
	)

	sfx_aoe_shot = _create_wav(0.25, func(t: float) -> float:
		var boom: float = sin(2.0 * PI * 90.0 * exp(-t * 8.0) * t) * exp(-t * 10.0)
		var noise: float = randf_range(-1.0, 1.0) * exp(-t * 15.0)
		return clampf(boom * 0.7 + noise * 0.5, -1.0, 1.0)
	)

	sfx_knife = _create_wav(0.14, func(t: float) -> float:
		var tone: float = sin(2.0 * PI * 650.0 * t) * exp(-t * 22.0)
		var whoosh: float = randf_range(-0.4, 0.4) * sin(PI * t / 0.14)
		return clampf(tone * 0.6 + whoosh, -1.0, 1.0)
	)

	sfx_explosion = _create_wav(0.8, func(t: float) -> float:
		var boom: float = sin(2.0 * PI * 65.0 * exp(-t * 3.0) * t) * exp(-t * 4.0)
		var rumble: float = randf_range(-1.0, 1.0) * exp(-t * 5.0)
		return clampf(boom * 0.6 + rumble * 0.6, -1.0, 1.0)
	)

	sfx_reload = _create_wav(0.2, func(t: float) -> float:
		var click1: float = (1.0 if t > 0.02 and t < 0.05 else 0.0) * randf_range(-0.7, 0.7)
		var click2: float = (1.0 if t > 0.12 and t < 0.16 else 0.0) * sin(2.0 * PI * 800.0 * t)
		return clampf(click1 + click2, -1.0, 1.0)
	)

	sfx_hit = _create_wav(0.08, func(t: float) -> float:
		return sin(2.0 * PI * 130.0 * t) * exp(-t * 40.0) * 0.8
	)

	sfx_headshot = _create_wav(0.25, func(t: float) -> float:
		var ding: float = sin(2.0 * PI * 1250.0 * t) * exp(-t * 14.0)
		var chime: float = sin(2.0 * PI * 1750.0 * t) * exp(-t * 18.0)
		return (ding + chime) * 0.45
	)

	sfx_kamikaze_beep = _create_wav(0.12, func(t: float) -> float:
		return sin(2.0 * PI * 920.0 * t) * exp(-t * 12.0) * 0.6
	)

	sfx_roll = _create_wav(0.25, func(t: float) -> float:
		return randf_range(-0.5, 0.5) * sin(PI * t / 0.25)
	)

	sfx_capture = _create_wav(0.4, func(t: float) -> float:
		var freq: float = 440.0 + t * 400.0
		return sin(2.0 * PI * freq * t) * exp(-t * 4.0) * 0.5
	)

	sfx_wind = _create_wav(2.5, func(t: float) -> float:
		var tone: float = sin(2.0 * PI * (58.0 + sin(t * 2.5) * 18.0) * t) * 0.18
		var noise: float = randf_range(-0.25, 0.25) * (0.6 + 0.4 * sin(t * 3.0))
		return clampf(tone + noise, -1.0, 1.0)
	)
	sfx_wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sfx_wind.loop_begin = 0
	sfx_wind.loop_end = int(2.5 * 22050)

func start_ambient_wind(volume_db: float = -8.0) -> void:
	if _ambient_wind_player == null:
		_ambient_wind_player = AudioStreamPlayer.new()
		add_child(_ambient_wind_player)
	_ambient_wind_player.stream = sfx_wind
	_ambient_wind_player.volume_db = volume_db
	if not _ambient_wind_player.playing:
		_ambient_wind_player.play()

func stop_ambient_wind() -> void:
	if _ambient_wind_player and _ambient_wind_player.playing:
		_ambient_wind_player.stop()

func _create_wav(duration: float, formula: Callable) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2) # 16-bit mono
	
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var sample: float = formula.call(t)
		var val16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		if val16 < 0:
			val16 += 65536
		buffer[i * 2] = val16 & 0xFF
		buffer[i * 2 + 1] = (val16 >> 8) & 0xFF
		
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = buffer
	return stream

func play_sfx(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	if stream == null or _player_pool.is_empty():
		return
	var player := _player_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _player_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
