extends Panel


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/game/game_screen.tscn")


# WEBRTC IMPLEMENTATION (not working for Android armeabi-v7a):
#
#enum MessageCode { OPPONENT_FOUND, SESSION_DESCRIPTION, ICE_CANDIDATE }
#const SERVER_DOMAIN = "multiplayergame-w50r9w5q.b4a.run"
#var _username: String
#var _socket := WebSocketPeer.new()
#var _peer := WebRTCPeerConnection.new()
#var _channel: WebRTCDataChannel
#var _match_id: int
#var _socket_is_open: bool = false
#
#
#func _ready() -> void:
#	_peer.initialize({
#		"iceServers": [
#			{ "urls": [ "stun:stun.relay.metered.ca:80" ] },
#			{
#				"urls": [
#					"turn:a.relay.metered.ca:80",
#					"turn:a.relay.metered.ca:80?transport=tcp",
#					"turn:a.relay.metered.ca:443",
#					"turn:a.relay.metered.ca:443?transport=tcp"
#				],
#				"username": "d5886ea39dd1a8dfac78fb15",
#				"credential": "DtgaCMq3Rw3NGdmB",
#			},
#		],
#	})
#	_peer.session_description_created.connect(_on_session_description_created)
#	_peer.ice_candidate_created.connect(_on_ice_candidate_created)
#
#
#func _on_username_input_text_changed(new_text: String) -> void:
#	_username = new_text
#	%HomeScreen/PlayButton.disabled = _username.is_empty() or _username == null
#
#
#func _on_play_button_pressed() -> void:
#	var url: String = "wss://%s/%s/match" % [SERVER_DOMAIN, _username]
#	var error: Error = _socket.connect_to_url(url)
#	print("%s connected to url %s with error %s" % [_username, url, error])
#	_socket_is_open = true
#	%HomeScreen/ErrorMessage.text = ""
#	_set_screen_visible(%MatchmakdgScreen)
#
#
#
#func _on_cancel_button_pressed() -> void:
#	_socket.close(1001, "Matchmaking cancelled")
#
#
#func _process(_delta: float) -> void:
#	if _socket_is_open:
#		_poll_socket()
#
#		if _channel:
#			_poll_peer()
#
#
#func _poll_socket() -> void:
#	_socket.poll()
#	match _socket.get_ready_state():
#		WebSocketPeer.STATE_OPEN:
#			while _socket.get_available_packet_count():
#				_process_socket_packet(_socket.get_packet())
#
#		WebSocketPeer.STATE_CLOSING:
#			pass # Keep polling for a proper close
#
#		WebSocketPeer.STATE_CLOSED:
#			_socket_is_open = false
#			var code: int = _socket.get_close_code()
#			var reason: String = _socket.get_close_reason()
#			%HomeScreen/ErrorMessage.text = reason
#			_set_screen_visible(%HomeScreen)
#			print("%s closed the connection with code '%s', reason '%s'" % [_username, code, reason])
#
#
#func _process_socket_packet(packet: PackedByteArray) -> void:
#	var string: String = packet.get_string_from_utf8()
#	var json: Dictionary = JSON.parse_string(string) as Dictionary
#	var data = json["data"]
#	print("%s received a packet: %s" % [_username, json])
#	match json["code"] as int:
#		MessageCode.OPPONENT_FOUND:
#			%MatchmakingScreen/Label.text = "Establishing peer to peer connection..."
#			%MatchmakingScreen/CancelButton.disabled = true
#			%GameScreen/Player1Name.text = _username
#			%GameScreen/Player2Name.text = data["opponent_username"]
#			_match_id = data["match_id"]
#			_channel = _peer.create_data_channel(
#				"match", 
#				{"negotiated": true, "id": _match_id}
#			)
#			if data["is_offerer"]:
#				# If successful, this calls _on_session_description_created
#				var error: Error = _peer.create_offer()
#				print("%s created an offer with error %s" % [_username, error])
#				%MatchmakingScreen/Log.text = "Offer created with error %s" % error
#			else:
#				%MatchmakingScreen/Log.text = "Waiting for the offer..."
#
#		MessageCode.SESSION_DESCRIPTION:
#			var type: String = data["type"]
#			var sdp: String = data["sdp"]
#			var error: Error = _peer.set_remote_description(type, sdp)
#			print("%s set remote session description with type %s, error %s" % [_username, type, error])
#			%MatchmakingScreen/Log.text = "Received remote session description"
#
#		MessageCode.ICE_CANDIDATE:
#			var media: String = data["media"]
#			var index: int = data["index"]
#			var name_: String = data["name"]
#			var error: Error = _peer.add_ice_candidate(media, index, name_)
#			print("%s added ICE candidate with error %s" % [_username, error])
#			%MatchmakingScreen/Log.text = "Received ICE candidate"
#
#
#func _on_session_description_created(type: String, sdp: String) -> void:
#	%MatchmakingScreen/Log.text = "Session description created"
#	# If successful, this calls _on_ice_candidate_created
#	var error: Error = _peer.set_local_description(type, sdp)
#	_send_message(MessageCode.SESSION_DESCRIPTION, {"type": type, "sdp": sdp})
#	print("%s set local session description with type %s, error %s" % [_username, type, error])
#	%MatchmakingScreen/Log.text = "Session description created with error %s" % error
#
#
#func _on_ice_candidate_created(media: String, index: int, name_: String) -> void:
#	print("%s created ICE candidate with media '%s', index '%s', name '%s'" % [_username, media, index, name_])
#	%MatchmakingScreen/Log.text = "ICE candidate created"
#	_send_message(
#		MessageCode.ICE_CANDIDATE, 
#		{"media": media, "index": index, "name": name_}
#	)
#
#
#func _send_message(code: MessageCode, data: Dictionary) -> void:
#	var message: String = '{"code": %s, "match_id": %s, "data": %s}' % [
#		code, _match_id, data
#	]
#	var error: Error = _socket.send_text(message)
#	print("%s sent a message with code %s, error %s" % [_username, code, error])
#	%MatchmakingScreen/Log.text = "Sent message with code %s, error %s" % [code, error]
#
#
#func _poll_peer() -> void:
#	_peer.poll()
#	match _peer.get_connection_state():
#		WebRTCPeerConnection.STATE_CONNECTED:
#			if not %GameScreen.visible:
#				_set_screen_visible(%GameScreen)
#				var msg = "Hi, I am " + _username
#				_channel.put_packet(msg.to_utf8_buffer())
#
#
#			while _channel.get_available_packet_count():
#				_process_peer_packet(_channel.get_packet())
#
#		WebRTCPeerConnection.STATE_FAILED:
#			%HomeScreen/ErrorMessage.text = "The connection with the other player failed"
#			_set_screen_visible(%HomeScreen)
#
#
#func _process_peer_packet(_packet: PackedByteArray) -> void:
#	var string: String = _packet.get_string_from_utf8()
#	print("%s received a packet: %s" % [_username, string])
#	%GameScreen/Battle/Packet.text = string
#
#
#func _set_screen_visible(screen: Control) -> void:
#	for s in get_children():
#		s.visible = false
#	screen.visible = true
#
#
#func _on_jump_button_released() -> void:
#	_channel.put_packet("JUMP".to_ascii_buffer())
#
#
#func _on_action_button_released() -> void:
#	_channel.put_packet("ACTION".to_ascii_buffer())
#

