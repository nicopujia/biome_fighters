extends Node


signal received_websocket_message(message: WebSocketMessage)

enum WebSocketMessageCode { OPPONENT_FOUND }

const IS_LOCAL: bool = true
const SECURE_S: String = "s" if not IS_LOCAL else ""
const ADDRESS: String = "127.0.0.1:8000" if IS_LOCAL else "multiplayergame-w50r9w5q.b4a.run"

var _http: HTTPRequest = HTTPRequest.new()
var _websocket: WebSocketPeer = WebSocketPeer.new()
var _websocket_is_open: bool = false


func _ready() -> void:
	_http.timeout = 10
	add_child(_http)


func _process(_delta: float) -> void:
	if _websocket_is_open:
		_poll_websocket()


func request(endpoint: String, args: Dictionary = {}, method: HTTPClient.Method = HTTPClient.METHOD_GET) -> HTTPResponse:
	var access_token: String = UserData.get_value("Auth", "access_token", "")
	var headers: PackedStringArray = ["Authorization: Bearer " + access_token]
	var url: String = build_url("http", endpoint, args)
	_http.request(url, headers, method)
	return HTTPResponse.new(await _http.request_completed)


func connect_to_websocket(endpoint: String, args: Dictionary = {}) -> Error:
	var token_response: HTTPResponse = await request("/websockets-token", {}, HTTPClient.METHOD_POST)
	
	if token_response.status_code != HTTPClient.RESPONSE_CREATED:
		return FAILED
	
	_websocket_is_open = true
	args["websockets_token"] = token_response.body["websockets_token"]
	return _websocket.connect_to_url(build_url("ws", endpoint, args))


func build_url(protocol: String = "http", endpoint: String = "/", args: Dictionary = {}) -> String:
	assert(protocol == "http" or protocol == "ws")
	var args_as_string: String = HTTPClient.new().query_string_from_dict(args)
	return protocol + SECURE_S + "://" + ADDRESS + endpoint + "?" + args_as_string



func close_current_websocket() -> void:
	_websocket_is_open = false
	_websocket.close()


func _poll_websocket() -> void:
	_websocket.poll()
	match _websocket.get_ready_state():
		WebSocketPeer.STATE_CLOSED:
			_websocket_is_open = false
		WebSocketPeer.STATE_OPEN:
			while _websocket.get_available_packet_count():
				var packet: PackedByteArray = _websocket.get_packet()
				received_websocket_message.emit(WebSocketMessage.new(packet))


class HTTPResponse:
	var result: HTTPRequest.Result
	var status_code: HTTPClient.ResponseCode
	var headers: PackedStringArray
	var body: Dictionary
	
	func _init(response: Array) -> void:
		result = response[0]
		status_code = response[1]
		headers = response[2]
		body = JSON.parse_string(response[3].get_string_from_utf8())


class WebSocketMessage:
	var code: WebSocketMessageCode
	var body: Dictionary
	
	func _init(packet: PackedByteArray) -> void:
		var message_dict: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
		code = message_dict["code"]
		body = message_dict["body"]
