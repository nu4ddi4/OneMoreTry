extends "res://tests/gameplay_revision_tests.gd"

class Harness extends OneMoreGame:
	var allow_runtime := false
	var apply_calls := 0
	var simulate_apply := true
	func supports_automatic_updates() -> bool: return allow_runtime
	func apply_update(manual: bool = false) -> void:
		if not simulate_apply:
			super.apply_update(manual)
			return
		update_apply_queued = false
		if updater.state != TryUpdater.State.READY or (not manual and not can_apply_automatically()): return
		apply_calls += 1
		updater.set_status(TryUpdater.State.APPLYING,"test")

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_update_settings.cfg"))
	var legacy_settings := ConfigFile.new()
	legacy_settings.set_value("updates","channel","beta")
	legacy_settings.save("user://test_update_settings.cfg")
	var updater := TryUpdater.new(true)
	root.add_child(updater)
	check(updater.automatic_updates and updater.channel == "beta" and not updater.previous_apply_failed,"Automatic updates default on while preserving existing channel-only settings")
	check(updater.set_automatic_updates(false) and updater.set_channel("beta"),"Automatic updates can be disabled independently of beta channel selection")
	var restored := TryUpdater.new(true)
	root.add_child(restored)
	check(not restored.automatic_updates and restored.channel == "beta","Restart restores both the automatic preference and selected channel")
	restored.free()
	check(updater.set_channel("stable") and not updater.automatic_updates,"Changing channel never resets a disabled automatic preference")
	var config := ConfigFile.new()
	config.load("user://test_update_settings.cfg")
	check(config.get_value("updates","automatic",true) == false and config.get_value("updates","channel") == "stable","Both preferences remain in the same persistent file")
	updater.settings_path = "user://missing-auto-settings/sub/settings.cfg"
	check(not updater.set_automatic_updates(true) and not updater.automatic_updates,"A failed preference write does not silently enable automatic updates")
	updater.settings_path = "user://test_update_settings.cfg"
	updater.set_automatic_updates(true)
	check(updater.automatic_download,"Enabling automatic updates also enables automatic download")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TryUpdater.CACHE_DIR))
	updater.package_path = "user://updates/auto-test.zip"
	var partial := FileAccess.open(updater.package_path+".part",FileAccess.WRITE)
	partial.store_string("partial")
	partial.close()
	updater.set_status(TryUpdater.State.DOWNLOADING,"test")
	updater.set_automatic_updates(false)
	check(updater.state == TryUpdater.State.IDLE and not FileAccess.file_exists(updater.package_path+".part"),"Turning automatic updates off cancels an in-flight download and removes its partial file")
	var receipt := FileAccess.open("user://test-apply-result.json",FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"success":false,"version":"0.6.1"}))
	receipt.close()
	restored = TryUpdater.new(true)
	root.add_child(restored)
	check(restored.previous_apply_failed and restored.state == TryUpdater.State.FAILED,"Failed native application becomes a recoverable status on the next launch")
	check(not FileAccess.file_exists("user://test-apply-result.json"),"Failure receipt is consumed once rather than causing an endless restart loop")
	restored.free()
	updater.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_update_settings.cfg"))
	var harness := Harness.new()
	root.add_child(harness)
	game = harness
	game.records.path = "user://auto-ui-records.json"
	harness.allow_runtime = true
	game.updater.set_automatic_updates(true)
	game.updater.set_status(TryUpdater.State.READY,"test")
	check(game.can_apply_automatically(),"Ready automatic update can apply from the title menu")
	game.start_run()
	await ticks(4)
	check(harness.apply_calls == 0 and game.updater.state == TryUpdater.State.READY,"A download that finishes during play never interrupts the run")
	game.pause_game()
	await ticks(4)
	check(harness.apply_calls == 0 and not game.can_apply_automatically(),"Paused gameplay also defers automatic application")
	game.show_menu()
	game.updater.automatic_updates = false
	await ticks(4)
	check(harness.apply_calls == 0,"Disabled automatic updates require a manual action even at the title menu")
	game.updater.automatic_updates = true
	game.updater.previous_apply_failed = true
	check(not game.can_apply_automatically(),"A failed update is not automatically retried in a restart loop")
	game.updater.previous_apply_failed = false
	game.update_dialog.popup_centered(Vector2i(560,260))
	await ticks(4)
	check(harness.apply_calls == 0,"Changing settings in an open update dialog does not abruptly close the app")
	game.update_dialog.hide()
	await ticks(4)
	check(harness.apply_calls == 1 and game.updater.state == TryUpdater.State.APPLYING,"Returning to an idle title menu applies a ready update exactly once")
	check(not game.updater.set_channel("beta") and not game.updater.set_automatic_updates(false),"Application cannot race a channel or preference change")
	harness.allow_runtime = false
	harness.simulate_apply = false
	game.updater.set_status(TryUpdater.State.READY,"test")
	game.records.path = "user://missing-auto-records/sub/records.json"
	game.apply_update(true)
	check(game.updater.state == TryUpdater.State.FAILED,"Failed record saving blocks both application and app exit")
	game.updater.set_status(TryUpdater.State.READY,"test")
	game.refresh_update_ui()
	check(game.update_dialog.get_ok_button().text == "적용하고 다시 시작" and game.update_automatic.button_pressed,"Update dialog exposes the saved preference and restart action")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://auto-ui-records.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_update_settings.cfg"))
	print("Automatic updates: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
