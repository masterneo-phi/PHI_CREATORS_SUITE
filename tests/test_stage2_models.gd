extends SceneTree
## 第2段モデル (od/crt/ex/ad): 無編集往復のバイト一致と
## 正規形レコードの parse→build_line 一致率の検証。

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _run_model(path: String, model: RefCounted, build: Callable,
		kinds: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	_check(f != null, path + " open")
	if f == null:
		return
	var original := f.get_buffer(f.get_length())
	f.close()
	_check(model.call("serialize") == original, path + " untouched round trip")
	var records: Array = model.get("records")
	var raw: PhiRawLines = model.get("raw_lines")
	var exact := 0
	var total := 0
	for i in records.size():
		if String(records[i]["kind"]) in kinds:
			total += 1
			if String(build.call(records[i])) == raw.line_text(i):
				exact += 1
			elif total - exact <= 3:
				print("  differs [", records[i]["kind"], "] <", raw.line_text(i),
						"> vs <", build.call(records[i]), ">")
	print(path, ": rebuild exact ", exact, "/", total)
	_check(exact == total, path + " all canonical records rebuild exactly")


func _initialize() -> void:
	Cp932.ensure_loaded()
	_run_model("res://tests/fixtures/testworld/phi.od",
			PhiOd.load_file("res://tests/fixtures/testworld/phi.od"),
			func(r: Dictionary) -> String: return PhiOd.build_line(r), ["O"])
	_run_model("res://tests/fixtures/realworld/phi.od",
			PhiOd.load_file("res://tests/fixtures/realworld/phi.od"),
			func(r: Dictionary) -> String: return PhiOd.build_line(r), ["O"])
	_run_model("res://tests/fixtures/realworld/phi.crt",
			PhiCrt.load_file("res://tests/fixtures/realworld/phi.crt"),
			func(r: Dictionary) -> String: return PhiCrt.build_line(r),
			["L", "P", "F", "S", "term"])
	_run_model("res://tests/fixtures/realworld/phi.ex",
			PhiEx.load_file("res://tests/fixtures/realworld/phi.ex"),
			func(r: Dictionary) -> String: return PhiEx.build_line(r),
			["G", "g", "I", "i", "M", "m", "term"])
	_run_model("res://tests/fixtures/realworld/phi.ad",
			PhiAd.load_file("res://tests/fixtures/realworld/phi.ad"),
			func(r: Dictionary) -> String: return PhiAd.build_line(r),
			["head", "A", "term"])
	print("test_stage2_models: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
