extends Control

@onready var event_label = $EventLabel
var events: Array[String] = []

func _ready():
	# Check if MediaKeys singleton exists
	if not Engine.has_singleton("MediaKeys"):
		event_label.text = "ERROR: MediaKeys singleton not found!"
		push_error("MediaKeys singleton not found!")
		return

	# Get the singleton
	var media_keys = Engine.get_singleton("MediaKeys")

	# Connect to the media_key_pressed signal
	if media_keys.connect("media_key_pressed", _on_media_key_pressed) != OK:
		event_label.text = "ERROR: Failed to connect to media_key_pressed signal!"
		push_error("Failed to connect to media_key_pressed signal!")
		return

	event_label.text = "Ready! Waiting for media key events..."
	print("MediaKeys test scene ready. Press media keys to test.")

func _on_media_key_pressed(key: int):
	var key_name = ""
	match key:
		0:  # MEDIA_KEY_PLAY_PAUSE
			key_name = "Play/Pause"
		1:  # MEDIA_KEY_NEXT
			key_name = "Next"
		2:  # MEDIA_KEY_PREVIOUS
			key_name = "Previous"
		3:  # MEDIA_KEY_STOP
			key_name = "Stop"
		_:
			key_name = "Unknown (%d)" % key

	var event_text = "Media key pressed: %s" % key_name
	print(event_text)

	# Add to events list (keep last 10)
	events.append(event_text)
	if events.size() > 10:
		events.pop_front()

	# Update label with all events
	event_label.text = "\n".join(events)
