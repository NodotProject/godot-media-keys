extends Node
## Autoload node that polls MediaKeys events every frame
## This node is automatically added to the scene tree to ensure
## media key events are processed and emitted to connected listeners

var media_keys: Object = null

func _ready():
	# Get the MediaKeys singleton
	if Engine.has_singleton("MediaKeys"):
		media_keys = Engine.get_singleton("MediaKeys")
	else:
		push_error("MediaKeys autoload: MediaKeys singleton not found!")

func _process(_delta):
	if media_keys:
		# Poll events from the worker thread and emit signals
		media_keys.poll_events_from_main_thread()
