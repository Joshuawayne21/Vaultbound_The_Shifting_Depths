class_name VaultDepthStreams
extends RefCounted
## Shared bounded mixer; deliberately independent of content and topology imports.
static func seed_for(seed_value: int, depth: int, policy_version: int, stream: StringName) -> int:
	var key := "vaultbound_depth_v%d|%d|%d|%s" % [policy_version, seed_value, depth, String(stream)]
	return int(key.sha256_text().substr(0, 10).hex_to_int())
