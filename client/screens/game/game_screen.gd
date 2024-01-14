extends Panel


enum WebSocketsStatusCode { WS_GOING_AWAY = 1001 }
enum MatchMessageCode { OPPONENT_FOUND, OPPONENT_LEFT }

@export var map_container: Panel

var _my_player_number: int
var _opponent_user: Server.User
var _websocket: WebSocketPeer = WebSocketPeer.new()


func _ready() -> void:
	multiplayer.multiplayer_peer = null
	
	LoadingScreen.communicate("Joining matchmaking...")
	
	var token_response: Server.HTTPResponse = await Server.request("/match-token", {}, HTTPClient.METHOD_POST)
	
	if token_response.status_code != HTTPClient.RESPONSE_CREATED or token_response.result != HTTPRequest.RESULT_SUCCESS:
		LoadingScreen.communicate(
			"Unexpected error occurred with result %s, status code %s" % [token_response.result, token_response.status_code], 
			"Accept", 
			_on_accept_button_pressed
		)
		return
	
	_websocket.connect_to_url(Server.build_url("ws", "/match", {"access_token": token_response.body["access_token"]}))
	
	LoadingScreen.communicate("Waiting for an opponent...", "Cancel", _on_cancel_matchmaking_button_pressed)


func _process(_delta: float) -> void:
	_websocket.poll()
	
	if _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var packet: PackedByteArray = _websocket.get_packet()
	
	if not packet:
		return
	
	var message: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
	
	match int(message["code"]):
		MatchMessageCode.OPPONENT_LEFT:
			LoadingScreen.communicate("Your opponent has disconnected. You win", "Accept", _on_accept_button_pressed)
			_websocket.close()
		MatchMessageCode.OPPONENT_FOUND:
			LoadingScreen.communicate("Opponent found!")
			
			_my_player_number = message["your_player_number"]
			_opponent_user = Server.User.new(message["opponent_user"])
			
			var multiplayer_peer = ENetMultiplayerPeer.new()
			multiplayer_peer.create_client(Server.HOST, message["port"])
			multiplayer.connected_to_server.connect(func(): _register_player.rpc(_my_player_number))
			multiplayer.multiplayer_peer = multiplayer_peer
			
			LoadingScreen.communicate("Loading combat...")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_websocket.close(WebSocketsStatusCode.WS_GOING_AWAY, "the game window has been closed")


@rpc("reliable")
func _register_player(_player_number: int) -> void:
	pass # Only implemented on server


@rpc("reliable")
func _start_game(players: Dictionary) -> void:
	var map: Node2D = preload("res://screens/game/maps/desert/desert_map_1.tscn").instantiate()
	
	for player_number in players:
		var peer_id: int = players[player_number]
		var player: Player = preload("res://screens/game/player/player.tscn").instantiate()
		player.name = str(peer_id)
		player.set_multiplayer_authority(peer_id)
		player.initial_looking_direction = -1 if player_number % 2 == 0 else 1
		player.health_changed.connect(_on_player_health_changed.bind(player_number))
		map.get_node("SpawnPoints/Player" + str(player_number)).add_child(player)
		
		var player_data_node: PlayerData = _get_player_data_node(player_number)
		player_data_node.max_health = Player.INITIAL_HEALTH
		player_data_node.health = Player.INITIAL_HEALTH
		player_data_node.username = Server.me.username if player_number == _my_player_number else _opponent_user["username"]
	
	map_container.add_child(map)
	
	LoadingScreen.hide()


@rpc("reliable", "call_local", "any_peer")
func _finish_game(loser_player_number: int) -> void:
	var player_has_lost: bool = loser_player_number == _my_player_number
	LoadingScreen.communicate("You have " + ("lost" if player_has_lost else "won"), "Accept", _on_accept_button_pressed)
	_websocket.close()


func _get_player_data_node(player_number: int) -> PlayerData:
	return get_node("PlayersData/Player%s" % player_number)


func _on_player_health_changed(value: float, player_number: int) -> void:
	_get_player_data_node(player_number).health = value
	
	if value > 0:
		return
	
	_finish_game.rpc(player_number)


func _on_cancel_matchmaking_button_pressed() -> void:
	LoadingScreen.communicate("Cancelling...")
	if multiplayer.has_multiplayer_peer():
		return
	_websocket.close(WebSocketsStatusCode.WS_GOING_AWAY, "the matchmaking has been cancelled")
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	LoadingScreen.hide()


func _on_accept_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
