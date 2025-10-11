#include "media_keys.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef __linux__
#include <unistd.h>  // for getpid()
#endif

using namespace godot;

MediaKeys *MediaKeys::singleton = nullptr;

MediaKeys *MediaKeys::get_singleton() {
    return singleton;
}

MediaKeys::MediaKeys() {
    singleton = this;

#ifdef __linux__
    connection = nullptr;
#elif defined(_WIN32) || defined(_WIN64)
    message_window = nullptr;
#endif

    // Only start the worker thread if we're running in the actual game, not in the editor
    if (Engine::get_singleton()->is_editor_hint()) {
        running = false;
        return;
    }

    running = true;
    // Start worker thread - it will handle platform-specific operations asynchronously
    worker_thread = std::thread(&MediaKeys::worker_thread_func, this);
}

MediaKeys::~MediaKeys() {
    running = false;

#ifdef __linux__
    if (connection) {
        dbus_connection_close(connection);
    }
#elif defined(_WIN32) || defined(_WIN64)
    if (message_window) {
        PostMessage(message_window, WM_QUIT, 0, 0);
    }
#endif

    if (worker_thread.joinable()) {
        worker_thread.join();
    }
    singleton = nullptr;
}

void MediaKeys::_bind_methods() {
    ADD_SIGNAL(MethodInfo("media_key_pressed", PropertyInfo(Variant::INT, "key", PROPERTY_HINT_ENUM, "Play/Pause,Next,Previous,Stop")));

    ClassDB::bind_method(D_METHOD("poll_events_from_main_thread"), &MediaKeys::poll_events_from_main_thread);

    BIND_ENUM_CONSTANT(MEDIA_KEY_PLAY_PAUSE);
    BIND_ENUM_CONSTANT(MEDIA_KEY_NEXT);
    BIND_ENUM_CONSTANT(MEDIA_KEY_PREVIOUS);
    BIND_ENUM_CONSTANT(MEDIA_KEY_STOP);
}

void MediaKeys::poll_events_from_main_thread() {
    poll_key_events();
}

void MediaKeys::poll_key_events() {
    std::lock_guard<std::mutex> lock(queue_mutex);
    while (!key_event_queue.empty()) {
        MediaKey key = key_event_queue.front();
        key_event_queue.pop();
        emit_signal("media_key_pressed", key);
    }
}

