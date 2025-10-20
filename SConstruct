from SCons.Script import ARGUMENTS, Environment, Mkdir, Default, File, CacheDir
import os
import sys

# Resolve platform/target/arch from args (matches CI defaults)
platform = ARGUMENTS.get('platform')
if not platform:
    p = sys.platform
    if p.startswith('win'):
        platform = 'windows'
    elif p == 'darwin':
        platform = 'macos'
    else:
        platform = 'linux'

target = ARGUMENTS.get('target', 'template_release')
arch = ARGUMENTS.get('arch', 'universal' if platform == 'macos' else 'x86_64')
if arch not in ['x86_64', 'x86_32', 'arm64', 'universal']:
    print(f"ERROR: Invalid architecture '{arch}'. Supported architectures are: x86_64, x86_32, arm64, universal.")
    Exit(1)

# Set up the environment based on the platform
use_mingw_arg = ARGUMENTS.get('use_mingw', 'no')
use_mingw = use_mingw_arg.lower() in ['yes', 'true', '1']

if platform == 'windows' and not use_mingw:
    # Use the MSVC compiler on Windows (native build)
    env = Environment(tools=['default', 'msvc'])
elif platform == 'windows' and use_mingw:
    # Force SCons to use the MinGW toolchain for cross-compilation
    env = Environment(tools=['gcc', 'g++', 'gnulink', 'ar', 'gas'])
    
    # Explicitly override compiler settings after environment creation
    cc_cmd = os.environ.get('CC', 'x86_64-w64-mingw32-gcc')
    cxx_cmd = os.environ.get('CXX', 'x86_64-w64-mingw32-g++')
    
    env.Replace(CC=cc_cmd)
    env.Replace(CXX=cxx_cmd)
    env.Replace(LINK=cxx_cmd)  # Use C++ compiler for linking (g++) so libstdc++ and C++ EH symbols are pulled in

else:
    # Use the default compiler on other platforms
    env = Environment()

# Optional: enable SCons cache if SCONS_CACHE or SCONS_CACHE_DIR is provided (local or CI)
cache_dir = os.environ.get('SCONS_CACHE') or os.environ.get('SCONS_CACHE_DIR')
if cache_dir:
    CacheDir(cache_dir)
    print(f"SCons cache enabled at: {cache_dir}")

# Add include paths for godot-cpp
env.Append(CPPPATH=[
    'src',
    '.',
    'godot-cpp/include',
    'godot-cpp/gen/include',
    'godot-cpp/gdextension',
])

# Platform-specific include paths - only add system paths for native builds
if not use_mingw and platform != 'windows':
    # Only add Linux/macOS system paths for native builds
    env.Append(CPPPATH=[
        '/usr/include',
        '/usr/local/include',
    ])
    if platform == 'linux':
        env.Append(CPPPATH=[
            '/usr/include/dbus-1.0',
            '/usr/lib/x86_64-linux-gnu/dbus-1.0/include',
        ])
elif use_mingw or platform == 'windows':
    # For Windows cross-compilation, add MinGW-specific paths
    env.Append(CPPPATH=[
        '/usr/x86_64-w64-mingw32/include',
    ])
    # Ensure MinGW uses its own sysroot and headers
    env.Append(CCFLAGS=['--sysroot=/usr/x86_64-w64-mingw32'])
    env.Append(LINKFLAGS=['--sysroot=/usr/x86_64-w64-mingw32'])

# Platform-specific library paths
env.Append(LIBPATH=['godot-cpp/bin'])

is_windows = platform == 'windows'
if is_windows and not use_mingw:
    # MSVC flags
    env.Append(CXXFLAGS=['/std:c++17'])
else:
    # Linux/macOS/MinGW flags
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])

if is_windows and use_mingw:
    # Add Windows-specific defines for MinGW
    env.Append(CPPDEFINES=['WIN32', '_WIN32', 'WINDOWS_ENABLED'])
    # Match godot-cpp's MinGW linking configuration for compatibility
    env.Append(CCFLAGS=['-Wwrite-strings'])
    env.Append(LINKFLAGS=['-Wl,--no-undefined'])
    # Use static linking to match godot-cpp's default use_static_cpp=True behavior
    env.Append(LINKFLAGS=['-static', '-static-libgcc', '-static-libstdc++'])

