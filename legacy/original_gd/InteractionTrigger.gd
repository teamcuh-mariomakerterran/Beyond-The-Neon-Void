extends Area2D

signal interacted(trigger_id: String)

@export var trigger_id: String = "default"
@export var interaction_text: String = "Interact"

var player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if player_inside and event.is_action_pressed("interact"):
		interacted.emit(trigger_id)
		UIManager.hide_interaction_prompt()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = true
		UIManager.show_interaction_prompt(interaction_text)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = false
		UIManager.hide_interaction_prompt()