class_name Num
extends RefCounted
## Typed reads of JSON and save values (Variant) without unsafe casts: JSON numbers arrive as
## float, saves may hold int. Use Num.f / Num.i instead of float() / int() on a Variant.


static func f(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT:
			var x: float = value
			return x
		TYPE_INT:
			var n: int = value
			return n
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_STRING:
			var s: String = value
			return s.to_float()
	return 0.0


static func i(value: Variant) -> int:
	return int(f(value))
