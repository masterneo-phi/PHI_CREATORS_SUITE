extends SceneTree
## 配布 pck だけで作例ライブラリが読めるかの実証 (プロジェクト側の
## data/ を退避した状態で、dist の pck を resource pack として読む)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var ok := ProjectSettings.load_resource_pack(
			"/home/hatch/workspace/phi-creators-godot/dist/PHI_CREATORS_SUITE.pck")
	print("pack loaded: ", ok)
	print("bundled exists: ",
			FileAccess.file_exists("res://data/switch_library.txt"))
	var entries := SwtLibrary.load_all()
	print("entries: ", entries.size())
	if not entries.is_empty():
		print("first: ", String(entries[0].get("label", "")))
	quit(0 if entries.size() > 200 else 1)
