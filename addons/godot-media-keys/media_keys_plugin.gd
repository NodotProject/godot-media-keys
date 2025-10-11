@tool
extends EditorPlugin

const AUTOLOAD_NAME = "MediaKeysAutoload"

func _enter_tree():
	# Register the autoload that polls media key events every frame
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/godot-media-keys/media_keys_autoload.gd")

func _exit_tree():
	# Remove the autoload when the plugin is disabled
	remove_autoload_singleton(AUTOLOAD_NAME)
