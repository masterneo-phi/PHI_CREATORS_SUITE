extends SceneTree
## NativeMenu API の存在確認用プローブ (Linux では global menu は無いが
## メソッド/定数の有無は分かる)

func _initialize() -> void:
	print("FEATURE_GLOBAL_MENU: ",
			DisplayServer.has_feature(DisplayServer.FEATURE_GLOBAL_MENU))
	print("APPLICATION_MENU_ID = ", NativeMenu.APPLICATION_MENU_ID)
	var menu := NativeMenu.get_system_menu(NativeMenu.APPLICATION_MENU_ID)
	print("app menu rid valid: ", menu.is_valid())
	if menu.is_valid():
		print("item count: ", NativeMenu.get_item_count(menu))
		if NativeMenu.get_item_count(menu) > 0:
			print("item0 text: ", NativeMenu.get_item_text(menu, 0))
	quit(0)
