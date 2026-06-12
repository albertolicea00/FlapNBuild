## Automated smoke playtest (headless-friendly).
## Boots the real game in LOCAL mode and drives both roles programmatically:
## the Flapper flaps on a timer, the Builder places blocks on a timer.
## Verifies the full loop: play -> die -> game over -> restart -> play.
## Run with: godot --headless res://tests/playtest.tscn
extends Node

const MAX_TIME := 45.0

var main: Node
var game: Node2D
var phase := "play"
var t := 0.0
var flap_timer := 0.0
var place_timer := 1.0
var died_once := false
var restarted := false
var max_score := 0

func _ready() -> void:
	main = $Main
	await get_tree().process_frame
	main._on_local()
	game = main.game
	print("[playtest] FlapNBuild started in LOCAL mode")


func _physics_process(delta: float) -> void:
	if game == null:
		return
	t += delta
	max_score = maxi(max_score, game.score)
	match phase:
		"play":
			# Drive the Flapper: flap cadence roughly hovers, drifts into pipes.
			flap_timer -= delta
			if flap_timer <= 0.0:
				flap_timer = 0.42
				game.flapper.flap()
			# Drive the Builder: place a platform ahead every few seconds.
			place_timer -= delta
			if place_timer <= 0.0:
				place_timer = 3.2
				game._try_place(Vector2(900, 320))
			if not game.playing:
				died_once = true
				print("[playtest] game over at t=%.1fs score=%d pipes=%d platforms=%d" % [
					t, game.score,
					get_tree().get_nodes_in_group("pipe").size(),
					get_tree().get_nodes_in_group("platform").size()])
				phase = "restart"
		"restart":
			game._on_restart_pressed()
			restarted = game.playing and game.score == 0
			print("[playtest] restart -> playing=%s score=%d" % [game.playing, game.score])
			phase = "second"
		"second":
			# Short second run to confirm the restarted state actually plays.
			flap_timer -= delta
			if flap_timer <= 0.0:
				flap_timer = 0.42
				game.flapper.flap()
			if t > 30.0 or not game.playing:
				_finish()
	if t > MAX_TIME:
		_finish()


func _finish() -> void:
	var ok := died_once and restarted
	print("[playtest] RESULT: %s | died_once=%s restarted=%s max_score=%d" % [
		"PASS" if ok else "FAIL", died_once, restarted, max_score])
	get_tree().quit(0 if ok else 1)
