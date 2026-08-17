extends Node

## AudioManager Autoload — Handles background music (BGM) looping, delayed start, muting, and volume.
##
## ==============================================================================
## HOW TO CHANGE MUSIC VOLUME:
## Change `bgm_volume_db` below (in decibels):
##   0.0   = 100% (Full volume)
##  -6.0   = 50%  (Default recommended volume)
## -12.0   = 25%  (Quiet background volume)
## -80.0   = Mute
## ==============================================================================

var bgm_volume_db: float = -12.0
var is_muted: bool = false

var _player: AudioStreamPlayer
var _timer: SceneTreeTimer = null


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

	# Load background music stream (song.ogg)
	var stream: AudioStream = load("res://Asset/song.ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_player.stream = stream
	_player.volume_db = bgm_volume_db


func start_bgm_delayed(delay_seconds: float = 5.0) -> void:
	stop_bgm()
	_timer = get_tree().create_timer(delay_seconds)
	_timer.timeout.connect(_on_delay_timeout)


func _on_delay_timeout() -> void:
	if _player and _player.stream and not is_muted:
		_player.play()


func play_bgm() -> void:
	if _player and not _player.playing and not is_muted:
		_player.play()


func stop_bgm() -> void:
	if _player and _player.playing:
		_player.stop()


func toggle_mute() -> bool:
	set_muted(not is_muted)
	return is_muted


func set_muted(muted: bool) -> void:
	is_muted = muted
	if _player:
		_player.volume_db = -80.0 if is_muted else bgm_volume_db
		if is_muted:
			_player.stop()
		else:
			_player.play()


func set_volume_db(new_volume_db: float) -> void:
	bgm_volume_db = new_volume_db
	if _player and not is_muted:
		_player.volume_db = bgm_volume_db
