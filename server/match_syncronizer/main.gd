extends Node


const REPLICATION_PROPERTIES = [
	"Player:position",
	"AnimatedSprite2D:animation",
	"AnimatedSprite2D:frame",
	"AnimatedSprite2D:flip_h",
]

var replication_config: SceneReplicationConfig = SceneReplicationConfig.new()
var connected_peer_ids: PackedInt32Array = []
var port: int


func _ready() -> void:
	_get_argurments()
	
	for property in REPLICATION_PROPERTIES:
		replication_config.add_property(property)
	
	var multiplayer_peer = ENetMultiplayerPeer.new()
	var error: Error = multiplayer_peer.create_server(port, 2)
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Server created at port %s with error %s" % [port, error])


func _get_argurments() -> void:
	var arguments: Dictionary = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			arguments[argument.lstrip("--")] = ""
	
	port = arguments.get("port", 50000)


func _on_peer_connected(new_peer_id : int) -> void:
	print("Peer %s is joining..." % new_peer_id)
	await get_tree().create_timer(1).timeout
	connected_peer_ids.append(new_peer_id)
	print("Peer %s joined" % new_peer_id)
	print("Currently connected peers: ", connected_peer_ids)
	
	if len(connected_peer_ids) == 2:
		print("Both peers have joined. Starting the game...")
		rpc("_start_game", connected_peer_ids)


func _on_peer_disconnected(id: int) -> void:
	connected_peer_ids.remove_at(connected_peer_ids.find(id))
	print("Peer %s disconnected" % id)
	print("Currently connected peers: ", connected_peer_ids)


@rpc("reliable")
func _start_game(peer_ids: PackedInt32Array):
	for i in len(peer_ids):
		get_node("Battle/Map/SpawnPoints/Player" + str(i)).add_child(_create_player(peer_ids[i]))


func _create_player(id: int) -> Node:
	var syncronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	syncronizer.replication_config = replication_config
	syncronizer.set_multiplayer_authority(id)
	
	var player: Node = Node.new()
	player.name = str(id)
	player.add_child(syncronizer)
	return player
