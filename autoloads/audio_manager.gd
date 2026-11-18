extends Node
## Manages BGM, Ambience, and SFX safely even before audio files are placed in res://audio/.

var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _music_linear: float = 0.7
var _sfx_linear: float = 0.9
var _current_bgm_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_ambience_player = AudioStreamPlayer.new()
	add_child(_ambience_player)
	for _i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)


func apply_volumes(music_percent: float, sfx_percent: float) -> void:
	_music_linear = clampf(music_percent / 100.0, 0.0, 1.0)
	_sfx_linear = clampf(sfx_percent / 100.0, 0.0, 1.0)
	if _bgm_player != null:
		_bgm_player.volume_db = linear_to_db(maxf(_music_linear, 0.0001)) if _music_linear > 0.01 else -80.0
	if _ambience_player != null:
		_ambience_player.volume_db = linear_to_db(maxf(_music_linear * 0.75, 0.0001)) if _music_linear > 0.01 else -80.0
	for p in _sfx_pool:
		p.volume_db = linear_to_db(maxf(_sfx_linear, 0.0001)) if _sfx_linear > 0.01 else -80.0


func play_bgm(file_name: String) -> void:
	var path := "res://audio/bgm/" + file_name
	if _current_bgm_path == path and _bgm_player.playing:
		return
	_current_bgm_path = path
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			_bgm_player.stream = stream
			_bgm_player.play()
			return
	_bgm_player.stop()


func play_ambience(file_name: String) -> void:
	var path := "res://audio/ambience/" + file_name
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			if _ambience_player.stream != stream:
				_ambience_player.stream = stream
			if not _ambience_player.playing:
				_ambience_player.play()
			return
	_ambience_player.stop()


func play_sfx(file_name: String, pitch_variance: float = 0.0) -> void:
	if _sfx_linear <= 0.01:
		return
	var path := "res://audio/sfx/" + file_name
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var p := _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance) if pitch_variance > 0.0 else 1.0
	p.play()
