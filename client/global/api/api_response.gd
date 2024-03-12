extends Object
class_name APIResponse

## Parser for responses sent by the API with common error handling.


## Result of the request. See [enum HTTPRequest.Result] for the possible values
var result: HTTPRequest.Result
## HTTP status code of the response. See [enum HTTPClient.ResponseCode] for the 
## possible values. It is zero if [member result] is not 
## [constant HTTPRequest.RESULT_SUCCESS].
var status_code: HTTPClient.ResponseCode
var headers: PackedStringArray ## HTTP headers of the response.
var body: Variant ## Response body in JSON format.
var error_message: String ## Detail provided by the API if an error occurs.


## Creates a new [APIResponse] based on the values returned by 
## [signal HTTPRequest.request_completed], which can be accessed by
## awaiting the signal after making calling [method HTTPRequest.request].
static func parse(raw_response: Array) -> APIResponse:
	var parsed_response := APIResponse.new()
	
	parsed_response.result = raw_response[0]
	parsed_response.status_code = raw_response[1]
	parsed_response.headers = raw_response[2]
	
	# Parse body
	var body_bytes: PackedByteArray = raw_response[3]
	if not body_bytes.is_empty():
		var body_string := body_bytes.get_string_from_utf8()
		parsed_response.body = JSON.parse_string(body_string)
	
	# Parse error message
	if parsed_response.body is Dictionary:
		var error_detail: Variant = parsed_response.body.get("detail")
		if error_detail is String:
			parsed_response.error_message = error_detail
	
	return parsed_response


## Returns [code]true[/code] if [member status_code] is 2XX, [code]false[/code] otherwise.
func succeeded() -> bool:
	return status_code >= 200 and status_code < 300


#region Error handling
## Handles common errors by displaying the intermediate screen.
## Returns [code]true[/code] if an error occurred, [code]false[/code] otherwise.
func handle_common_errors(should_handle_unauthorized_error: bool = true) -> bool:
	var error_handlers: Array[Callable] = [
		_handle_timeout_error,
		_handle_server_error,
		_handle_unknown_error,
	]
	
	if should_handle_unauthorized_error:
		error_handlers.append(_handle_unauthorized_error)
	
	for error_handler in error_handlers:
		if error_handler.call():
			return true
	
	return false


func _handle_timeout_error() -> bool:
	if result == HTTPRequest.RESULT_TIMEOUT:
		ScreensManager.show_intermediate_screen(
			"Request took too long. Please, make sure your connection is strong and then reload the game",
			"Reload",
			ScreensManager.go_to_main_menu_screen,
		)
		return true
	return false


func _handle_unauthorized_error() -> bool:
	if status_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		ScreensManager.show_intermediate_screen(
			error_message, 
			"Log in", 
			ScreensManager.go_to_auth_screen,
		)
		return true
	return false


func _handle_server_error() -> bool:
	if status_code == HTTPClient.RESPONSE_INTERNAL_SERVER_ERROR:
		ScreensManager.show_intermediate_screen("Internal server error.", "Ok")
		return true
	return false


func _handle_unknown_error() -> bool:
	if not succeeded() and error_message.is_empty():
		ScreensManager.show_intermediate_screen(
			"Unknown error ocurred with result %s, status code %s." % [result, status_code],
			"Ok",
		)
		return true
	return false
#endregion
