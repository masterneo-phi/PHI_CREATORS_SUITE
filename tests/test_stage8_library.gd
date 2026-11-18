extends SceneTree
## 第8段: スイッチ作例ライブラリ。
## - 実世界から作例が生成され、座標は 0/1 に、文章・キーワード・
##   アイテム名・魔法名が伏せられる (固有名詞が残らない)
## - 作例は全て検証を通る形で、ライブラリの保存/読み込みが往復する

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var swt := PhiSwt.load_file(
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld/phi.swt")
	var entries := SwtLibrary.build_entries(swt)
	_check(entries.size() >= 100 and entries.size() <= 500,
			"entry count sane: %d" % entries.size())
	var all_text := ""
	for e in entries:
		all_text += String(e["line"]) + "\n"
	# 固有名詞・物語の語が残っていない
	for ng in ["Metro", "Eldius", "蒼神", "ガイアース", "Turotial",
			"Black orb", "精霊", "王妃", "温泉が湧き"]:
		_check(not all_text.contains(ng), "no leak: " + ng)
	_check(all_text.contains("メッセージ本文"), "messages masked")
	_check(all_text.contains("キーワード"), "keywords masked")
	_check(all_text.contains("アイテム名"), "item names masked")
	# 座標は 000/001 のみ + :S は検証を通る
	var bad := 0
	for e in entries:
		var line := String(e["line"])
		if line.begins_with(":S"):
			var v := SwtAi.validate_lines(line, Vector2i(1000, 1000))
			if (v["ok"] as Array).size() != 1:
				bad += 1
				continue
			var f: Dictionary = (v["ok"][0] as Dictionary)["fields"]
			for key in ["sx", "sy", "ax", "ay"]:
				if not [0, 1].has(int(f[key])):
					bad += 1
	_check(bad == 0, "all :S entries valid with masked coords (bad=%d)" % bad)
	# sanitize の単体確認: 同一マスは 0、別マスは 1
	var rec := {"kind": "S", "fields": {"sx": 50, "sy": 60, "cc": 3,
			"cond": ["\"秘密の言葉\""], "ax": 50, "ay": 60, "dd": 6,
			"act": []}, "modified": false}
	var s1 := SwtLibrary.sanitize_record(rec)
	_check(int(s1["fields"]["ax"]) == 0, "same cell stays 0")
	_check(String(s1["fields"]["cond"][0]) == "\"キーワード\"",
			"keyword masked in unit check")
	rec["fields"]["ax"] = 99
	var s2 := SwtLibrary.sanitize_record(rec)
	_check(int(s2["fields"]["ax"]) == 1, "other cell becomes 1")
	# テキスト往復
	var text := SwtLibrary.entries_to_text(entries)
	var back := SwtLibrary.parse_library_text(text)
	_check(back.size() == entries.size(), "text round trip")
	# 同梱ライブラリが読める
	var all := SwtLibrary.load_all()
	_check(all.size() >= 200, "bundled library loads: %d" % all.size())
	# ユーザーライブラリへの追加 (重複は増えない)。
	# 前回実行の残りがあると数えられないので最初に消す
	var user_lib := ProjectSettings.globalize_path("user://switch_library.txt")
	if FileAccess.file_exists(user_lib):
		DirAccess.remove_absolute(user_lib)
	var n1 := SwtLibrary.append_user_entries(entries.slice(0, 5))
	var n2 := SwtLibrary.append_user_entries(entries.slice(0, 5))
	_check(n1 == 5 and n2 == 0, "append dedups (%d, %d)" % [n1, n2])
	print("stage8 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)
