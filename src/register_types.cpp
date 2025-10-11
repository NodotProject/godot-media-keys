#include "register_types.h"

#include "media_keys.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

static MediaKeys *media_keys_singleton;

void initialize_media_keys_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	ClassDB::register_class<MediaKeys>();

	media_keys_singleton = memnew(MediaKeys);
	Engine::get_singleton()->register_singleton(StringName("MediaKeys"), media_keys_singleton);
}

void uninitialize_media_keys_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	Engine::get_singleton()->unregister_singleton(StringName("MediaKeys"));
	memdelete(media_keys_singleton);
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT media_keys_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_media_keys_module);
	init_obj.register_terminator(uninitialize_media_keys_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
