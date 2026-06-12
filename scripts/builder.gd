## Player A controller: requests temporary platform placements with a cooldown.
## Input zoning:
##   - LOCAL mode: only the RIGHT half of the screen belongs to the Builder
##     (the left half is the Flapper's tap zone).
##   - CLIENT mode: the whole screen is the Builder's.
## The cooldown here drives the local UI; the authoritative cooldown check
## lives in the game world ("Local Server" strict validation).
class_name Builder
extends Node

const COOLDOWN := 3.0

signal place_requested(screen_pos: Vector2)

var cooldown_left := 0.0
var active := true
## True when sharing the screen with the Flapper (local same-device mode).
var local_split := false


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Accept both touch (mobile) and left mouse click (desktop/web).
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
	# In split-screen local mode, ignore taps on the Flapper's half.
	if local_split and pos.x < get_viewport().get_visible_rect().size.x * 0.5:
		return
	if cooldown_left > 0.0:
		return
	cooldown_left = COOLDOWN
	place_requested.emit(pos)
