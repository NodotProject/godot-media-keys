#ifdef __APPLE__

#include "media_keys.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <IOKit/hidsystem/ev_keymap.h>
#import <Carbon/Carbon.h>

using namespace godot;

// System defined event for media keys
#define kSystemDefinedEventMediaKeys 8

// Global callback function for the event tap
static CGEventRef mediaKeyEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

// Event tap callback implementation
static CGEventRef mediaKeyEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MediaKeys *self = static_cast<MediaKeys *>(refcon);

    // Handle event tap timeout
    if (type == kCGEventTapDisabledByTimeout) {
        // Re-enable the event tap
        if (self && self->event_tap) {
            CGEventTapEnable(self->event_tap, true);
        }
        return event;
    }

    // Only process system-defined events
    if (type != NX_SYSDEFINED) {
        return event;
    }

    // Convert to NSEvent for easier handling
    NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];

    // Check if it's a media key event
    if ([nsEvent subtype] != kSystemDefinedEventMediaKeys) {
        return event;
    }

    // Extract key code and flags
    int keyCode = (([nsEvent data1] & 0xFFFF0000) >> 16);
    int keyFlags = ([nsEvent data1] & 0x0000FFFF);
    int keyPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA;

    // Only process key down events
    if (!keyPressed) {
        return event;
    }

    // Map macOS key codes to our enum
    MediaKeys::MediaKey mediaKey;
    bool validKey = false;

    switch (keyCode) {
        case NX_KEYTYPE_PLAY:
            mediaKey = MediaKeys::MEDIA_KEY_PLAY_PAUSE;
            validKey = true;
            MEDIA_KEYS_LOG("MediaKeys: macOS PLAY key pressed");
            break;
        case NX_KEYTYPE_FAST:
            mediaKey = MediaKeys::MEDIA_KEY_NEXT;
            validKey = true;
            MEDIA_KEYS_LOG("MediaKeys: macOS NEXT key pressed");
            break;
        case NX_KEYTYPE_REWIND:
            mediaKey = MediaKeys::MEDIA_KEY_PREVIOUS;
            validKey = true;
            MEDIA_KEYS_LOG("MediaKeys: macOS PREVIOUS key pressed");
            break;
        // Note: There's no standard NX_KEYTYPE_STOP, but we'll handle NEXT for completeness
        default:
            break;
    }

    if (validKey && self) {
        std::lock_guard<std::mutex> lock(self->queue_mutex);
        self->key_event_queue.push(mediaKey);
        MEDIA_KEYS_LOG("MediaKeys: Queued media key event");
    }

    // Consume the event so other apps don't receive it
    return validKey ? NULL : event;
}

// macOS-specific worker thread implementation
void MediaKeys::worker_thread_func_macos() {
    @autoreleasepool {
        MEDIA_KEYS_LOG("MediaKeys: Starting macOS worker thread");

        // Create event tap to intercept media key events
        event_tap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionDefault,
            CGEventMaskBit(NX_SYSDEFINED),
            mediaKeyEventCallback,
            this
        );

        if (!event_tap) {
            MEDIA_KEYS_LOG("MediaKeys: Failed to create event tap (requires accessibility permissions)");
            return;
        }

        MEDIA_KEYS_LOG("MediaKeys: Event tap created successfully");

        // Create run loop source
        event_tap_source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, event_tap, 0);
        if (!event_tap_source) {
            MEDIA_KEYS_LOG("MediaKeys: Failed to create run loop source");
            CFRelease(event_tap);
            event_tap = nullptr;
            return;
        }

        // Get the run loop for this thread
        run_loop = CFRunLoopGetCurrent();

        // Add source to run loop
        CFRunLoopAddSource(run_loop, event_tap_source, kCFRunLoopCommonModes);

        MEDIA_KEYS_LOG("MediaKeys: Listening for media key events...");

        // Run the loop (this blocks until CFRunLoopStop is called)
        CFRunLoopRun();

        // Cleanup
        MEDIA_KEYS_LOG("MediaKeys: macOS worker thread exiting");
    }
}

// macOS-specific cleanup
void MediaKeys::cleanup_macos() {
    if (run_loop) {
        CFRunLoopStop(run_loop);
        run_loop = nullptr;
    }

    if (event_tap_source) {
        CFRelease(event_tap_source);
        event_tap_source = nullptr;
    }

    if (event_tap) {
        CGEventTapEnable(event_tap, false);
        CFRelease(event_tap);
        event_tap = nullptr;
    }
}

#endif // __APPLE__
