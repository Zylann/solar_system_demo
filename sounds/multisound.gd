
var _streams = []
var _players = []
var _player_round_index := 0
var _stream_round_index := 0


func set_streams(streams: Array):
	_streams = streams


func set_players(players: Array):
	_players = players


func play(pos := Vector3()):
	var player = _players[_player_round_index]
	_player_round_index += 1
	if _player_round_index == len(_players):
		_player_round_index = 0

	if player is AudioStreamPlayer3D:
		player.global_transform = Transform3D(Basis(), pos)

	var sound = _streams[_stream_round_index]
	_next_sound()
	if randf() > 0.5:
		_next_sound()
	player.stream = sound
	#print("Playing ", sound.resource_path)
	player.play()


func _next_sound():
	_stream_round_index += 1
	if _stream_round_index == len(_streams):
		_stream_round_index = 0


