extends Node3D

const ArenaManager := preload("res://scripts/arena_manager.gd")

var arena

func _ready() -> void:
	arena = ArenaManager.new()
	arena.name = "Arena"
	add_child(arena)
