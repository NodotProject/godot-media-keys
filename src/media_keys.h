#ifndef MEDIA_KEYS_H
#define MEDIA_KEYS_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/binder_common.hpp>

#include <thread>
#include <queue>
#include <mutex>

#ifdef __linux__
#include <dbus/dbus.h>
#elif defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#elif defined(__APPLE__)
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#endif

// Debug logging can be enabled by defining MEDIA_KEYS_DEBUG
// To enable: Add "CPPDEFINES=['MEDIA_KEYS_DEBUG']" to SConstruct
#ifdef MEDIA_KEYS_DEBUG
    #include <godot_cpp/variant/utility_functions.hpp>
    #define MEDIA_KEYS_LOG(msg) godot::UtilityFunctions::print(msg)
#else
    #define MEDIA_KEYS_LOG(msg)
#endif

namespace godot {

class MediaKeys : public Object {
    GDCLASS(MediaKeys, Object)

public:
    enum MediaKey {
        MEDIA_KEY_PLAY_PAUSE,
        MEDIA_KEY_NEXT,
        MEDIA_KEY_PREVIOUS,
        MEDIA_KEY_STOP,
    };

    std::queue<MediaKey> key_event_queue;
    std::mutex queue_mutex;

private:
    static MediaKeys *singleton;

#ifdef __linux__
    DBusConnection *connection;
#elif defined(_WIN32) || defined(_WIN64)
    HWND message_window;
    static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
#elif defined(__APPLE__)
    CFMachPortRef event_tap;
    CFRunLoopSourceRef event_tap_source;
    CFRunLoopRef run_loop;
    void worker_thread_func_macos();
    void cleanup_macos();
#endif

    std::thread worker_thread;
    bool running;

    void worker_thread_func();
    void poll_key_events();

protected:
    static void _bind_methods();

public:
    static MediaKeys *get_singleton();

    MediaKeys();
    ~MediaKeys();

    void poll_events_from_main_thread();
};

} // namespace godot

VARIANT_ENUM_CAST(MediaKeys::MediaKey);

#endif // MEDIA_KEYS_H
