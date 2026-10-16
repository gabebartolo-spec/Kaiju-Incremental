extends Node
## Development switches. Off in every capture the director sees.

var verbose := false


func trace(message: String) -> void:
	if verbose:
		print("[debug] ", message)
