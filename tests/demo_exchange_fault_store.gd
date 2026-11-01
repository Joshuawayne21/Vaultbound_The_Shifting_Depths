extends "res://scripts/exchange/demo_exchange_store.gd"
## Isolated filesystem fault fixture. Never used by runtime UI.
var fault := ""
var reentry_candidate: Dictionary = {}
var reentry_result: Dictionary = {}

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if fault == "write" and path.ends_with(".json.tmp"):
		fault = ""
		return false
	if fault == "short_write" and path.ends_with(".json.tmp"):
		fault = ""
		return super._write_bytes(path, bytes.slice(0, 17))
	if fault == "backup" and path.ends_with(".bak.tmp"):
		fault = ""
		return false
	if fault == "reentry" and path.ends_with(".json.tmp"):
		fault = ""
		reentry_result = save_state(reentry_candidate, int(reentry_candidate.epoch), int(reentry_candidate.revision) - 1)
	return super._write_bytes(path, bytes)

func _replace(source: String, destination: String) -> Error:
	if destination.ends_with("demo_exchange.json"):
		if fault == "replace":
			fault = ""
			return ERR_CANT_CREATE
		if fault == "lost_ack":
			fault = ""
			super._replace(source, destination)
			return ERR_CANT_CREATE
		if fault == "corrupt_after_replace":
			fault = ""
			super._replace(source, destination)
			super._write_bytes(destination, "{interrupted".to_utf8_buffer())
			return ERR_CANT_CREATE
	return super._replace(source, destination)
