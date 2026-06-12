## Player B character: flies with vertical impulses against constant gravity.
## Only the simulation authority (local play or LAN host) runs physics here;
## on clients the body is positioned directly from synced state.
class_name Flapper
extends CharacterBody2D

const GRAVITY := 1500.0
const FLAP_IMPULSE := -450.0
const MAX_FALL_SPEED := 900.0

signal died

var alive := true


func _ready() -> void:
	# Visual: flat-style yellow bird (original code-drawn art, no assets).
	var body := Polygon2D.new()
	body.polygon = _circle(18.0, 20)
	body.color = Color(1.0, 0.84, 0.2)
	add_child(body)

	var eye := Polygon2D.new()
	eye.polygon = _circle(4.0, 10)
	eye.color = Color(0.12, 0.12, 0.12)
	eye.position = Vector2(8, -6)
	add_child(eye)

	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(2, -4), Vector2(2, 6)])
	wing.color = Color(0.95, 0.65, 0.1)
	add_child(wing)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)


static func _circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func flap() -> void:
	if alive:
		velocity.y = FLAP_IMPULSE


## Called by the game world each physics frame, authority side only.
func step_physics(delta: float) -> void:
	if not alive:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	# The ceiling does not kill: clamp upward motion at the top of the screen.
	if position.y < 24.0 and velocity.y < 0.0:
		velocity.y = 0.0
		position.y = 24.0
	move_and_slide()
	# Lean into the movement for the classic flappy feel.
	rotation = clampf(velocity.y / 900.0, -0.5, 1.2)
	# Touching any hazard (pipes or ground) ends the run. Builder platforms
	# are in a separate "platform" group and are safe to land on.
	for i in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider != null and collider.is_in_group("hazard"):
			alive = false
			died.emit()
			return


func reset(start_position: Vector2) -> void:
	position = start_position
	velocity = Vector2.ZERO
	rotation = 0.0
	alive = true
