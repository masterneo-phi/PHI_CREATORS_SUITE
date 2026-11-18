extends SceneTree
## phi.swt モデルのテスト: 無編集往復のバイト一致、
## レコード分類の網羅、parse→build_line の一致率の計測。

const PATHS: Array[String] = [
	"res://tests/fixtures/realworld/phi.swt",
	"res://tests/fixtures/testworld/phi.swt",
]

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	Cp932.ensure_loaded()
	for path in PATHS:
		var f := FileAccess.open(path, FileAccess.READ)
		_check(f != null, path + " open")
		if f == null:
			continue
		var original := f.get_buffer(f.get_length())
		f.close()
		var sw := PhiSwt.parse(PhiRawLines.from_bytes(original))
		_check(sw.serialize() == original, path + " untouched round trip")
		var kinds := {}
		var exact := 0
		var built := 0
		var substantive := 0
		for i in sw.records.size():
			var rec: Dictionary = sw.records[i]
			var kind := String(rec["kind"])
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			if kind in ["S", "A", "M"]:
				built += 1
				var orig := sw.raw_lines.line_text(i)
				var rebuilt := PhiSwt.build_line(rec)
				if rebuilt == orig:
					exact += 1
				elif rebuilt != orig.rstrip(" 　"):
					substantive += 1
					if substantive <= 5:
						print("  substantive diff [", kind, "] orig: <",
								orig, ">\n    rebuilt: <", rebuilt, ">")
		print(path, ": kinds=", kinds, " exact rebuild=", exact, "/", built,
				" substantive diffs=", substantive)
		_check(substantive == 0, path + " no substantive rebuild diffs")
		_check(int(kinds.get("S_partial", 0)) == 0,
				path + " no partial :S records")
	print("test_phi_swt: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
