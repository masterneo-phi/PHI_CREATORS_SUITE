extends SceneTree
## phi.ed モデル: 無編集往復のバイト一致と、
## ヘッダ行の parse→build_line 一致を両世界で検証する。

const PATHS: Array[String] = [
	"res://tests/fixtures/realworld/phi.ed",
	"res://tests/fixtures/testworld/phi.ed",
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
		var ed := PhiEd.parse(PhiRawLines.from_bytes(original))
		_check(ed.serialize() == original, path + " untouched round trip")
		var bl := ed.blocks()
		_check(bl.size() > 0, path + " has enemy blocks")
		var exact := 0
		for b in bl:
			var hi := int(b["header"])
			if PhiEd.build_line(ed.records[hi]) == ed.raw_lines.line_text(hi):
				exact += 1
			else:
				print("  header differs: <", ed.raw_lines.line_text(hi),
						">\n    rebuilt: <", PhiEd.build_line(ed.records[hi]), ">")
		print(path, ": blocks=", bl.size(), " header exact=", exact)
		_check(exact == bl.size(), path + " all headers rebuild exactly")
		# サブレコードは rest 保持で常に一致するはず
		var sub_ok := true
		for i in ed.records.size():
			if String(ed.records[i]["kind"]) in ["sub", "select", "term"]:
				if PhiEd.build_line(ed.records[i]) != ed.raw_lines.line_text(i):
					sub_ok = false
		_check(sub_ok, path + " sub records rebuild exactly")
	print("test_phi_ed: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
