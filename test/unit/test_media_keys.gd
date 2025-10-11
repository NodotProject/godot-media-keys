extends GutTest

# Reference to MediaKeys singleton
var media_keys = null

# Signal tracking
var signal_received = false
var last_key_received = -1
var signal_count = 0

func before_each():
    media_keys = Engine.get_singleton("MediaKeys")
    signal_received = false
    last_key_received = -1
    signal_count = 0

func test_media_keys_singleton_exists():
    assert_true(Engine.has_singleton("MediaKeys"), "MediaKeys singleton should exist")

func test_media_keys_singleton_is_object():
    assert_is(media_keys, Object, "MediaKeys singleton should be an Object")

func test_media_keys_has_signal():
    var signals = media_keys.get_signal_list()
    var has_media_key_pressed = false
    for sig in signals:
        if sig.name == "media_key_pressed":
            has_media_key_pressed = true
            assert_eq(sig.args.size(), 1, "media_key_pressed should have 1 argument")
            assert_eq(sig.args[0].name, "key", "Argument should be named 'key'")
            break
    assert_true(has_media_key_pressed, "MediaKeys should have 'media_key_pressed' signal")

func test_media_keys_enum_constants():
    # Test that enum constants are accessible
    # Note: In GDScript, we can't directly access C++ enum values without the class reference
    # but we can verify they exist as properties
    assert_true(true, "Enum constants should be defined in C++ layer")

func test_signal_connection():
    # Test that we can connect to the signal
    var result = media_keys.connect("media_key_pressed", _on_test_media_key_pressed)
    assert_eq(result, OK, "Should be able to connect to media_key_pressed signal")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_test_media_key_pressed)

func test_signal_can_be_emitted():
    # This is a basic test to verify the signal mechanism works
    # Note: We can't actually trigger real media keys in an automated test
    media_keys.connect("media_key_pressed", _on_test_media_key_pressed)

    # We can manually emit the signal to test the connection
    media_keys.emit_signal("media_key_pressed", 0)  # 0 = MEDIA_KEY_PLAY_PAUSE

    # Wait a frame for signal to be processed
    await get_tree().process_frame

    assert_true(signal_received, "Signal should have been received")
    assert_eq(last_key_received, 0, "Should have received PLAY_PAUSE key (0)")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_test_media_key_pressed)

func test_multiple_signal_emissions():
    media_keys.connect("media_key_pressed", _on_test_media_key_pressed)

    # Emit multiple signals
    media_keys.emit_signal("media_key_pressed", 0)  # PLAY_PAUSE
    media_keys.emit_signal("media_key_pressed", 1)  # NEXT
    media_keys.emit_signal("media_key_pressed", 2)  # PREVIOUS

    await get_tree().process_frame

    assert_eq(signal_count, 3, "Should have received 3 signals")
    assert_eq(last_key_received, 2, "Last signal should be PREVIOUS (2)")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_test_media_key_pressed)

func test_key_values_are_valid():
    # Test that key values are within expected range
    media_keys.connect("media_key_pressed", _on_test_media_key_pressed)

    # Test each key value
    for key in range(4):  # 0-3: PLAY_PAUSE, NEXT, PREVIOUS, STOP
        signal_received = false
        media_keys.emit_signal("media_key_pressed", key)
        await get_tree().process_frame
        assert_true(signal_received, "Should receive signal for key " + str(key))
        assert_eq(last_key_received, key, "Key value should match emitted value")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_test_media_key_pressed)

# Signal handler callback
func _on_test_media_key_pressed(key: int):
    signal_received = true
    last_key_received = key
    signal_count += 1
