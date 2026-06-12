## Flap & Build game world. See AGENTS.md for the full spec.
##
## Authority model:
##   - LOCAL / HOST: this node simulates physics, pipes, scoring and blocks.
##   - CLIENT: renders state received from the host and forwards Builder
##     placement requests.
## Role assignment in network modes: host = Flapper, client = Builder
## (the Flapper needs zero input latency, so it always runs on the host).
extends Node2D

const VIEW := Vector2(1280, 720)
const SCROLL_SPEED := 200.0
const PIPE_INTERVAL := 2.2
const PIPE_GAP := 230.0
const PIPE_WIDTH := 90.0
const PIPE_MARGIN := 150.0      # min distance of the gap center from edges
const GROUND_H := 60.0
const BLOCK_SIZE := Vector2(120, 24)
const BLOCK_LIFETIME := 5.0
const FLAPPER_START := Vector2(320, 320)

signal exited

var flapper: Flapper
var builder: Builder
var scroll_root: Node2D     # pipes and blocks live here; the root scrolls left
var score := 0
var playing := true
var pipe_timer := 1.5
## Host-side cooldown tracking for the remote Builder ("Local Server" mode).
var remote_cooldown := 0.0

var hud: CanvasLayer
var score_label: Label
var cooldown_bar: ProgressBar
var over_box: VBoxContainer
var over_label: Label


func _ready() -> void:
	_build_world()
	_build_players()
	_build_hud()


# --- Scene construction (all original code-drawn art) ----------------------

func _build_world() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.45, 0.75, 0.95)
	sky.size = VIEW
	add_child(sky)

	scroll_root = Node2D.new()
	add_child(scroll_root)

	# Ground: a hazard strip across the bottom (touching it ends the run).
	var ground := _make_rect_body(
		Vector2(VIEW.x, GROUND_H), Vector2(VIEW.x / 2.0, VIEW.y - GROUND_H / 2.0),
		Color(0.35, 0.25, 0.15), "hazard")
	add_child(ground)


func _build_players() -> void:
	flapper = Flapper.new()
	flapper.position = FLAPPER_START
	flapper.died.connect(_on_flapper_died)
	add_child(flapper)

	builder = Builder.new()
	# Role wiring per mode: in LOCAL both roles share the device; in HOST
	# the Builder is the remote client, so the local builder is disabled.
	match Net.mode:
		Net.Mode.LOCAL:
			builder.local_split = true
		Net.Mode.HOST:
			builder.active = false
		Net.Mode.CLIENT:
			builder.local_split = false
	builder.place_requested.connect(_on_place_requested)
	add_child(builder)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 56)
	score_label.position = Vector2(VIEW.x / 2.0 - 20, 24)
	hud.add_child(score_label)

	# Builder cooldown bar (only meaningful when this peer can build).
	cooldown_bar = ProgressBar.new()
	cooldown_bar.size = Vector2(220, 18)
	cooldown_bar.position = Vector2(VIEW.x - 244, VIEW.y - 36)
	cooldown_bar.show_percentage = false
	cooldown_bar.visible = Net.mode != Net.Mode.HOST
	hud.add_child(cooldown_bar)

	# Game-over panel, hidden until the run ends.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(center)
	over_box = VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 10)
	over_box.visible = false
	center.add_child(over_box)
	over_label = Label.new()
	over_label.add_theme_font_size_override("font_size", 40)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(over_label)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(220, 48)
	restart.pressed.connect(_on_restart_pressed)
	over_box.add_child(restart)
	var quit := Button.new()
	quit.text = "Back to Menu"
	quit.custom_minimum_size = Vector2(220, 48)
	quit.pressed.connect(func() -> void: exited.emit())
	over_box.add_child(quit)


