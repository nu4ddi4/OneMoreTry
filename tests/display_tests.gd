extends SceneTree

var game: OneMoreGame
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    call_deferred("run")

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + description)
    else:
        print("PASS: " + description)

func settle() -> void:
    for i in 6:
        await process_frame

func controls_fit(parent: Node, bounds: Rect2) -> bool:
    for child in parent.get_children():
        if child is Control and child.is_visible_in_tree():
            if not bounds.grow(1).encloses(child.get_global_rect()):
                print("Outside viewport: ", child.name, " ", child.get_global_rect(), " bounds ", bounds)
                return false
            if not controls_fit(child, bounds):
                return false
    return true

func screenshot(name: String) -> void:
    if not capture:
        return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://build/display-audit/" + name + ".png")

func run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    root.mode = Window.MODE_WINDOWED
    for dimensions in [Vector2i(640, 360), Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 1080), Vector2i(3840, 2160)]:
        root.size = dimensions
        await settle()
        var bounds := root.get_visible_rect()
        var actual := root.get_final_transform() * bounds
        var name := "%dx%d" % [dimensions.x, dimensions.y]
        check(actual.position.length() < 1.5 and (actual.size - Vector2(root.size)).length() < 2, name + ": viewport fills the client area without bars or cropping")
        game.show_menu()
        await settle()
        check(controls_fit(game.overlay, bounds), name + ": menu and footer stay inside the viewport")
        check((game.ui.position + game.DESIGN_SIZE / 2.0 - bounds.size / 2.0).length() < 1, name + ": menu remains centered")
        check(game.camera.position.x - bounds.size.x / 2 >= -1, name + ": camera does not expose the left world edge")
        if dimensions in [Vector2i(640, 360), Vector2i(1280, 800), Vector2i(2560, 1080), Vector2i(3840, 2160)]:
            await screenshot("03-menu-" + name)
        game.start_run()
        await settle()
        check(controls_fit(game.hud, bounds), name + ": HUD and progress track stay inside the viewport")
        check(absf(game.hud.get_child(0).size.x - (bounds.size.x - 40)) < 1, name + ": HUD adapts to the available width")
        if dimensions == Vector2i(2560, 1080):
            await screenshot("04-play-ultrawide")
        game.player.respawn(Vector2(TryWorld.LENGTH - 100, 416))
        game.respawn()
        game.camera.position.x = game.camera_x(TryWorld.LENGTH)
        check(game.camera.position.x + bounds.size.x / 2 <= TryWorld.LENGTH + 1, name + ": camera respects the right world edge")
        game.pause_game()
        await settle()
        check(controls_fit(game.overlay, bounds), name + ": pause controls remain visible")
        if dimensions == Vector2i(1280, 800):
            await screenshot("06-pause")
        game.show_menu()
        game.show_records()
        await settle()
        check(controls_fit(game.overlay, bounds), name + ": record labels and return button remain visible")
        if dimensions == Vector2i(1280, 800):
            await screenshot("07-records")
        game.start_run()
        game.elapsed = 54.28
        game.run_deaths = 7
        game.finish_run()
        await settle()
        check(controls_fit(game.overlay, bounds), name + ": clear results and actions remain visible")
        if dimensions == Vector2i(1280, 800):
            await screenshot("08-clear")
    root.size = Vector2i(640, 360)
    game.show_menu()
    game.updater.set_status(TryUpdater.State.CURRENT, "업데이트가 없습니다. (v0.2.2-beta)")
    game.refresh_update_ui()
    game.update_dialog.popup_centered(Vector2i(560, 220))
    await settle()
    check(game.update_dialog.size.x <= root.get_visible_rect().size.x and game.update_dialog.size.y <= root.get_visible_rect().size.y, "Update dialog fits the smallest supported window")
    var jump := InputEventAction.new()
    jump.action = "jump"
    jump.pressed = true
    game._unhandled_input(jump)
    check(game.mode == OneMoreGame.Mode.MENU, "Update dialog blocks game shortcuts behind it")
    await screenshot("05-update-small")
    root.size = Vector2i(1280, 800)
    await settle()
    check((Vector2(game.update_dialog.position) + Vector2(game.update_dialog.size) / 2 - root.get_visible_rect().size / 2).length() < 1, "Open update dialog recenters when the parent resizes")
    game.update_dialog.hide()
    if "--window-modes" in OS.get_cmdline_user_args():
        var fullscreen := InputEventAction.new()
        fullscreen.action = "fullscreen"
        fullscreen.pressed = true
        for original in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED]:
            root.mode = original
            await settle()
            game._unhandled_input(fullscreen)
            await settle()
            check(root.mode == Window.MODE_FULLSCREEN, "F11 enters fullscreen from mode %d" % original)
            game._unhandled_input(fullscreen)
            await settle()
            check(root.mode == original, "F11 restores previous mode %d" % original)
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_records.json"))
    print("Display: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
