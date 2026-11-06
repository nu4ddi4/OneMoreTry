class_name OneMoreGame
extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")
const EncounterScript = preload("res://scripts/encounter.gd")
const Course = preload("res://scripts/course.gd")
const RecordsScript = preload("res://scripts/records.gd")
const SoundScript = preload("res://scripts/sound.gd")
const UpdaterScript = preload("res://scripts/updater.gd")
const InspectorScript = preload("res://scripts/inspection.gd")
const INK := Color("203c40")
const CREAM := Color("f4ecd4")
const MINT := Color("84dfb7")
const MUTED := Color("a2bcb3")
const DESIGN_SIZE := Vector2(960, 540)

enum Mode { MENU, PLAYING, PAUSED, CLEAR, RECORDS }
var mode: Mode = Mode.MENU
var player: TryPlayer
var world: TryWorld
var camera: Camera2D
var sound: TrySound
var records: TryRecords
var traps: Array[TryEncounter] = []
var checkpoint_index := -1
var spawn_point := Vector2(100, 416)
var elapsed := 0.0
var run_deaths := 0
var secret_collected := false
var respawn_timer := 0.0
var shake := 0.0
var particles: Array[Dictionary] = []
var celebration_clock := 0.0
var font: Font
var ui: Control
var hud: Control
var overlay: Control
var death_label: Label
var time_label: Label
var toast_label: Label
var toast_clock := 0.0
var progress: ColorRect
var new_best := false
var test_mode := false
var updater: TryUpdater
var update_dialog: AcceptDialog
var update_button: Button
var update_channel: OptionButton
var update_status: Label
var update_automatic: CheckButton
var update_apply_queued := false
var version_label: Label
var quit_dialog: ConfirmationDialog
var inspector: TryInspector
var mode_before_fullscreen: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED

func _ready() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	configure_input()
	font = load("res://assets/fonts/OneMoreSans.otf")
	records = RecordsScript.new(test_mode)
	sound = SoundScript.new()
	add_child(sound)
	apply_audio_settings()
	camera = Camera2D.new()
	camera.position = Vector2(480, 270)
	add_child(camera)
	world = WorldScript.new()
	world.game = self
	world.z_index = -10
	add_child(world)
	build_traps()
	player = PlayerScript.new()
	player.position = spawn_point
	add_child(player)
	player.died.connect(on_death)
	player.jumped.connect(func(): sound.effect("jump"))
	player.landed.connect(func(speed: float):
		if speed >= 340:
			sound.effect("click")
			burst(player.position, Color("a77954"), 5))
	build_ui()
	build_updater()
	build_quit_dialog()
	get_viewport().size_changed.connect(layout_screen)
	show_menu()
	layout_screen()
	inspector = InspectorScript.new()
	inspector.game = self
	add_child(inspector)
	updater.acknowledge_restart()
	if supports_automatic_updates() and updater.automatic_updates and not updater.previous_apply_failed:
		updater.automatic_download = updater.automatic_updates
		updater.check_for_updates()
	get_window().focus_exited.connect(func():
		if mode == Mode.PLAYING and not test_mode:
			pause_game())
	get_tree().auto_accept_quit = false

