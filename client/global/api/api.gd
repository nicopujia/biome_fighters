extends Node

## Bridge between the client and the server of this game.


const IS_RUNNING_LOCALLY := true
const HOST := "127.0.0.1" if IS_RUNNING_LOCALLY else "34.41.27.64"
const PORT := 55555
const ACCESS_TOKEN_FILE_PATH := "user://access_token.txt"
const REQUEST_TIMEOUT := 10

var _access_token: String
var _http := HTTPRequest.new()


func _ready() -> void:
	_access_token = _load_access_token()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)


#region Authentication
## Requests the creation of a new user and returns an error message.
## If successful, it calls [method login] and the error message is empty.
func register(username: String, password: String) -> String:
	var response := await _make_form_request("users/me", _serialize_auth_fields(username, password))
	if response.succeeded():
		return await login(username, password)
	return response.error_message


## Requests the creation of an access token and returns an error message.
## If successful, it saves the access token and the error message is empty.
func login(username: String, password: String) -> String:
	var response := await _make_form_request("access-token", _serialize_auth_fields(username, password))
	var token := Token.new(response)
	if token.has_data:
		_access_token = token.access_token
		_save_access_token(_access_token)
		return ""
	return response.error_message


## Deletes the access token and redirects to auth screen.
func logout() -> void:
	_access_token = ""
	_delete_access_token()
	ScreensManager.go_to_auth_screen()
#endregion


#region Specific requests
## Fully handled request to [code]/users/me[/code] endpoint.
func request_current_user() -> User:
	return User.new(await _make_authorized_request("users/me"))


## Fully handled request to [code]/matches/access-token[/code] endpoint.
func request_match_access_token() -> Token:
	return Token.new(await _make_authorized_request("matches/access-token", HTTPClient.METHOD_POST))
#endregion


#region Helper methods to make requests
## Builds an URL to call the API
func build_url(protocol: StringName = "http", endpoint: String = "", args: Dictionary = {}) -> String:
	assert(protocol == "http" or protocol == "ws", "Parameter 'protocol' must be either 'http' or 'ws'")
	assert(not endpoint.begins_with("/"), "Parameter 'endpoint' must not start with '/'")
	var args_as_string: String = HTTPClient.new().query_string_from_dict(args)
	return "%s://%s:%d/%s?%s" % [protocol, HOST, PORT, endpoint, args_as_string]


func _make_authorized_request(
	endpoint: String, 
	method: HTTPClient.Method = HTTPClient.METHOD_GET, 
	args: Dictionary = {},
) -> APIResponse:
	var headers: PackedStringArray = ["Authorization: Bearer " + _access_token]
	var response := await _make_http_request(endpoint, method, args, headers)
	response.handle_common_errors()
	return response


func _serialize_auth_fields(username: String, password: String) -> Dictionary:
	return {"username": username, "password": password}


func _make_form_request(endpoint: String, fields: Dictionary) -> APIResponse:
	var body: String = HTTPClient.new().query_string_from_dict(fields)
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	var response := await _make_http_request(endpoint, HTTPClient.METHOD_POST, {}, headers, body)
	response.handle_common_errors(false)
	return response


func _make_http_request(
	endpoint: String, 
	method: HTTPClient.Method = HTTPClient.METHOD_GET, 
	args: Dictionary = {}, 
	headers: PackedStringArray = PackedStringArray(), 
	body: String = "",
) -> APIResponse:
	var url := build_url("http", endpoint, args)
	_http.request(url, headers, method, body)
	return APIResponse.parse(await _http.request_completed)
#endregion


#region File I/O
func _save_access_token(access_token: String) -> void:
	var file := FileAccess.open(ACCESS_TOKEN_FILE_PATH, FileAccess.WRITE)
	file.store_string(access_token)
	file.close()


func _load_access_token() -> String:
	if not FileAccess.file_exists(ACCESS_TOKEN_FILE_PATH):
		return ""
	var file := FileAccess.open(ACCESS_TOKEN_FILE_PATH, FileAccess.READ)
	var access_token := file.get_as_text()
	file.close()
	return access_token


func _delete_access_token() -> Error:
	return DirAccess.remove_absolute(ACCESS_TOKEN_FILE_PATH)
#endregion
