extends Panel


var players_user: Array


func _ready() -> void:
	Server.received_websocket_message.connect(_on_received_websocket_message)
	LoadingScreen.set_state(true, "Joining matchmaking...")
	await Server.connect_to_websocket("/match")
	LoadingScreen.set_state(true, "Waiting for an opponent...", "Cancel", _on_cancel_matchmaking_button_pressed)


func _on_received_websocket_message(message: Server.WebSocketMessage) -> void:
	if message.code == Server.WebSocketMessageCode.OPPONENT_FOUND:
		LoadingScreen.set_state(true, "Opponent found!")
		players_user = message.body["users"]
		var map: Node = load("res://screens/game/maps/%s/map.tscn" % message.body["map"]).instantiate()
		$Battle.add_child(map)
		var multiplayer_peer = ENetMultiplayerPeer.new()
		multiplayer_peer.create_client(Server.ADDRESS.get_slice(":", 0), message.body["port"])
		multiplayer.multiplayer_peer = multiplayer_peer


func _on_cancel_matchmaking_button_pressed() -> void:
	Server.close_current_websocket()
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu_screen.tscn")
	LoadingScreen.set_state(false)


@rpc("reliable")
func _start_game(peer_ids: PackedInt32Array):
	LoadingScreen.set_state(true, "Loading combat arena...")
	
	for i in len(peer_ids):
		var user_data: Dictionary = players_user[i]
		var player_data_node: Node = get_node("PlayersData/Player" + str(i))
		player_data_node.get_node("Username").text = user_data["username"]
		player_data_node.show()
		
		var player: Node = preload("res://screens/game/player/player.tscn").instantiate()
		var id: int = peer_ids[i]
		player.set_multiplayer_authority(id)
		player.name = str(id)
		player.sprite_frames_path = "res://screens/game/player/characters/%s/sprite_frames.tres"  %  user_data["character"]
		player.starts_looking_left = i % 2 == 1
		get_node("Battle/Map/SpawnPoints/Player" + str(i)).add_child(player)
	
	LoadingScreen.set_state(false)
