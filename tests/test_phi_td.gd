extends SceneTree
## phi.td モデルのテスト:
## 1) 無編集の parse→serialize が両世界でバイト一致
## 2) 正規形レコードは parse→build_line が元の行と一致
## 3) 既知レコードのフィールド値が仕様どおり取れる

const PATHS: Array[String] = [
	"res://tests/fixtures/realworld/phi.td",
	"res://tests/fixtures/testworld/phi.td",
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
		var td := PhiTd.parse(PhiRawLines.from_bytes(original))
		_check(td.serialize() == original, path + " untouched round trip")
		var exact := 0
		var total := 0
		for i in td.records.size():
			var rec: Dictionary = td.records[i]
			if String(rec["kind"]) == "raw":
				continue
			total += 1
			if PhiTd.build_line(rec) == td.raw_lines.line_text(i):
				exact += 1
			else:
				print("  rebuild differs [", rec["kind"], "] orig: <",
						td.raw_lines.line_text(i), "> rebuilt: <",
						PhiTd.build_line(rec), ">")
		print(path, ": records=", total, " exact rebuild=", exact)
		_check(exact == total, path + " all records rebuild exactly")
	# フィールド値の検証 (実世界)
	var real := PhiTd.load_file(PATHS[0])
	var kinds := {}
	for rec in real.records:
		kinds[String(rec["kind"])] = int(kinds.get(String(rec["kind"]), 0)) + 1
	_check(int(kinds.get("G", 0)) > 10, "real td has many :G")
	_check(int(kinds.get("H", 0)) > 3, "real td has :H")
	_check(int(kinds.get("B", 0)) > 3, "real td has :B")
	for rec in real.records:
		if String(rec["kind"]) == "N":
			_check(String(rec["fields"]["name"]) == "Metro Planetarium",
					"world name")
		if String(rec["kind"]) == "O":
			_check(int(rec["fields"]["port"]) == 20033, "port 20033")
		if String(rec["kind"]) == "t":
			_check(int(rec["fields"]["yslide"]) == 3000, "yslide 3000")
	print("test_phi_td: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
