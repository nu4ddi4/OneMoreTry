class_name TryInspector
extends Node

const Records = preload("res://scripts/records.gd")
var game: Node2D
var active := false
var flying := false
var dialog: AcceptDialog
var room: SpinBox
var coordinate_x: SpinBox
var coordinate_y: SpinBox
var flight: CheckBox
var invulnerable: CheckBox
var freeze_world: CheckBox
var position_label: Label
var saved_mode := 0
var normal_records: TryRecords
var flight_speed := 600.0
var replay_finale := false

func _ready() -> void:
	process_physics_priority = 100
	get_viewport().size_changed.connect(recenter)

func activate() -> bool:
	if active:
		return true
	# Save the legitimate run once, then never write its record store again.
	if not game.save_records():
		return false
	normal_records = game.records
	var isolated := Records.new(true)
	isolated.path = "user://test_inspection_records.json" if game.test_mode else "user://inspection_records.json"
	if FileAccess.file_exists(isolated.path):
		isolated.load_records()
	else:
		isolated.data = normal_records.data.duplicate(true)
	for key in ["music", "sfx", "muted"]:
		isolated.data[key] = normal_records.data[key]
	game.records = isolated
	active = true
	get_window().title = str(ProjectSettings.get_setting("application/config/name")) + " · 검증"
	build_dialog()
	return true

