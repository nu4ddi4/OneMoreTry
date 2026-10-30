class_name OneMoreGame
extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")
const TrapScript = preload("res://scripts/trap.gd")
const RecordsScript = preload("res://scripts/records.gd")
const SoundScript = preload("res://scripts/sound.gd")
const INK := Color("203c40")
const CREAM := Color("f4ecd4")
const MINT := Color("84dfb7")
const MUTED := Color("a2bcb3")

enum Mode { MENU, PLAYING, PAUSED, CLEAR, RECORDS }
var mode: Mode = Mode.MENU
var player: TryPlayer
var world: TryWorld
var camera: Camera2D
var sound: TrySound
var records: TryRecords
var traps: Array[TryTrap] = []
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
var checkpoint_label: Label
var toast_label: Label
var toast_clock := 0.0
var progress: ColorRect
var new_best := false
var test_mode := false

func _ready() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	configure_input()
	font = load("res://assets/fonts/OneMoreSans.otf")
	records = RecordsScript.new(test_mode)
	sound = SoundScript.new()
	add_child(sound)
	sound.sfx_on = records.data.sfx and not test_mode
	sound.set_music(records.data.music and not test_mode)
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
	build_ui()
	show_menu()
	get_window().focus_exited.connect(func():
		if mode == Mode.PLAYING and not test_mode:
			pause_game())
	get_tree().auto_accept_quit = false

