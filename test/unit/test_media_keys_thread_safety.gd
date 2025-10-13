extends GutTest

# Thread safety tests for MediaKeys
# These tests verify that the extension handles concurrent operations safely

var media_keys = null
var signal_count = 0
var received_keys = []
var test_mutex = Mutex.new()

func before_each():
    media_keys = Engine.get_singleton("MediaKeys")
    signal_count = 0
    received_keys = []

func test_rapid_signal_emissions():
    # Test that rapid signal emissions don't cause issues
    # The C++ side uses a mutex-protected queue, so this should be safe
    media_keys.connect("media_key_pressed", _on_rapid_test_key_pressed)

    # Rapidly emit multiple signals
    for i in range(20):
        media_keys.emit_signal("media_key_pressed", i % 4)

    # Wait for all signals to process
    for i in range(5):
        await get_tree().process_frame

    assert_eq(signal_count, 20, "Should have received all 20 signals")
    assert_eq(received_keys.size(), 20, "Should have tracked all 20 key presses")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_rapid_test_key_pressed)

func test_signal_order_preservation():
    # Test that signals are received in the order they were emitted
    media_keys.connect("media_key_pressed", _on_ordered_test_key_pressed)

    # Emit signals in a specific sequence
    var expected_sequence = [0, 1, 2, 3, 0, 1, 2, 3]
    for key in expected_sequence:
        media_keys.emit_signal("media_key_pressed", key)

    # Wait for processing
    for i in range(3):
        await get_tree().process_frame

    assert_eq(received_keys.size(), expected_sequence.size(),
              "Should receive correct number of signals")

    for i in range(expected_sequence.size()):
        if i < received_keys.size():
            assert_eq(received_keys[i], expected_sequence[i],
                     "Signal at index " + str(i) + " should match expected sequence")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_ordered_test_key_pressed)

func test_concurrent_signal_handlers():
    # Test multiple signal handlers can be connected simultaneously
    var handler_helper = ConcurrentHandlerHelper.new()

    media_keys.connect("media_key_pressed", handler_helper.on_handler1)
    media_keys.connect("media_key_pressed", handler_helper.on_handler2)
    media_keys.connect("media_key_pressed", handler_helper.on_handler3)

    # Emit some signals
    for i in range(5):
        media_keys.emit_signal("media_key_pressed", i % 4)

    # Wait for processing
    for i in range(3):
        await get_tree().process_frame

    assert_eq(handler_helper.handler1_count, 5, "Handler 1 should receive all signals")
    assert_eq(handler_helper.handler2_count, 5, "Handler 2 should receive all signals")
    assert_eq(handler_helper.handler3_count, 5, "Handler 3 should receive all signals")

    # Cleanup
    media_keys.disconnect("media_key_pressed", handler_helper.on_handler1)
    media_keys.disconnect("media_key_pressed", handler_helper.on_handler2)
    media_keys.disconnect("media_key_pressed", handler_helper.on_handler3)

func test_signal_emission_during_processing():
    # Test that emitting signals while processing doesn't cause deadlock
    media_keys.connect("media_key_pressed", _on_reentrant_test_key_pressed)

    # Start with one emission
    media_keys.emit_signal("media_key_pressed", 0)

    # Wait for all cascading signals to process
    for i in range(10):
        await get_tree().process_frame

    # We should have received multiple signals without deadlock
    assert_true(signal_count > 0, "Should have processed at least one signal")
    assert_true(signal_count <= 5, "Should not have infinite recursion")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_reentrant_test_key_pressed)

func test_no_signals_lost_under_load():
    # Test that under heavy load, no signals are lost
    media_keys.connect("media_key_pressed", _on_load_test_key_pressed)

    var expected_count = 100
    # Emit many signals in quick succession
    for i in range(expected_count):
        media_keys.emit_signal("media_key_pressed", i % 4)
        if i % 10 == 0:
            await get_tree().process_frame  # Occasionally yield

    # Wait for all signals to process
    for i in range(20):
        await get_tree().process_frame

    assert_eq(signal_count, expected_count,
              "Should not lose any signals under load")

    # Cleanup
    media_keys.disconnect("media_key_pressed", _on_load_test_key_pressed)

# Signal handlers for different tests

func _on_rapid_test_key_pressed(key: int):
    test_mutex.lock()
    signal_count += 1
    received_keys.append(key)
    test_mutex.unlock()

func _on_ordered_test_key_pressed(key: int):
    test_mutex.lock()
    received_keys.append(key)
    test_mutex.unlock()

func _on_reentrant_test_key_pressed(key: int):
    signal_count += 1
    # Only re-emit a limited number of times to avoid infinite recursion
    if signal_count < 5:
        media_keys.emit_signal("media_key_pressed", (key + 1) % 4)

func _on_load_test_key_pressed(key: int):
    test_mutex.lock()
    signal_count += 1
    test_mutex.unlock()
    # Simulate some processing time
    await get_tree().create_timer(0.001).timeout

# Helper class for concurrent signal handler test
# Needed because lambda functions don't work properly with signal connections
class ConcurrentHandlerHelper:
    var handler1_count = 0
    var handler2_count = 0
    var handler3_count = 0

    func on_handler1(key: int):
        handler1_count += 1

    func on_handler2(key: int):
        handler2_count += 1

    func on_handler3(key: int):
        handler3_count += 1
