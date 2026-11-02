extends SceneTree

const ACTIONS := ["move_left", "move_right", "jump", "climb_up", "climb_down"]
var game: OneMoreGame
var data: Dictionary
var index := 0
var bits := 0
var completed := false
var diverged := false
var pause_points: Array[int] = []
var pause_remaining := 0
var pause_count := 0

class Driver extends Node:
	var owner_tree: SceneTree
	# Input.action_press stamps an edge for the NEXT physics tick. Apply the
	# next tape entry after every body and encounter has finished this tick.
	func _ready() -> void: process_physics_priority = 1000
	func _physics_process(_delta: float) -> void: owner_tree.drive()

func _initialize() -> void: call_deferred("run")
func apply_input(next: int) -> void:
	for n in ACTIONS.size():
		if (next & (1 << n)) != (bits & (1 << n)):
			if next & (1 << n): Input.action_press(ACTIONS[n])
			else: Input.action_release(ACTIONS[n])
	bits = next
func run() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://build/course-replay.json"))
	if "--pauses" in OS.get_cmdline_user_args():
		for number in [6,20,29]:
			for n in data.frames.size():
				var x: float = float(data.positions[n][0]) - (number - 1) * 640
				var y: float = data.positions[n][1]
				var input: int = data.frames[n]
				if (number == 6 and x > 250 and x < 350 and y > 410 and y < 420 and input == 0) or (number == 20 and x > 420 and x < 520 and y < 300 and input == 8) or (number == 29 and x > 230 and x < 245 and y > 360 and y < 400 and input == 0):
					pause_points.append(n + 1)
					break
		assert(pause_points.size() == 3, "Replay must pause on a moving platform, chain and lift")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://replay-records.json"
	game.start_run()
	apply_input(int(data.frames[0]))
	var driver := Driver.new()
	driver.owner_tree = self
	root.add_child(driver)

func drive() -> void:
	if completed: return
	if pause_remaining > 0:
		pause_remaining -= 1
		if pause_remaining == 0:
			game.resume_game()
			apply_input(int(data.frames[index]))
		return
	var expected := Vector2(float(data.positions[index][0]), float(data.positions[index][1]))
	if not diverged and game.player.position.distance_to(expected) > 0.1:
		print("FIRST DIVERGENCE tick=",index," actual=",game.player.position," expected=",expected," bits=",bits)
		diverged = true
	index += 1
	if index == data.frames.size():
		completed = true
		var passed := not diverged and game.mode == OneMoreGame.Mode.CLEAR and game.run_deaths == 0 and game.checkpoint_index == 1 and game.secret_collected and absf(game.player.position.x - float(data.x)) < 0.1 and absf(game.elapsed - float(data.time)) < 0.01
		print("REPLAY %s physics_ticks=%d render_frames=%d position=%.3f time=%.3f deaths=%d pauses=%d" % ["PASS" if passed else "FAIL", index, Engine.get_process_frames(), game.player.position.x, game.elapsed, game.run_deaths, pause_count])
		for action in ACTIONS: Input.action_release(action)
		game.queue_free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://replay-records.json"))
		quit(0 if passed else 1)
		return
	if index in pause_points:
		game.pause_game()
		pause_remaining = 24
		pause_count += 1
	else:
		apply_input(int(data.frames[index]))