func build_updater() -> void:
	updater = UpdaterScript.new(test_mode)
	add_child(updater)
	update_dialog = AcceptDialog.new()
	update_dialog.title = "업데이트"
	update_dialog.dialog_hide_on_ok = false
	update_dialog.min_size = Vector2i(560, 260)
	var dialog_theme := Theme.new()
	dialog_theme.default_font = font
	dialog_theme.default_font_size = 17
	update_dialog.theme = dialog_theme
	add_child(update_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	update_dialog.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var channel_label := Label.new()
	channel_label.text = "채널"
	row.add_child(channel_label)
	update_channel = OptionButton.new()
	update_channel.add_item("정식")
	update_channel.add_item("베타")
	update_channel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(update_channel)
	update_channel.item_selected.connect(func(index: int):
		if updater.set_channel("stable" if index == 0 else "beta"):
			updater.check_for_updates())
	update_automatic = CheckButton.new()
	update_automatic.text = "자동 업데이트"
	content.add_child(update_automatic)
	update_automatic.toggled.connect(func(value: bool):
		if updater.set_automatic_updates(value) and value:
			updater.previous_apply_failed = false
			updater.check_for_updates()
		refresh_update_ui())
	update_status = Label.new()
	update_status.custom_minimum_size = Vector2(520, 60)
	update_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(update_status)
	update_dialog.add_cancel_button("닫기").pressed.connect(updater.cancel)
	update_dialog.close_requested.connect(updater.cancel)
	update_dialog.confirmed.connect(confirm_update)
	updater.changed.connect(refresh_update_ui)

func build_quit_dialog() -> void:
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "종료"
	quit_dialog.dialog_text = "기록을 저장하지 못했습니다."
	quit_dialog.min_size = Vector2i(560, 180)
	quit_dialog.theme = update_dialog.theme
	quit_dialog.ok_button_text = "저장하지 않고 종료"
	quit_dialog.cancel_button_text = "취소"
	quit_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(quit_dialog)

func confirm_update() -> void:
	match updater.state:
		TryUpdater.State.AVAILABLE:
			updater.download_update()
		TryUpdater.State.READY:
			apply_update(true)
		_:
			updater.check_for_updates()

func show_updates() -> void:
	refresh_update_ui()
	update_dialog.popup_centered(Vector2i(560, 260))
	if updater.state in [TryUpdater.State.IDLE, TryUpdater.State.FAILED, TryUpdater.State.CURRENT]:
		updater.check_for_updates()

func refresh_update_ui() -> void:
	update_status.text = updater.message
	update_channel.select(1 if updater.channel == "beta" else 0)
	update_automatic.set_pressed_no_signal(updater.automatic_updates)
	update_automatic.disabled = updater.state == TryUpdater.State.APPLYING
	update_channel.disabled = updater.state == TryUpdater.State.APPLYING
	var action := update_dialog.get_ok_button()
	action.disabled = updater.state in [TryUpdater.State.CHECKING, TryUpdater.State.DOWNLOADING, TryUpdater.State.APPLYING]
	match updater.state:
		TryUpdater.State.AVAILABLE:
			action.text = "다운로드"
		TryUpdater.State.READY:
			action.text = "적용하고 다시 시작"
		_:
			action.text = "다시 확인"
	if is_instance_valid(update_button):
		update_button.text = "새 버전" if updater.state in [TryUpdater.State.AVAILABLE, TryUpdater.State.READY] else "업데이트"

func supports_automatic_updates() -> bool:
	return OS.get_name() == "Windows" and not OS.has_feature("editor") and not test_mode

func can_apply_automatically() -> bool:
	return supports_automatic_updates() and updater.automatic_updates and not updater.previous_apply_failed and updater.state == TryUpdater.State.READY and mode == Mode.MENU and not update_dialog.visible and not quit_dialog.visible

func apply_update(manual: bool = false) -> void:
	update_apply_queued = false
	if updater.state != TryUpdater.State.READY or (not manual and not can_apply_automatically()): return
	if not records.save():
		updater.fail("기록을 저장하지 못했습니다. 저장 공간을 확인해 주세요.")
	elif updater.launch_apply():
		get_tree().quit()

func configure_input() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "climb_up": [KEY_W, KEY_UP], "climb_down": [KEY_S, KEY_DOWN], "retry": [KEY_R], "pause_game": [KEY_ESCAPE], "fullscreen": [KEY_F11], "mute": [KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func apply_audio_settings() -> void:
	var audible: bool = not records.data.muted and not test_mode
	sound.set_effects(records.data.sfx and audible)
	sound.set_music(records.data.music and audible)

func build_traps() -> void:
	for data in Course.all():
		var encounter := EncounterScript.new()
		encounter.definition = data
		encounter.game = self
		add_child(encounter)
		traps.append(encounter)

func interaction_enabled() -> bool:
	return mode == Mode.PLAYING and player != null and player.alive and not bool(get_meta("inspection_pause_world", false))

func start_run() -> void:
	mode = Mode.PLAYING
	toast_clock = 0
	toast_label.hide()
	checkpoint_index = -1
	spawn_point = Vector2(100, 416)
	elapsed = 0
	run_deaths = 0
	respawn_timer = 0
	secret_collected = false
	particles.clear()
	records.data.attempts += 1
	save_records()
	for trap in traps:
		trap.reset()
	player.respawn(spawn_point)
	player.enabled = true
	camera.position = Vector2(camera_x(100), 270)
	sound.quiet(false)
	clear_overlay()
	hud.show()
	update_hud()

func _physics_process(delta: float) -> void:
	if mode == Mode.PLAYING and not bool(get_meta("inspection_flying", false)):
		elapsed += delta
		if not player.alive:
			respawn_timer -= delta
			if respawn_timer <= 0:
				respawn()
		else:
			for i in range(TryWorld.CHECKPOINTS.size()):
				if i > checkpoint_index and absf(player.position.x - TryWorld.CHECKPOINTS[i].x) < 24 and absf(player.position.y - 416) < 8 and player.is_on_floor():
					activate_checkpoint(i)
			if not secret_collected and player.position.distance_to(TryWorld.SECRET + Vector2(0, 14)) < 28:
				secret_collected = true
				records.data.secret = true
				save_records()
				sound.effect("secret")
				burst(TryWorld.SECRET, MINT, 20)
			if player.position.x >= TryWorld.GOAL - 12 and player.position.y <= 420 and player.position.y >= 350:
				finish_run()
		update_hud()
	player.enabled = mode == Mode.PLAYING
	if mode == Mode.PLAYING or mode == Mode.CLEAR:
		var target := camera_x(player.position.x + 130)
		camera.position.x = camera_x(lerpf(camera.position.x, target, 1.0 - exp(-delta * 9)))
		camera.position.y = 270

func _process(delta: float) -> void:
	if not update_apply_queued and can_apply_automatically():
		update_apply_queued = true
		apply_update.call_deferred()
	if mode == Mode.PAUSED or mode == Mode.RECORDS:
		return
	toast_clock = maxf(0, toast_clock - delta)
	toast_label.visible = toast_clock > 0
	shake = move_toward(shake, 0.0, delta * 24)
	camera.offset = Vector2(sin(Time.get_ticks_msec() * 0.11), cos(Time.get_ticks_msec() * 0.09)) * shake
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].velocity.y += 420 * delta
		particles[i].position += particles[i].velocity * delta
		if particles[i].life <= 0:
			particles.remove_at(i)
	if mode == Mode.CLEAR:
		celebration_clock += delta
		if celebration_clock > 0.22:
			celebration_clock = 0
			burst(Vector2(player.position.x + randf_range(-220, 220), 110), [MINT, CREAM, Color("e9ab79")].pick_random(), 5)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var window_mode := DisplayServer.window_get_mode()
		if window_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			DisplayServer.window_set_mode(mode_before_fullscreen)
		else:
			mode_before_fullscreen = window_mode
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif update_dialog.visible or quit_dialog.visible or (inspector != null and inspector.is_open()):
		return
	elif event.is_action_pressed("mute"):
		records.data.muted = not records.data.muted
		apply_audio_settings()
		save_records()
		if mode == Mode.PAUSED:
			pause_game()
		toast("소리 꺼짐" if records.data.muted else "음소거 해제", 1.4)
	elif event.is_action_pressed("pause_game"):
		if mode == Mode.PLAYING:
			pause_game()
		elif mode == Mode.PAUSED:
			resume_game()
		elif mode == Mode.RECORDS:
			show_menu()
	elif event.is_action_pressed("retry") and mode == Mode.PLAYING and player.alive:
		player.die("retry")
		respawn_timer = 0.0
	elif event.is_action_pressed("jump") and mode == Mode.MENU:
		start_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func on_death(_reason: String) -> void:
	run_deaths += 1
	records.data.deaths += 1
	save_records()
	respawn_timer = 0.38
	shake = 4.0
	sound.effect("death")
	burst(player.position + Vector2(0, -16), MINT, 18)

func respawn() -> void:
	for trap in traps:
		trap.reset()
	player.respawn(spawn_point)
	respawn_timer = 0
	camera.position.x = camera_x(spawn_point.x + 130)
	if inspector != null:
		inspector.after_respawn()

func activate_checkpoint(index: int) -> void:
	checkpoint_index = index
	spawn_point = TryWorld.CHECKPOINTS[index] + Vector2(24, 0)
	sound.effect("checkpoint")
	burst(TryWorld.CHECKPOINTS[index] + Vector2(5, -55), Color("f5d68a"), 15)

func finish_run() -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.CLEAR
	player.enabled = false
	player.velocity = Vector2.ZERO
	new_best = records.data.best_time <= 0 or elapsed < records.data.best_time
	if new_best:
		records.data.best_time = elapsed
	records.data.clears += 1
	if run_deaths == 0:
		records.data.no_death = true
	if save_records():
		toast_clock = 0
	sound.quiet(true)
	sound.effect("clear")
	show_clear()

func save_records() -> bool:
	if records.save():
		return true
	if toast_label:
		toast(records.last_error, 4)
	return false

func camera_x(value: float) -> float:
	var half_width := minf(get_viewport_rect().size.x / 2.0, TryWorld.LENGTH / 2.0)
	return clampf(value, half_width, TryWorld.LENGTH - half_width)

func layout_screen() -> void:
	var visible_size := get_viewport_rect().size
	ui.position = (visible_size - DESIGN_SIZE) / 2.0
	ui.size = DESIGN_SIZE
	hud.position = -ui.position
	hud.size = visible_size
	toast_label.position.y = 105 - ui.position.y
	if is_instance_valid(version_label):
		version_label.position = Vector2(65, visible_size.y - 32) - ui.position
	if is_instance_valid(update_button):
		update_button.position = visible_size - Vector2(225, 68) - ui.position
	if mode in [Mode.MENU, Mode.RECORDS]:
		camera.position.x = camera_x(100)
	else:
		camera.position.x = camera_x(camera.position.x)
	if update_dialog.visible:
		update_dialog.position = Vector2i((visible_size - Vector2(update_dialog.size)) / 2.0)
	if quit_dialog.visible:
		quit_dialog.position = Vector2i((visible_size - Vector2(quit_dialog.size)) / 2.0)
	update_hud()

func toast(message: String, duration: float = 2.0) -> void:
	toast_label.text = message
	toast_clock = duration
	toast_label.show()

func burst(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"position": at, "velocity": Vector2(randf_range(-150, 150), randf_range(-210, -30)), "life": randf_range(0.3, 0.8), "color": color, "size": randi_range(2, 5)})

