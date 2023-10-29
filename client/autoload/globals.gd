extends Node


const SERVER_DOMAIN = "multiplayergame-w50r9w5q.b4a.run"
const SERVER_PORT = "60408"
const AUTH_SCREEN = preload("res://screens/auth/auth_screen.tscn")
const MAIN_MENU_SCREEN = preload("res://screens/main_menu/main_menu_screen.tscn")
const GAME_SCREEN = preload("res://screens/game/game_screen.tscn")
const CONFIG_FILE_PATH = "user://data.cfg"
var access_token: get = _get_access_token, set = _set_access_token
var _http = HTTPRequest.new()


func _ready() -> void:
	add_child(_http)


func call_server(endpoint: String, method: HTTPClient.Method = HTTPClient.METHOD_GET) -> Dictionary:
	var url = "https://%s:%s/%s" % [SERVER_DOMAIN, SERVER_PORT, endpoint]
	var headers = ["Authorization: Bearer " + access_token]
	var error = _http.request(url, headers, method)
	
	if error != OK:
		return {}
	
	var response = await _http.request_completed
	
	return {
		"status_code": response[1],
		"body": JSON.parse_string(response[3].get_string_from_utf8())
	}


func _set_access_token(value: String) -> void:
	var config_file = ConfigFile.new()
	config_file.set_value("Auth", "access_token", value)
	config_file.save(CONFIG_FILE_PATH)


func _get_access_token() -> String:
	var config_file = ConfigFile.new()
	config_file.load(CONFIG_FILE_PATH)
	return config_file.get_value("Auth", "access_token", "")
