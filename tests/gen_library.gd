extends SceneTree
## 同梱用の作例ライブラリを Metro 実世界から生成する (手動実行用)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var swt := PhiSwt.load_file(
			"/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld/phi.swt")
	var entries := SwtLibrary.build_entries(swt)
	print("entries: ", entries.size())
	var f := FileAccess.open(
			"/home/hatch/workspace/phi-creators-godot/data/switch_library.txt",
			FileAccess.WRITE)
	f.store_string(SwtLibrary.entries_to_text(entries))
	print("written")
	quit(0)
