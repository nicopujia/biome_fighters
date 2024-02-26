extends Node


const IS_LOCAL: bool = true
const HOST: String = "127.0.0.1" if IS_LOCAL else "34.41.27.64"
const PORT: int = 55555

var me: User

var _http: HTTPRequest = HTTPRequest.new()


func _ready() -> void:
	_http.timeout = 10
	add_child(_http)


func request(endpoint: String, args: Dictionary = {}, method: HTTPClient.Method = HTTPClient.METHOD_GET) -> HTTPResponse:
	var access_token: String = PersistentData.get_value("Auth", "access_token", "")
	var headers: PackedStringArray = ["Authorization: Bearer " + access_token]
	var url: String = build_url("http", endpoint, args)
	_http.request(url, headers, method)
	return HTTPResponse.new(await _http.request_completed)


func build_url(protocol: String = "http", endpoint: String = "/", args: Dictionary = {}) -> String:
	assert(protocol == "http" or protocol == "ws")
	var args_as_string: String = HTTPClient.new().query_string_from_dict(args)
	return protocol + "://" + HOST + ':' + str(PORT) + endpoint + "?" + args_as_string


class HTTPResponse:
	var result: HTTPRequest.Result
	var status_code: HTTPClient.ResponseCode
	var headers: PackedStringArray
	var body: Dictionary
	
	func _init(response: Array) -> void:
		result = response[0]
		status_code = response[1]
		headers = response[2]
		if response[3]:
			body = JSON.parse_string(response[3].get_string_from_utf8())


class User:
	var username: String

	func _init(data: Dictionary) -> void:
		username = data["username"]
