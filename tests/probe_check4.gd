extends SceneTree
## 確認用: ed (グラ欄 / :I 分解)・crt・ex・swt:A を 1600x1000 で撮る

func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(path)


func _run() -> void:
	Cp932.ensure_loaded()
	root.size = Vector2i(1600, 1000)
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root",
			"/home/hatch/workspace/.zipstage/mac")
	cfg.save("user://creators.cfg")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_world("/home/hatch/workspace/phi-creators-godot/tests/fixtures/realworld")
	await process_frame
	var project = main.get("_project")
	# --- ed: 敵0 (グラ欄) ---
	main.call("_on_editor_selected", 5)
	await process_frame
	var ed_ed = main.get("_editors")["ed"]
	ed_ed.call("_on_enemy_selected", 0)
	await process_frame
	var sc: ScrollContainer = ed_ed.get("_detail").get_parent()
	sc.scroll_vertical = 620
	await process_frame
	await _shot("/home/hatch/workspace/probe-shots/check4_ed.png")
	# --- ed: :I サブの分解フォーム ---
	var subs: Array = ed_ed.get("_sub_indices")
	for si in subs:
		var rec: Dictionary = project.ed.records[int(si)]
		if String(rec["kind"]) == "sub" and \
				String(rec["fields"].get("letter", "")) == "I":
			ed_ed.call("_show_sub", int(si))
			break
	await process_frame
	sc.scroll_vertical = 100000
	await process_frame
	await _shot("/home/hatch/workspace/probe-shots/check4_ed_sub.png")
	# --- crt: レシピ0 ---
	main.call("_on_editor_selected", 6)
	await process_frame
	var crt_ed = main.get("_editors")["crt"]
	crt_ed.call("_show", 0)
	await process_frame
	await _shot("/home/hatch/workspace/probe-shots/check4_crt.png")
	# --- ex: 最初の :I ---
	main.call("_on_editor_selected", 7)
	await process_frame
	var ex_ed = main.get("_editors")["ex"]
	for i in project.ex.records.size():
		if String(project.ex.records[i]["kind"]) == "I":
			ex_ed.call("_show", i)
			break
	await process_frame
	await _shot("/home/hatch/workspace/probe-shots/check4_ex.png")
	# --- swt: :A テレポート (無ければ合成して追加) ---
	main.call("_on_editor_selected", 3)
	await process_frame
	var swt_ed = main.get("_editors")["swt"]
	var aidx := -1
	for i in project.swt.records.size():
		var rec2: Dictionary = project.swt.records[i]
		if String(rec2["kind"]) == "A" and \
				int(rec2["fields"].get("tail_kind", -1)) == 1:
			aidx = i
			break
	if aidx < 0:
		aidx = project.swt.add_record(
				PhiSwt._parse_line(":A 0001 0000 0000 x 012 034"))
		swt_ed.call("_refresh_list")
	swt_ed.call("_show_detail", aidx)
	await process_frame
	await _shot("/home/hatch/workspace/probe-shots/check4_swta.png")
	print("saved check4, swt A idx=", aidx)
	quit(0)