func configure_input() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "retry": [KEY_R], "pause_game": [KEY_ESCAPE], "fullscreen": [KEY_F11], "mute": [KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func build_traps() -> void:
	for i in range(3):
		add_trap(TryTrap.Kind.CRUMBLE, Vector2(640 + i * 48, 416), Vector2(48, 20))
	add_trap(TryTrap.Kind.SPRING, Vector2(1000, 416), Vector2(80, 24))
	add_trap(TryTrap.Kind.FALLING, Vector2(1232, 150), Vector2(56, 48))
	for i in range(2):
		add_trap(TryTrap.Kind.CRUMBLE, Vector2(1664 + i * 48, 416), Vector2(48, 18))
	add_trap(TryTrap.Kind.SPIKES, Vector2(1990, 416), Vector2(64, 24))
	add_trap(TryTrap.Kind.SPRING, Vector2(2670, 416), Vector2(80, 24))
	for i in range(4):
		add_trap(TryTrap.Kind.CRUMBLE, Vector2(2864 + i * 44, 416), Vector2(44, 20))
	add_trap(TryTrap.Kind.SPIKES, Vector2(3160, 416), Vector2(80, 24))

func add_trap(kind: TryTrap.Kind, at: Vector2, size: Vector2) -> void:
	var trap := TrapScript.new()
	trap.kind = kind
	trap.position = at
	trap.size = size
	trap.game = self
	add_child(trap)
	traps.append(trap)

func interaction_enabled() -> bool:
	return mode == Mode.PLAYING and player != null and player.alive

func start_run() -> void:
	mode = Mode.PLAYING
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
	camera.position = Vector2(480, 270)
	sound.quiet(false)
	clear_overlay()
	hud.show()
	toast("01  튜토리얼?  ·  쉬워 보인다고 방심하지 마세요.", 3.0)
	update_hud()

func _physics_process(delta: float) -> void:
	if mode == Mode.PLAYING:
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
				toast("숨겨진 별 발견!  ·  의심 많은 모험가", 3)
			if player.position.x >= TryWorld.GOAL - 12 and player.position.y <= 420 and player.position.y >= 350:
				finish_run()
		update_hud()
	player.enabled = mode == Mode.PLAYING
	if mode == Mode.PLAYING or mode == Mode.CLEAR:
		var target := clampf(player.position.x + 130, 480, TryWorld.LENGTH - 480)
		camera.position.x = lerpf(camera.position.x, target, 1.0 - exp(-delta * 9))
		camera.position.y = 270

func _process(delta: float) -> void:
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
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("mute"):
		var on := not (sound.music_on or sound.sfx_on)
		records.data.music = on
		records.data.sfx = on
		sound.sfx_on = on
		sound.set_music(on)
		save_records()
		toast("소리 켜짐" if on else "소리 꺼짐", 1.4)
	elif event.is_action_pressed("pause_game"):
		if mode == Mode.PLAYING:
			pause_game()
		elif mode == Mode.PAUSED:
			resume_game()
		elif mode == Mode.RECORDS:
			show_menu()
	elif event.is_action_pressed("retry") and mode == Mode.PLAYING and player.alive:
		player.die("좋아요. 바로 한 번 더!")
		respawn_timer = 0.0
	elif event.is_action_pressed("jump") and mode == Mode.MENU:
		start_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if records:
			save_records()
		get_tree().quit()

func on_death(reason: String) -> void:
	run_deaths += 1
	records.data.deaths += 1
	save_records()
	respawn_timer = 0.38
	shake = 4.0
	sound.effect("death")
	burst(player.position + Vector2(0, -16), MINT, 18)
	var milestone: Dictionary = {1: "처음이니까 봐드립니다.", 10: "이제 익숙해지셨죠?", 30: "이 정도면 외우실 때도 됐는데...", 50: "여기까지 온 것도 실력입니다.", 100: "제작자도 이렇게까지는 예상 못 했습니다."}
	toast(milestone.get(int(records.data.deaths), reason), 2.5)

func respawn() -> void:
	for trap in traps:
		trap.reset()
	player.respawn(spawn_point)
	respawn_timer = 0
	camera.position.x = clampf(spawn_point.x + 130, 480, TryWorld.LENGTH - 480)

func activate_checkpoint(index: int) -> void:
	checkpoint_index = index
	spawn_point = TryWorld.CHECKPOINTS[index] + Vector2(24, 0)
	sound.effect("checkpoint")
	burst(TryWorld.CHECKPOINTS[index] + Vector2(5, -55), Color("f5d68a"), 15)
	toast("체크포인트 %d  ·  이제 여기서 다시 시작합니다." % (index + 1), 2.4)

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
	save_records()
	sound.quiet(true)
	sound.effect("clear")
	toast_clock = 0
	show_clear()

func save_records() -> void:
	if not records.save() and toast_label:
		toast(records.last_error, 4)

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
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	panel(hud, Vector2(20, 18), Vector2(920, 62), Color("203c40f2"))
	text(hud, "01", Vector2(38, 27), Vector2(36, 36), 25, MINT)
	text(hud, "튜토리얼?", Vector2(87, 26), Vector2(180, 25), 20)
	text(hud, "MEADOW MISCHIEF", Vector2(88, 53), Vector2(180, 15), 10, MUTED)
	checkpoint_label = text(hud, "", Vector2(330, 34), Vector2(230, 30), 14, MUTED)
	death_label = text(hud, "", Vector2(595, 30), Vector2(145, 35), 19)
	time_label = text(hud, "", Vector2(762, 30), Vector2(150, 35), 19, MINT)
	var track := ColorRect.new()
	track.position = Vector2(21, 78)
	track.size = Vector2(918, 3)
	track.color = Color("395850")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(track)
	progress = ColorRect.new()
	progress.size = Vector2(0, 3)
	progress.color = MINT
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(progress)
	panel(hud, Vector2(20, 490), Vector2(920, 31), Color("203c40e8"))
	text(hud, "A / D  이동     SPACE  점프     R  재도전", Vector2(34, 495), Vector2(550, 20), 11, MUTED)
	text(hud, "ESC  일시정지     M  음소거     F11  전체 화면", Vector2(598, 495), Vector2(330, 20), 11, MUTED)
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
	death_label.text = "실패  %03d" % run_deaths
	time_label.text = format_time(elapsed)
	checkpoint_label.text = "CHECKPOINT  %d / 2" % (checkpoint_index + 1)
	progress.size.x = clampf((player.position.x - 100) / (TryWorld.GOAL - 100), 0, 1) * 918

static func format_time(seconds: float) -> String:
	var centis := int(seconds * 100)
	return "%02d:%02d.%02d" % [centis / 6000, (centis / 100) % 60, centis % 100]

func show_menu() -> void:
	mode = Mode.MENU
	particles.clear()
	player.enabled = false
	player.respawn(Vector2(100, 416))
	camera.position = Vector2(480, 270)
	camera.offset = Vector2.ZERO
	checkpoint_index = -1
	for trap in traps:
		trap.reset()
	hud.hide()
	toast_clock = 0
	sound.quiet(false)
	clear_overlay()
	var card := panel(overlay, Vector2(64, 64), Vector2(832, 309))
	text(card, "A LITTLE PLATFORMER. A LOT OF SECOND CHANCES.", Vector2(32, 22), Vector2(720, 20), 11, MINT)
	text(card, "한 번만 더!", Vector2(27, 48), Vector2(500, 87), 57)
	text(card, "ONE MORE TRY!", Vector2(33, 139), Vector2(400, 28), 21, MINT)
	text(card, "쉬운 조작. 수상한 바닥. 그리고 빠른 재도전.", Vector2(33, 179), Vector2(510, 28), 16, MUTED)
	var start := button(card, "도전하기  →", Vector2(32, 233), Vector2(208, 48), start_run, true)
	button(card, "내 기록", Vector2(252, 233), Vector2(104, 48), show_records)
	button(card, "종료", Vector2(368, 233), Vector2(80, 48), quit_game)
	panel(card, Vector2(573, 58), Vector2(225, 223), Color("2d4b48"))
	text(card, "첫 번째 도전", Vector2(592, 76), Vector2(180, 23), 13, MINT)
	text(card, "01  튜토리얼?", Vector2(592, 111), Vector2(200, 32), 23)
	text(card, "초원 · 체크포인트 2개\n함정 3종 · 숨겨진 길 1개", Vector2(592, 154), Vector2(200, 52), 13, MUTED)
	text(card, "실패해도, 0.5초면 다시.", Vector2(592, 234), Vector2(200, 24), 13, Color("f5ce95"))
	text(overlay, "A / D 또는 ← →  이동     SPACE  점프 / 시작     F11  전체 화면", Vector2(64, 472), Vector2(830, 28), 13, CREAM)
	text(overlay, "WINDOWS  /  MVP 0.1.0", Vector2(65, 508), Vector2(400, 18), 10, Color("b5c4a2"))
	start.grab_focus()
	if not records.last_error.is_empty():
		toast(records.last_error, 5)

func pause_game() -> void:
	mode = Mode.PAUSED
	player.enabled = false
	sound.quiet(true)
	clear_overlay()
	var card := panel(overlay, Vector2(270, 138), Vector2(420, 315))
	text(card, "잠깐, 숨 고르기.", Vector2(30, 22), Vector2(365, 42), 29)
	text(card, "시간과 함정도 함께 멈춥니다.", Vector2(30, 73), Vector2(360, 24), 14, MUTED)
	var resume := button(card, "계속하기  →", Vector2(30, 115), Vector2(360, 43), resume_game, true)
	button(card, "처음부터 재도전", Vector2(30, 169), Vector2(174, 40), start_run)
	button(card, "타이틀로", Vector2(216, 169), Vector2(174, 40), show_menu)
	button(card, "음악 " + ("켜짐" if records.data.music else "꺼짐"), Vector2(30, 225), Vector2(174, 36), func():
		records.data.music = not records.data.music
		sound.set_music(records.data.music)
		save_records()
		pause_game())
	button(card, "효과음 " + ("켜짐" if records.data.sfx else "꺼짐"), Vector2(216, 225), Vector2(174, 36), func():
		records.data.sfx = not records.data.sfx
		sound.sfx_on = records.data.sfx
		save_records()
		pause_game())
	text(card, "ESC  계속하기", Vector2(30, 279), Vector2(360, 20), 11, MUTED)
	resume.grab_focus()

func resume_game() -> void:
	mode = Mode.PLAYING
	player.enabled = true
	sound.quiet(false)
	clear_overlay()

func show_clear() -> void:
	clear_overlay()
	var card := panel(overlay, Vector2(235, 118), Vector2(490, 336))
	text(card, "STAGE 01  /  CLEAR", Vector2(30, 20), Vector2(420, 23), 13, MINT)
	text(card, "결국, 해냈네요!", Vector2(27, 52), Vector2(440, 53), 36)
	text(card, "처음에는 억울했지만, 이제는 내 실력.", Vector2(30, 112), Vector2(430, 28), 15, MUTED)
	text(card, "클리어 시간", Vector2(31, 161), Vector2(210, 24), 13, MUTED)
	text(card, format_time(elapsed), Vector2(31, 187), Vector2(230, 39), 27)
	text(card, "이번 도전의 실패", Vector2(279, 161), Vector2(180, 24), 13, MUTED)
	text(card, "%d회" % run_deaths, Vector2(279, 187), Vector2(180, 39), 27, MINT)
	var badge := "개인 최고 기록!" if new_best else "최고 기록  " + format_time(records.data.best_time)
	if run_deaths == 0:
		badge += "  ·  노데스!"
	if secret_collected:
		badge += "  ·  비밀 발견"
	text(card, badge, Vector2(31, 231), Vector2(438, 25), 13, Color("f5ce95"))
	var again := button(card, "한 번만 더!", Vector2(30, 275), Vector2(241, 40), start_run, true)
	button(card, "타이틀로", Vector2(283, 275), Vector2(177, 40), show_menu)
	again.grab_focus()

func show_records() -> void:
	mode = Mode.RECORDS
	clear_overlay()
	var card := panel(overlay, Vector2(235, 76), Vector2(490, 368))
	text(card, "MY LITTLE ACHIEVEMENTS", Vector2(30, 20), Vector2(430, 22), 11, MINT)
	text(card, "도전의 흔적", Vector2(27, 51), Vector2(435, 50), 34)
	var values := ["최단 클리어", "도전 / 클리어", "총 실패", "노데스 클리어", "숨겨진 별"]
	var stats := [format_time(records.data.best_time) if records.data.best_time > 0 else "아직 도전 중", "%d / %d" % [records.data.attempts, records.data.clears], "%d회" % records.data.deaths, "달성!" if records.data.no_death else "다음 도전에서!", "발견!" if records.data.secret else "아직은 비밀"]
	for i in range(5):
		text(card, values[i], Vector2(32, 118 + i * 33), Vector2(230, 26), 14, MUTED)
		var value := text(card, stats[i], Vector2(250, 118 + i * 33), Vector2(206, 26), 15)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := button(card, "돌아가기", Vector2(30, 306), Vector2(430, 40), show_menu, true)
	back.grab_focus()

func quit_game() -> void:
	save_records()
	get_tree().quit()
