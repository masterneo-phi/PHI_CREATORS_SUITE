extends SceneTree
## 往復テスト土台: 実世界 corpus の全ファイルが
## PhiRawLines の load→save でバイト一致すること、
## CP932 往復で壊れる行の数を数える。

const FIXTURE_DIR := "res://tests/fixtures/realworld"
const FILES: Array[String] = [
	"phi.td", "phi.dd", "phi.fd", "phi.ed", "phi.swt", "phi.od",
	"phi.crt", "phi.ex", "phi.bb", "phi.inf", "phi.ad",
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
	for name in FILES:
		var path := FIXTURE_DIR.path_join(name)
		var f := FileAccess.open(path, FileAccess.READ)
		_check(f != null, name + " open")
		if f == null:
			continue
		var original := f.get_buffer(f.get_length())
		f.close()
		var parsed := PhiRawLines.from_bytes(original)
		_check(parsed.to_bytes() == original, name + " byte-identical round trip")
		var unclean := 0
		for i in parsed.line_count():
			if not parsed.line_is_cp932_clean(i):
				unclean += 1
		print(name, ": lines=", parsed.line_count(), " cp932-unclean lines=", unclean)
	print("test_roundtrip_raw: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
