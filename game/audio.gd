extends Node
## Plays sound effects by name from res://audio/sfx/<name>.wav, through a small pool of
## players so overlapping sounds don't cut each other off.

const SFX_DIR := "res://audio/sfx/"
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
# Headless runs (tests) use a dummy audio driver that never finishes a sound, so every sound
# would linger until exit and be reported as leaked. Stay silent there.
var _silent := AudioServer.get_driver_name() == "Dummy"


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


# A sound still playing when the game quits would otherwise be reported as leaked.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null


## Play a sound. `pitch_jitter` varies the pitch a little so repeats don't sound identical.
func play(sound: StringName, volume_db := 0.0, pitch_jitter := 0.05) -> void:
	if _silent:
		return
	var stream := _stream(sound)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var path := SFX_DIR + String(sound) + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]
