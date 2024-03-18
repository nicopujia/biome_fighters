extends Panel


enum WebSocketsStatusCode { WS_GOING_AWAY = 1001 }
enum MatchMessageCode { OPPONENT_MATCHED, OPPONENT_DISCONNECTED }

@export var scenario_container: Node2D

var _my_player_number: int
var _scenario: int
var _opponent_user: User
var _websocket: WebSocketPeer = WebSocketPeer.new()


func _ready() -> void:
	multiplayer.multiplayer_peer = null
	
	ScreensManager.show_intermediate_screen("Joining matchmaking...")
	
	var connection_error := await _connect_to_matchmaking_websocket()
	
	if connection_error == OK:
		ScreensManager.show_intermediate_screen("Waiting for an opponent...", "Cancel", _cancel_matchmaking)
	else:
		ScreensManager.show_intermediate_screen(
			"Failed to connect to the matchmaking websocket due to an unknown reason. Error code: %d" % connection_error, 
			"Ok",
			ScreensManager.go_to_main_menu_screen,
		)


func _process(_delta: float) -> void:
	_websocket.poll()
	
	if _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	while _websocket.get_available_packet_count():
		var packet: PackedByteArray = _websocket.get_packet()
		_process_websocket_packet(packet)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_websocket.close(WebSocketsStatusCode.WS_GOING_AWAY, "The game window has been closed")


func _connect_to_matchmaking_websocket() -> Error:
	var match_token: Token = await API.request_match_access_token()
	if match_token.has_data:
		var url := API.build_url("ws", "matches/play", {"match_access_token": match_token.access_token})
		return _websocket.connect_to_url(url)
	return FAILED


func _cancel_matchmaking() -> void:
	ScreensManager.show_intermediate_screen("Cancelling...")
	if multiplayer.has_multiplayer_peer():
		return
	_websocket.close(WebSocketsStatusCode.WS_GOING_AWAY, "the matchmaking has been cancelled")
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	ScreensManager.hide()


func _process_websocket_packet(packet: PackedByteArray) -> void:
	var message: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	match int(message["code"]):
		MatchMessageCode.OPPONENT_MATCHED:
			_on_opponent_match(message)
		MatchMessageCode.OPPONENT_DISCONNECTED:
			_on_opponent_disconnection()


func _on_opponent_match(message: Dictionary) -> void:
	ScreensManager.show_intermediate_screen("Opponent found!")
	_my_player_number = message["your_player_number"]
	_scenario = message["scenario"]
	_opponent_user = User.new(message["opponent_user"])
	_connect_to_match_synchronizer(message["port"])
	ScreensManager.show_intermediate_screen("Loading combat...")


func _connect_to_match_synchronizer(port: int) -> void:
	var multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_client(API.HOST, port)
	multiplayer.connected_to_server.connect(_on_connected_to_match_synchronizer)
	multiplayer.multiplayer_peer = multiplayer_peer


func _on_connected_to_match_synchronizer() -> void:
	_register_player.rpc(_my_player_number)


func _on_opponent_disconnection() -> void:
	ScreensManager.show_intermediate_screen("Your opponent has disconnected. You win", "Accept", _on_accept_button_pressed)
	_websocket.close()


@rpc("reliable")
func _register_player(_player_number: int) -> void:
	pass # Only implemented on match synchronizer


@rpc("reliable")
func _start_match(players: Dictionary) -> void: # Called by match synchronizer when all players have connected
	var scenario: TileMap = load("res://screens/match/scenarios/desert/desert_scenario_%s.tscn" % _scenario).instantiate()
	
	for player_number in players:
		var username: String
		if player_number == _my_player_number:
			var current_user := await API.request_current_user()
			username = current_user.username 
		else:
			username = _opponent_user.username
			
		var peer_id: int = players[player_number]
		var player: Player = _create_player(username, player_number, peer_id)
		scenario.get_node("Player" + str(player_number)).add_child(player)
	
	scenario_container.add_child(scenario)
	scenario.global_position = scenario_container.global_position
	
	ScreensManager.hide()


func _create_player(username: String, player_number: int, peer_id: int) -> Player:
	var player: Player = preload("res://screens/match/player/player.tscn").instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.initial_looking_direction = -1 if player_number % 2 == 0 else 1
	player.health_changed.connect(_on_player_health_changed.bind(player_number))
	
	var player_data_node: PlayerData = _get_player_data_node(player_number)
	player_data_node.max_health = player.INITIAL_HEALTH
	player_data_node.health = player.INITIAL_HEALTH
	player_data_node.username = username
	
	return player


func _on_player_health_changed(value: float, player_number: int) -> void:
	_get_player_data_node(player_number).health = value
	
	if value > 0:
		return
	
	_finish_match.rpc(player_number)


func _get_player_data_node(player_number: int) -> PlayerData:
	return get_node("PlayersData/Player%s" % player_number)


@rpc("reliable", "call_local", "any_peer")
func _finish_match(loser_player_number: int) -> void:
	var player_has_lost: bool = loser_player_number == _my_player_number
	ScreensManager.show_intermediate_screen("You have " + ("lost" if player_has_lost else "won"), "Accept", _on_accept_button_pressed)
	_websocket.close()


func _on_accept_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