#ifdef __linux__
// Combined MPRIS2 method call and Settings Daemon signal handler
static DBusHandlerResult mpris_message_handler(DBusConnection *connection, DBusMessage *message, void *user_data) {
    MediaKeys *self = static_cast<MediaKeys *>(user_data);
    const char *interface_name = dbus_message_get_interface(message);
    const char *member_name = dbus_message_get_member(message);

    if (!interface_name || !member_name) {
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
    }

    // Handle Settings Daemon MediaPlayerKeyPressed signals
    if (dbus_message_is_signal(message, "org.gnome.SettingsDaemon.MediaKeys", "MediaPlayerKeyPressed")) {
        MEDIA_KEYS_LOG("MediaKeys: Received MediaPlayerKeyPressed signal");

        DBusMessageIter args;
        if (dbus_message_iter_init(message, &args)) {
            // Skip first argument (app name)
            if (dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_STRING) {
                dbus_message_iter_next(&args);
            }

            // Get second argument (key name)
            if (dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_STRING) {
                const char *key_name;
                dbus_message_iter_get_basic(&args, &key_name);

                MEDIA_KEYS_LOG(String("MediaKeys: Signal key: ") + key_name);

                std::lock_guard<std::mutex> lock(self->queue_mutex);
                if (strcmp(key_name, "Next") == 0) {
                    self->key_event_queue.push(MediaKeys::MEDIA_KEY_NEXT);
                    MEDIA_KEYS_LOG("MediaKeys: Queued NEXT (from signal)");
                } else if (strcmp(key_name, "Play") == 0 || strcmp(key_name, "Pause") == 0 || strcmp(key_name, "PlayPause") == 0) {
                    self->key_event_queue.push(MediaKeys::MEDIA_KEY_PLAY_PAUSE);
                    MEDIA_KEYS_LOG("MediaKeys: Queued PLAY_PAUSE (from signal)");
                } else if (strcmp(key_name, "Previous") == 0) {
                    self->key_event_queue.push(MediaKeys::MEDIA_KEY_PREVIOUS);
                    MEDIA_KEYS_LOG("MediaKeys: Queued PREVIOUS (from signal)");
                } else if (strcmp(key_name, "Stop") == 0) {
                    self->key_event_queue.push(MediaKeys::MEDIA_KEY_STOP);
                    MEDIA_KEYS_LOG("MediaKeys: Queued STOP (from signal)");
                }
            }
        }
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    // Handle MPRIS2 Player interface method calls
    if (strcmp(interface_name, "org.mpris.MediaPlayer2.Player") == 0) {
        MEDIA_KEYS_LOG(String("MediaKeys: Received MPRIS method call: ") + member_name);

        std::lock_guard<std::mutex> lock(self->queue_mutex);

        if (strcmp(member_name, "PlayPause") == 0 || strcmp(member_name, "Play") == 0 || strcmp(member_name, "Pause") == 0) {
            self->key_event_queue.push(MediaKeys::MEDIA_KEY_PLAY_PAUSE);
            MEDIA_KEYS_LOG("MediaKeys: Queued PLAY_PAUSE (from MPRIS)");
        } else if (strcmp(member_name, "Next") == 0) {
            self->key_event_queue.push(MediaKeys::MEDIA_KEY_NEXT);
            MEDIA_KEYS_LOG("MediaKeys: Queued NEXT (from MPRIS)");
        } else if (strcmp(member_name, "Previous") == 0) {
            self->key_event_queue.push(MediaKeys::MEDIA_KEY_PREVIOUS);
            MEDIA_KEYS_LOG("MediaKeys: Queued PREVIOUS (from MPRIS)");
        } else if (strcmp(member_name, "Stop") == 0) {
            self->key_event_queue.push(MediaKeys::MEDIA_KEY_STOP);
            MEDIA_KEYS_LOG("MediaKeys: Queued STOP (from MPRIS)");
        } else {
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        }

        // Send empty reply
        DBusMessage *reply = dbus_message_new_method_return(message);
        if (reply) {
            dbus_connection_send(connection, reply, NULL);
            dbus_message_unref(reply);
        }

        return DBUS_HANDLER_RESULT_HANDLED;
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}


void MediaKeys::worker_thread_func() {
    DBusError err;
    dbus_error_init(&err);

    // Try to connect to D-Bus
    connection = dbus_bus_get(DBUS_BUS_SESSION, &err);
    if (dbus_error_is_set(&err)) {
        MEDIA_KEYS_LOG(String("MediaKeys: D-Bus connection error: ") + err.message);
        dbus_error_free(&err);
        return;
    }

    if (!connection) {
        MEDIA_KEYS_LOG("MediaKeys: Failed to get D-Bus connection");
        return;
    }

    // Register as an MPRIS2 media player
    String bus_name = String("org.mpris.MediaPlayer2.godot");
    CharString bus_name_cstr = bus_name.utf8();

    MEDIA_KEYS_LOG(String("MediaKeys: Registering as MPRIS2 player: ") + bus_name);

    // Request the MPRIS bus name
    int ret = dbus_bus_request_name(connection, bus_name_cstr.get_data(),
                                     DBUS_NAME_FLAG_REPLACE_EXISTING | DBUS_NAME_FLAG_DO_NOT_QUEUE, &err);
    if (dbus_error_is_set(&err)) {
        MEDIA_KEYS_LOG(String("MediaKeys: D-Bus name request error: ") + err.message);
        dbus_error_free(&err);
        return;
    }

    if (ret != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
        MEDIA_KEYS_LOG(String("MediaKeys: Failed to acquire D-Bus name (return code: ") + String::num_int64(ret) + ")");
        return;
    }

    MEDIA_KEYS_LOG("MediaKeys: Successfully acquired MPRIS2 bus name");

    // Register object path handler for /org/mpris/MediaPlayer2
    DBusObjectPathVTable vtable = {};
    vtable.message_function = mpris_message_handler;

    if (!dbus_connection_register_object_path(connection, "/org/mpris/MediaPlayer2", &vtable, this)) {
        MEDIA_KEYS_LOG("MediaKeys: Failed to register object path");
        return;
    }

    MEDIA_KEYS_LOG("MediaKeys: MPRIS2 interface registered");

    // Add signal filter to receive MediaPlayerKeyPressed signals
    // These are targeted signals, not broadcasts, so we need a filter function
    dbus_connection_add_filter(connection, mpris_message_handler, this, NULL);
    MEDIA_KEYS_LOG("MediaKeys: Signal filter added");

    // Add match rule to receive MediaPlayerKeyPressed signals (for keys like Next that still use signals)
    String match_rule = "type='signal',interface='org.gnome.SettingsDaemon.MediaKeys',member='MediaPlayerKeyPressed'";
    CharString match_cstr = match_rule.utf8();
    dbus_bus_add_match(connection, match_cstr.get_data(), &err);
    if (dbus_error_is_set(&err)) {
        MEDIA_KEYS_LOG(String("MediaKeys: Failed to add signal match rule: ") + err.message);
        dbus_error_free(&err);
    } else {
        MEDIA_KEYS_LOG("MediaKeys: Signal match rule added");
    }

    // ALSO register with Settings Daemon to get priority for media keys
    DBusMessage *grab_msg = dbus_message_new_method_call(
        "org.gnome.SettingsDaemon",
        "/org/gnome/SettingsDaemon/MediaKeys",
        "org.gnome.SettingsDaemon.MediaKeys",
        "GrabMediaPlayerKeys"
    );

    if (grab_msg) {
        const char *app_name_ptr = "org.mpris.MediaPlayer2.godot";
        dbus_uint32_t time = 0;
        dbus_message_append_args(grab_msg,
                                 DBUS_TYPE_STRING, &app_name_ptr,
                                 DBUS_TYPE_UINT32, &time,
                                 DBUS_TYPE_INVALID);

        DBusMessage *grab_reply = dbus_connection_send_with_reply_and_block(connection, grab_msg, 500, &err);
        dbus_message_unref(grab_msg);

        if (dbus_error_is_set(&err)) {
            MEDIA_KEYS_LOG(String("MediaKeys: GrabMediaPlayerKeys call failed: ") + err.message);
            dbus_error_free(&err);
        } else {
            MEDIA_KEYS_LOG("MediaKeys: Successfully called GrabMediaPlayerKeys for priority");
        }

        if (grab_reply) {
            dbus_message_unref(grab_reply);
        }
    }

    MEDIA_KEYS_LOG("MediaKeys: Listening for media key events...");

    // Main event loop
    while (running) {
        dbus_connection_read_write_dispatch(connection, 100);
    }

    // Cleanup: MPRIS name will be automatically released when connection is closed
    MEDIA_KEYS_LOG("MediaKeys: Worker thread exiting");
}
