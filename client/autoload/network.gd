extends Node


const SERVER_DOMAIN: String = "multiplayergame-w50r9w5q.b4a.run"
var _http: HTTPRequest = HTTPRequest.new()


func _ready() -> void:
	add_child(_http)


func http_request(
	url: String, 
	headers: PackedStringArray = [], 
	method: HTTPClient.Method = HTTPClient.METHOD_GET, 
	body: String = ""
) -> Dictionary:
	var error: Error = _http.request(url, headers, method, body)
	
	if error != OK:
		return {
			"status_code": error, 
			"body": {
				"detail": "Can't make the request. Please check your internet connection and try again"
			}
		}
	
	var response: Array = await _http.request_completed
	var status_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	var response_body_as_dict: Dictionary = JSON.parse_string(
		response_body.get_string_from_utf8()
	)
	return {"status_code": status_code, "body": response_body_as_dict}


func call_server_with_auth_token(
	endpoint: String,
	method: HTTPClient.Method = HTTPClient.METHOD_GET
) -> Dictionary:
	var url: String = "https://%s/%s" % [Globals.SERVER_DOMAIN, endpoint]
	var access_token: String = UserData.get_value("Auth", "access_token", "")
	if access_token.is_empty():
		# As we already know the answer if the token is empty, we directly 
		# return the expected response to save time
		return {
			"status_code": HTTPClient.RESPONSE_UNAUTHORIZED, 
			"body": {"detail": "Not authenticated"}
		}
	var headers: PackedStringArray = ["Authorization: Bearer " + access_token]
	return await http_request(url, headers, method)