func build_dialog() -> void:
	dialog = AcceptDialog.new()
	dialog.title = "검증"
	dialog.theme = game.update_dialog.theme
	dialog.min_size = Vector2i(620, 310)
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "좌표로 이동"
	dialog.add_cancel_button("닫기")
	dialog.canceled.connect(close_panel)
	dialog.close_requested.connect(close_panel)
	dialog.window_input.connect(_input)
	dialog.confirmed.connect(func(): teleport(Vector2(coordinate_x.value, coordinate_y.value)))
	add_child(dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	dialog.add_child(box)
	position_label = Label.new()
	position_label.custom_minimum_size = Vector2(580, 26)
	box.add_child(position_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	add_label(row, "구간")
	room = spin(row, 1, TryCourse.COUNT)
	var go := Button.new()
	go.text = "입구로 이동"
	go.pressed.connect(func(): go_to_room(int(room.value)))
	row.add_child(go)
	var anchor := Button.new()
	anchor.text = "현재 위치를 출발점으로"
	anchor.pressed.connect(set_spawn_here)
	row.add_child(anchor)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	add_label(row, "X")
	coordinate_x = spin(row, 0, TryCourse.LENGTH)
	add_label(row, "Y")
	coordinate_y = spin(row, -4096, 4096)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	flight = CheckBox.new()
	flight.text = "자유 이동 · F9"
	flight.toggled.connect(set_flying)
	row.add_child(flight)
	invulnerable = CheckBox.new()
	invulnerable.text = "무적"
	invulnerable.toggled.connect(func(_value: bool): apply_flags())
	row.add_child(invulnerable)
	freeze_world = CheckBox.new()
	freeze_world.text = "비행 중 장치 정지"
	freeze_world.button_pressed = true
	freeze_world.toggled.connect(func(_value: bool): apply_flags())
	box.add_child(freeze_world)
	add_label(box, "Ctrl + 클릭  이동   WASD  비행   Shift  빠르게")

func add_label(parent: Node, value: String) -> void:
	var label := Label.new()
	label.text = value
	parent.add_child(label)

func spin(parent: Node, minimum: float, maximum: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	field.custom_minimum_size.x = 145
	parent.add_child(field)
	return field

func is_open() -> bool:
	return active and dialog.visible

func show_panel() -> void:
	if not activate(): return
	if dialog.visible:
		close_panel()
		return
	saved_mode = game.mode
	if game.mode == game.Mode.PLAYING:
		game.mode = game.Mode.PAUSED
		game.player.enabled = false
	room.value = clampi(int(game.player.position.x / TryCourse.CELL) + 1, 1, TryCourse.COUNT)
	coordinate_x.value = game.player.position.x
	coordinate_y.value = game.player.position.y
	position_label.text = "X %.0f   Y %.0f" % [game.player.position.x, game.player.position.y]
	dialog.popup_centered(Vector2i(620, 310))
	room.get_line_edit().grab_focus()

func close_panel() -> void:
	if not active: return
	dialog.hide()
	if saved_mode == game.Mode.PLAYING:
		game.resume_game()
	if flying:
		game.mode = game.Mode.PLAYING
		game.clear_overlay()
		game.hud.show()
	apply_flags()

func recenter() -> void:
	if is_open():
		dialog.position = Vector2i((get_viewport().get_visible_rect().size - Vector2(dialog.size)) / 2)

func apply_flags() -> void:
	if not active: return
	game.set_meta("inspection_flying", flying)
	game.set_meta("inspection_pause_world", flying and freeze_world.button_pressed)
	game.player.set_meta("inspection_invincible", flying or invulnerable.button_pressed)
	game.player.set_physics_process(not flying)

func set_flying(value: bool) -> void:
	if not active: return
	if value == flying:
		apply_flags()
		return
	if game.mode in [game.Mode.MENU, game.Mode.CLEAR, game.Mode.RECORDS]:
		game.start_run()
		if is_open(): saved_mode = game.Mode.PLAYING
	flying = value
	flight.set_pressed_no_signal(value)
	game.player.detach_chain()
	game.player.carrier = null
	game.player.velocity = Vector2.ZERO
	game.player.alive = true
	if not value:
		game.player.respawn(game.player.position)
	apply_flags()
	if is_open():
		game.mode = game.Mode.PAUSED
		game.player.enabled = false
	else:
		game.resume_game()

func go_to_room(number: int) -> bool:
	if not active or number < 1 or number > TryCourse.COUNT: return false
	set_flying(false)
	game.start_run()
	var target := Vector2((number - 1) * TryCourse.CELL + (100 if number == 1 else 64), TryCourse.FLOOR)
	replay_finale = number == 40
	var moved := teleport(target, false, true)
	after_respawn()
	return moved

func after_respawn() -> void:
	if not active or not replay_finale: return
	var relative_x: float = game.spawn_point.x - 39 * TryCourse.CELL
	if relative_x < 0 or relative_x > 96: return
	# Room 40 uses room 39's clock. Recreate the elapsed trip from its door.
	var previous: TryEncounter = game.traps[38]
	previous.arm()
	previous.clock = (TryCourse.CELL + 64 - 560) / TryPlayer.SPEED
	previous.auxiliary = 0
	previous.flags.finish = true

func teleport(target: Vector2, reset_encounters: bool = false, anchor: bool = false) -> bool:
	if not active or not is_finite(target.x) or not is_finite(target.y): return false
	if target.x < 0 or target.x > TryCourse.LENGTH or target.y < -4096 or target.y > 4096: return false
	if game.mode in [game.Mode.MENU, game.Mode.CLEAR, game.Mode.RECORDS]:
		game.start_run()
	if reset_encounters:
		for encounter in game.traps: encounter.reset()
	game.player.respawn(target)
	game.respawn_timer = 0
	game.shake = 0
	game.camera.offset = Vector2.ZERO
	if anchor:
		game.spawn_point = target
		game.checkpoint_index = -1
		for n in TryCourse.CHECKPOINTS.size():
			if target.x >= TryCourse.CHECKPOINTS[n].x: game.checkpoint_index = n
	game.camera.position = Vector2(game.camera_x(target.x + 130), target.y - 146 if flying else 270)
	game.resume_game()
	game.update_hud()
	dialog.hide()
	apply_flags()
	if reset_encounters: after_respawn()
	return true

func set_spawn_here() -> void:
	if active:
		game.spawn_point = game.player.position

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8 and event.ctrl_pressed and event.shift_pressed:
			show_panel()
			get_viewport().set_input_as_handled()
			return
		if active and event.keycode == KEY_F9:
			set_flying(not flying)
			get_viewport().set_input_as_handled()
			return
		if active and flying and not is_open() and event.is_action_pressed("retry"):
			teleport(game.spawn_point, true)
			get_viewport().set_input_as_handled()
			return
		if is_open() and event.keycode == KEY_ESCAPE:
			close_panel()
			get_viewport().set_input_as_handled()
			return
	if active and not is_open() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed:
		teleport(game.get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not active or not flying or is_open() or game.mode != game.Mode.PLAYING: return
	var direction := Input.get_vector("move_left", "move_right", "climb_up", "climb_down")
	var speed := flight_speed * (4 if Input.is_key_pressed(KEY_SHIFT) else 1)
	game.player.position += direction * speed * delta
	game.player.position.x = clampf(game.player.position.x, 0, TryCourse.LENGTH)
	game.player.position.y = clampf(game.player.position.y, -4096, 4096)
	game.player.velocity = Vector2.ZERO
	game.camera.position = game.player.position + Vector2(130, -146)
	game.player.queue_redraw()
