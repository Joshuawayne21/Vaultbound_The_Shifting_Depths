class_name VaultDemoExchangeCodec
extends RefCounted
## Canonical integer-only data. No ownership, files, RNG or clock access.

const MAX_COUNT := 2147483647

static func canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "true" if value else "false"
		TYPE_INT: return str(value)
		TYPE_STRING: return JSON.stringify(value)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for child: Variant in value:
				var encoded := canonical_json(child)
				if encoded.is_empty(): return ""
				parts.append(encoded)
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			for key: Variant in keys:
				if not key is String: return ""
			keys.sort()
			var parts: PackedStringArray = []
			for key: String in keys:
				var encoded := canonical_json(value[key])
				if encoded.is_empty(): return ""
				parts.append(JSON.stringify(key) + ":" + encoded)
			return "{" + ",".join(parts) + "}"
	return ""

static func digest(value: Variant) -> String:
	var encoded := canonical_json(value)
	return encoded.sha256_text() if not encoded.is_empty() else ""

static func integer_tree(value: Variant) -> Variant:
	# JSON numbers are doubles. Reject fractions/nonfinite/out-of-range values;
	# schema validation still decides which fields are integers or booleans.
	if value is float:
		if not is_finite(value) or value != floor(value) or absf(value) > MAX_COUNT: return null
		return int(value)
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			if not key is String: return null
			result[key] = integer_tree(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(integer_tree(child))
		return result
	return value if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING] else null

static func keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: Variant in value:
		if not key is String or not expected.has(key): return false
	return true

static func integer(value: Variant, minimum: int = 0, maximum: int = MAX_COUNT) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= maximum

static func strings(value: Dictionary, fields: Array) -> bool:
	for field: String in fields:
		if not value.get(field) is String: return false
	return true

static func text(value: Variant, maximum: int = 240, empty: bool = false) -> bool:
	if not value is String or value.length() > maximum or (not empty and value.is_empty()): return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32: return false
	return true

static func hex_digest(value: Variant, length: int = 64) -> bool:
	if not value is String or value.length() != length: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true
