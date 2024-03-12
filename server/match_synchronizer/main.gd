extends Node


const NEEDED_PLAYERS_AMOUNT: int = 2

var players: Dictionary


func _ready() -> void:
	var cmdline_args: Dictionary = {}
	for argument in OS.get_cmdline_args():
		if argument.contains("="):
			var key_value: PackedStringArray = argument.split("=")
			cmdline_args[key_value[0].lstrip("--")] = key_value[1]
		else:
			cmdline_args[argument.lstrip("--")] = true
	
	var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	multiplayer_peer.set_bind_ip("0.0.0.0")
	var error: Error = multiplayer_peer.create_server(int(cmdline_args["port"]), NEEDED_PLAYERS_AMOUNT)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.multiplayer_peer = multiplayer_peer
	printraw("\nMatch synchronizer server " + ("error " + str(error) if error else "successfully created"))


func _on_peer_disconnected(id: int) -> void:
	printraw("\nPeer %s has disconnected. Closing the server with exit code 1..." % id)
	multiplayer.multiplayer_peer.close()
	get_tree().quit(1)


@rpc("reliable", "any_peer")
func _register_player(player_number: int) -> void:
	players[player_number] = multiplayer.get_remote_sender_id()
	printraw("\nPlayer %s has been registered" % player_number)
	
	if len(players) == NEEDED_PLAYERS_AMOUNT:
		printraw("\nAll players have been registered. Starting the match...")
		_start_match.rpc(players)


@rpc("reliable")
func _start_match(players: Dictionary) -> void:
	for player_number in players:
		var player: Node = Node.new()
		player.name = str(players[player_number])
		player.add_child(MultiplayerSynchronizer.new())
		get_node("ScenarioContainer/Scenario/Player" + str(player_number)).add_child(player)
	
	printraw("\nThe match has started")


@rpc("reliable", "call_local", "any_peer")
func _finish_match(_loser_player_number: int) -> void:
	var player_number: int = players.find_key(multiplayer.get_remote_sender_id())
	players.erase(player_number)
	printraw("\nPlayer %s has finished." % [player_number])
	
	if players.is_empty():
		printraw("\nAll players have finished. Closing the server...")
		multiplayer.multiplayer_peer.close()
		get_tree().quit()