## Helper: solid rectangle body with a flat-colored visual, in a group that
## defines its gameplay role ("hazard" kills, "platform" is safe to land on).
func _make_rect_body(size: Vector2, pos: Vector2, color: Color, group: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	body.add_to_group(group)
	var visual := Polygon2D.new()
	var half := size / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	visual.color = color
	body.add_child(visual)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	return body


# --- Input (Flapper side) ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not playing or Net.mode == Net.Mode.CLIENT:
		return  # the client is the Builder; it never controls the Flapper
	# Keyboard flap (desktop/web).
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		flapper.flap()
		return
	# Touch / click flap. In local split-screen mode only the LEFT half flaps.
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = true
	if not pressed:
		return
	if Net.mode == Net.Mode.LOCAL \
			and pos.x >= get_viewport().get_visible_rect().size.x * 0.5:
		return  # right half belongs to the Builder in local mode
	flapper.flap()


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	remote_cooldown = maxf(remote_cooldown - delta, 0.0)
	cooldown_bar.value = (1.0 - builder.cooldown_left / Builder.COOLDOWN) * 100.0
	if not playing:
		return
	# Both sides scroll locally for smoothness; the host's sync corrects drift.
	scroll_root.position.x -= SCROLL_SPEED * delta
	if Net.mode == Net.Mode.CLIENT:
		return

	flapper.step_physics(delta)

	pipe_timer -= delta
	if pipe_timer <= 0.0:
		pipe_timer = PIPE_INTERVAL
		var gap_y := randf_range(PIPE_MARGIN, VIEW.y - GROUND_H - PIPE_MARGIN)
		# World x inside scroll_root so the pipe appears just off-screen right.
		var world_x := -scroll_root.position.x + VIEW.x + PIPE_WIDTH
		_spawn_pipe(world_x, gap_y)
		if Net.mode == Net.Mode.HOST:
			_spawn_pipe_remote.rpc(world_x, gap_y)

	_score_and_cleanup()

	if Net.mode == Net.Mode.HOST:
		_sync.rpc(flapper.position, flapper.rotation, scroll_root.position.x, score)


func _score_and_cleanup() -> void:
	for pipe in get_tree().get_nodes_in_group("pipe"):
		var pipe_global_x: float = pipe.position.x + scroll_root.position.x
		# Score once when the pipe pair fully passes the bird.
		if not pipe.get_meta("scored") and pipe_global_x + PIPE_WIDTH < flapper.position.x:
			pipe.set_meta("scored", true)
			score += 1
			score_label.text = str(score)
		if pipe_global_x < -200.0:
			pipe.queue_free()


# --- Pipes ------------------------------------------------------------------

func _spawn_pipe(world_x: float, gap_y: float) -> void:
	var pair := Node2D.new()
	pair.position = Vector2(world_x, 0)
	pair.add_to_group("pipe")
	pair.set_meta("scored", false)
	var top_h := gap_y - PIPE_GAP / 2.0
	var bottom_y := gap_y + PIPE_GAP / 2.0
	var bottom_h := VIEW.y - GROUND_H - bottom_y
	var green := Color(0.2, 0.65, 0.3)
	pair.add_child(_make_rect_body(
		Vector2(PIPE_WIDTH, top_h), Vector2(0, top_h / 2.0), green, "hazard"))
	pair.add_child(_make_rect_body(
		Vector2(PIPE_WIDTH, bottom_h), Vector2(0, bottom_y + bottom_h / 2.0),
		green, "hazard"))
	scroll_root.add_child(pair)


@rpc("authority", "call_remote", "reliable")
func _spawn_pipe_remote(world_x: float, gap_y: float) -> void:
	_spawn_pipe(world_x, gap_y)


# --- Builder blocks ---------------------------------------------------------

func _on_place_requested(screen_pos: Vector2) -> void:
	if Net.mode == Net.Mode.CLIENT:
		# Forward to the host; the host validates and spawns authoritatively.
		_request_place.rpc_id(1, screen_pos)
	else:
		_try_place(screen_pos)


@rpc("any_peer", "call_remote", "reliable")
func _request_place(screen_pos: Vector2) -> void:
	# Runs on the host when the remote Builder taps.
	if not playing:
		return
	if Net.strict_validation:
		# "Local Server" mode: never trust the client. Re-check the cooldown
		# and clamp the position to the visible play area.
		if remote_cooldown > 0.0:
			return
		if screen_pos.x < 0.0 or screen_pos.x > VIEW.x \
				or screen_pos.y < 0.0 or screen_pos.y > VIEW.y - GROUND_H:
			return
	remote_cooldown = Builder.COOLDOWN
	_try_place(screen_pos)


func _try_place(screen_pos: Vector2) -> void:
	# Convert the tap position into scroll-space so the block scrolls with
	# the world like everything else.
	var world_pos := screen_pos - scroll_root.position
	_spawn_block(world_pos)
	if Net.mode == Net.Mode.HOST:
		_spawn_block_remote.rpc(world_pos)


@rpc("authority", "call_remote", "reliable")
func _spawn_block_remote(world_pos: Vector2) -> void:
	_spawn_block(world_pos)


func _spawn_block(world_pos: Vector2) -> void:
	var block := _make_rect_body(
		BLOCK_SIZE, world_pos, Color(0.9, 0.5, 0.2), "platform")
	scroll_root.add_child(block)
	# Temporary platform: fade out near the end of its lifetime, then free.
	var tween := block.create_tween()
	tween.tween_interval(BLOCK_LIFETIME - 1.0)
	tween.tween_property(block, "modulate:a", 0.0, 1.0)
	tween.tween_callback(block.queue_free)


# --- Game over / restart ----------------------------------------------------

func _on_flapper_died() -> void:
	_show_game_over()
	if Net.mode == Net.Mode.HOST:
		_game_over_remote.rpc(score)


@rpc("authority", "call_remote", "reliable")
func _game_over_remote(final_score: int) -> void:
	score = final_score
	_show_game_over()


func _show_game_over() -> void:
	playing = false
	over_label.text = "Game Over — Score: %d" % score
	over_box.visible = true


func _on_restart_pressed() -> void:
	if Net.mode == Net.Mode.CLIENT:
		_request_restart.rpc_id(1)  # only the host may restart the match
	else:
		_restart()
		if Net.mode == Net.Mode.HOST:
			_restart_remote.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _request_restart() -> void:
	if not playing:  # ignore spurious requests mid-run
		_restart()
		_restart_remote.rpc()


@rpc("authority", "call_remote", "reliable")
func _restart_remote() -> void:
	_restart()


func _restart() -> void:
	for node in get_tree().get_nodes_in_group("pipe"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("platform"):
		node.queue_free()
	scroll_root.position = Vector2.ZERO
	flapper.reset(FLAPPER_START)
	score = 0
	score_label.text = "0"
	pipe_timer = 1.5
	over_box.visible = false
	playing = true


# --- Client-side state sync -------------------------------------------------

@rpc("authority", "call_remote", "unreliable")
func _sync(flapper_pos: Vector2, flapper_rot: float, scroll_x: float, new_score: int) -> void:
	flapper.position = flapper_pos
	flapper.rotation = flapper_rot
	# Snap scroll to the host's value; local scrolling covers the frames between.
	scroll_root.position.x = scroll_x
	if new_score != score:
		score = new_score
		score_label.text = str(score)