func _draw() -> void:
	for p in particles:
		var color: Color = p.color
		color.a = minf(1, p.life * 3)
		draw_rect(Rect2(p.position, Vector2.ONE * p.size), color)

func style(background: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(3)
	result.content_margin_left = 12
	result.content_margin_right = 12
	return result

func text(parent: Node, value: String, at: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color = Color("203c40f5")) -> Panel:
	var node := Panel.new()
	node.position = at
	node.size = dimensions
	node.add_theme_stylebox_override("panel", style(color, Color("6e948552"), 1))
	parent.add_child(node)
	return node

func button(parent: Node, value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = at
	node.size = dimensions
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", INK if primary else CREAM)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_focus_color", INK if primary else CREAM)
	node.add_theme_stylebox_override("normal", style(MINT if primary else Color("335253"), Color("52736b"), 1))
	node.add_theme_stylebox_override("hover", style(Color("b5e6c0")))
	node.add_theme_stylebox_override("pressed", style(Color("67b99d")))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color("f6d794"), 2))
	node.pressed.connect(func():
		sound.effect("click")
		callback.call())
	parent.add_child(node)
	return node

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.size = DESIGN_SIZE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	hud.size = DESIGN_SIZE
	var hud_panel := panel(hud, Vector2(20, 18), Vector2(920, 62), Color("203c40f2"))
	hud_panel.set_anchor(SIDE_RIGHT, 1.0)
	hud_panel.offset_right = -20
	death_label = text(hud, "", Vector2(38, 30), Vector2(210, 35), 19)
	time_label = text(hud, "", Vector2(762, 30), Vector2(150, 35), 19, MINT)
	for entry in [time_label]:
		var left_offset: float = entry.position.x - DESIGN_SIZE.x
		var right_offset: float = left_offset + entry.size.x
		entry.set_anchor(SIDE_LEFT, 1.0)
		entry.set_anchor(SIDE_RIGHT, 1.0)
		entry.offset_left = left_offset
		entry.offset_right = right_offset
	var track := ColorRect.new()
	track.position = Vector2(21, 78)
	track.size = Vector2(918, 3)
	track.color = Color("395850")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(track)
	track.set_anchor(SIDE_RIGHT, 1.0)
	track.offset_right = -21
	progress = ColorRect.new()
	progress.size = Vector2(0, 3)
	progress.color = MINT
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(progress)
	toast_label = text(ui, "", Vector2(140, 105), Vector2(680, 38), 15, INK)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", style(Color("fff1d2ef"), Color("dfcda4"), 1))
	toast_label.hide()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)

func clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

func update_hud() -> void:
	death_label.text = "사망  %03d" % run_deaths
	time_label.text = format_time(elapsed)
	progress.size.x = clampf((player.position.x - 100) / (TryWorld.GOAL - 100), 0, 1) * progress.get_parent().size.x

static func format_time(seconds: float) -> String:
	var centis := int(seconds * 100)
	return "%02d:%02d.%02d" % [centis / 6000, (centis / 100) % 60, centis % 100]

func show_menu() -> void:
	mode = Mode.MENU
	particles.clear()
	player.enabled = false
	player.respawn(Vector2(100, 416))
	camera.position = Vector2(camera_x(100), 270)
	camera.offset = Vector2.ZERO
	checkpoint_index = -1
	for trap in traps:
		trap.reset()
	hud.hide()
	toast_clock = 0
	sound.quiet(false)
	clear_overlay()
	var card := panel(overlay, Vector2(220, 128), Vector2(520, 280))
	var title := text(card, "한 번만 더!", Vector2(24, 25), Vector2(472, 80), 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start := button(card, "시작", Vector2(40, 141), Vector2(440, 48), start_run, true)
	button(card, "기록", Vector2(40, 203), Vector2(214, 40), show_records)
	button(card, "종료", Vector2(266, 203), Vector2(214, 40), quit_game)
	if OS.get_name() == "Windows":
		update_button = button(overlay, "업데이트", Vector2(735, 472), Vector2(160, 36), show_updates)
		refresh_update_ui()
	version_label = text(overlay, "v" + str(ProjectSettings.get_setting("application/config/version")), Vector2(65, 508), Vector2(180, 18), 10, Color("b5c4a2"))
	layout_screen()
	start.grab_focus()
	if not records.last_error.is_empty():
		toast(records.last_error, 5)

func pause_game() -> void:
	mode = Mode.PAUSED
	player.enabled = false
	sound.quiet(true)
	clear_overlay()
	var card := panel(overlay, Vector2(270, 138), Vector2(420, 315))
	text(card, "일시정지", Vector2(30, 22), Vector2(365, 42), 29)
	if records.data.muted:
		text(card, "음소거", Vector2(300, 34), Vector2(90, 24), 13, MUTED)
	var resume := button(card, "계속", Vector2(30, 90), Vector2(360, 43), resume_game, true)
	button(card, "처음부터", Vector2(30, 144), Vector2(174, 40), start_run)
	button(card, "메뉴", Vector2(216, 144), Vector2(174, 40), show_menu)
	button(card, "음악 " + ("켜짐" if records.data.music else "꺼짐"), Vector2(30, 200), Vector2(174, 36), func():
		records.data.music = not records.data.music
		apply_audio_settings()
		save_records()
		pause_game())
	button(card, "효과음 " + ("켜짐" if records.data.sfx else "꺼짐"), Vector2(216, 200), Vector2(174, 36), func():
		records.data.sfx = not records.data.sfx
		apply_audio_settings()
		save_records()
		pause_game())
	text(card, "A / D  이동   SPACE  점프   W / S  오르내리기", Vector2(30, 252), Vector2(360, 20), 11, MUTED)
	text(card, "ESC  계속   R  다시하기   M  음소거   F11  전체 화면", Vector2(30, 276), Vector2(360, 20), 11, MUTED)
	resume.grab_focus()

func resume_game() -> void:
	mode = Mode.PLAYING
	player.enabled = true
	sound.quiet(false)
	clear_overlay()

func show_clear() -> void:
	clear_overlay()
	var card := panel(overlay, Vector2(235, 120), Vector2(490, 300))
	text(card, "클리어", Vector2(30, 24), Vector2(430, 52), 36)
	text(card, "시간", Vector2(31, 98), Vector2(210, 24), 13, MUTED)
	text(card, format_time(elapsed), Vector2(31, 126), Vector2(230, 39), 27)
	text(card, "사망", Vector2(279, 98), Vector2(180, 24), 13, MUTED)
	text(card, "%d회" % run_deaths, Vector2(279, 126), Vector2(180, 39), 27, MINT)
	var badge := "최고 기록" if new_best else "최고 기록  " + format_time(records.data.best_time)
	if run_deaths == 0:
		badge += "  ·  무사망"
	if secret_collected:
		badge += "  ·  별"
	text(card, badge, Vector2(31, 190), Vector2(438, 25), 13, Color("f5ce95"))
	var again := button(card, "다시하기", Vector2(30, 236), Vector2(241, 40), start_run, true)
	button(card, "메뉴", Vector2(283, 236), Vector2(177, 40), show_menu)
	again.grab_focus()

func show_records() -> void:
	mode = Mode.RECORDS
	clear_overlay()
	var card := panel(overlay, Vector2(235, 76), Vector2(490, 368))
	text(card, "기록", Vector2(30, 45), Vector2(430, 50), 34)
	var values := ["최고 기록", "시작 / 클리어", "사망", "무사망 클리어", "별"]
	var stats := [format_time(records.data.best_time) if records.data.best_time > 0 else "—", "%d / %d" % [records.data.attempts, records.data.clears], "%d회" % records.data.deaths, "달성" if records.data.no_death else "—", "획득" if records.data.secret else "—"]
	for i in range(5):
		text(card, values[i], Vector2(32, 118 + i * 33), Vector2(230, 26), 14, MUTED)
		var value := text(card, stats[i], Vector2(250, 118 + i * 33), Vector2(206, 26), 15)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := button(card, "돌아가기", Vector2(30, 306), Vector2(430, 40), show_menu, true)
	back.grab_focus()

func quit_game() -> void:
	if save_records():
		get_tree().quit()
	else:
		quit_dialog.popup_centered(Vector2i(560, 180))
		quit_dialog.get_cancel_button().grab_focus()