# Enable debug logging for media keys (can be disabled for production)
# Uncomment the line below to enable debug logging:
# env.Append(CPPDEFINES=['MEDIA_KEYS_DEBUG'])

# When using MinGW for cross-compilation, we still get .a files with lib prefix
# .lib files without prefix are only used with MSVC
if is_windows and not use_mingw:
    lib_ext = '.lib'
    lib_prefix = ''
else:
    lib_ext = '.a'
    lib_prefix = 'lib'

# Add godot-cpp library
# For macOS, try arch-specific first, then fall back to universal
if platform == 'macos' and arch != 'universal':
    arch_specific = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"
    universal = f"{lib_prefix}godot-cpp.{platform}.{target}.universal{lib_ext}"

    arch_specific_path = os.path.join('godot-cpp', 'bin', arch_specific)
    universal_path = os.path.join('godot-cpp', 'bin', universal)

    if os.path.exists(arch_specific_path):
        godot_cpp_lib = arch_specific
        print(f"Using arch-specific godot-cpp library: {arch_specific}")
    elif os.path.exists(universal_path):
        godot_cpp_lib = universal
        print(f"Using universal godot-cpp library: {universal}")
    else:
        print(f"ERROR: No suitable godot-cpp library found!")
        print(f"Tried: {arch_specific_path}")
        print(f"Tried: {universal_path}")
        Exit(1)
else:
    godot_cpp_lib = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"

env.Append(LIBS=[File(os.path.join('godot-cpp', 'bin', godot_cpp_lib))])

if is_windows:
    # ws2_32 and bcrypt are needed by godot-cpp
    # user32 is needed for Windows message handling (CreateWindowEx, GetMessage, etc.)
    env.Append(LIBS=['ws2_32', 'bcrypt', 'user32'])
elif platform == 'linux':
    env.Append(LIBS=['pthread', 'dl', 'dbus-1'])
elif platform == 'macos':
    env.Append(LIBS=['pthread'])
    # CoreFoundation and CoreGraphics are needed for CGEventTap
    # AppKit/Foundation are needed for NSEvent handling
    # Carbon is needed for media key codes (NX_KEYTYPE_*)
    # IOKit is needed for ev_keymap.h
    env.Append(FRAMEWORKS=['CoreFoundation', 'CoreGraphics', 'AppKit', 'Carbon', 'IOKit', 'SystemConfiguration', 'Security'])


# Debug logging for CI: print resolved names and compiler locations
print("=== SCons debug: resolved build variables ===")
print("platform:", platform)
print("target:", target)
print("arch:", arch)
print("use_mingw:", ARGUMENTS.get('use_mingw', 'no'))
print("expected godot_cpp_lib:", godot_cpp_lib)
print("godot-cpp bin path:", os.path.join('godot-cpp', 'bin'))
print("ENV CC:", os.environ.get('CC'))
print("ENV CXX:", os.environ.get('CXX'))
print("env['CC']:", env.get('CC'))
print("env['CXX']:", env.get('CXX'))
print("============================================")

src_files = [
    'src/register_types.cpp',
    'src/media_keys.cpp',
]

# Add macOS-specific Objective-C++ file
if platform == 'macos':
    src_files.append('src/media_keys_macos.mm')

env.Execute(Mkdir('addons/godot-media-keys/bin'))

# Set the correct library suffix and prefix based on platform
# Note: We use 'lib' prefix for all platforms to match the .gdextension file
if is_windows:
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.dll'
elif platform == 'macos':
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.dylib'
else:
    env['SHLIBPREFIX'] = 'lib'
    env['SHLIBSUFFIX'] = '.so'

# Debug logging: shared lib name details
print("SHLIBPREFIX:", env.get('SHLIBPREFIX'))
print("SHLIBSUFFIX:", env.get('SHLIBSUFFIX'))
print("Target shared lib will be created as:", env.get('SHLIBPREFIX') + 'media_keys' + env.get('SHLIBSUFFIX'))

# Create the library directly in the addon directory
# For macOS, when building with a specific architecture (not universal), include arch in filename
if platform == 'macos' and arch != 'universal':
    library = env.SharedLibrary(target=f'addons/godot-media-keys/bin/media_keys.{arch}', source=src_files)
else:
    library = env.SharedLibrary(target='addons/godot-media-keys/bin/media_keys', source=src_files)
Default(library)