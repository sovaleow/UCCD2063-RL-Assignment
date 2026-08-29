extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound: AudioStreamPlayer2D = $CollectedSound


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var collected := false

func _on_body_entered(body: Node2D) -> void:
	if collected or body.name != "Player":
		return
	collected = true
	animated_sprite_2d.animation = "collected"
	collected_sound.play()
	GameState.collect_apple()
	$CollisionShape2D.set_deferred("disabled", true)
	await collected_sound.finished
	queue_free()
