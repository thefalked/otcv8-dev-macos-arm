# Build OTCv8 on macOS Apple Silicon (arm64)

This tree adds a native Cocoa / NSOpenGL backend. You do **not** need XQuartz.

Verified on Apple Silicon with:

- Homebrew packages for PhysFS (and optional LuaJIT headers)
- vcpkg triplet `arm64-osx`
- PUC Lua 5.1 from `deps/lua-5.1.5` (`-DLUAJIT=OFF`)

LuaJIT on arm64 was unstable for this codebase. Keep `LUAJIT=OFF` unless you are debugging that path.

## 1. Homebrew

```bash
brew install cmake ninja physfs pkg-config
```

Optional (only if you experiment with LuaJIT):

```bash
brew install luajit-openresty
```

## 2. vcpkg (do not fork this registry)

Clone Microsoft vcpkg and pin a known-good commit. This project was built against:

```text
a42757564758c60651ebc616d9b000b7b91249ef
```

```bash
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
git checkout a42757564758c60651ebc616d9b000b7b91249ef
./bootstrap-vcpkg.sh
```

Install the arm64 packages used by the client:

```bash
./vcpkg install --triplet=arm64-osx \
  boost-iostreams boost-asio boost-beast boost-system boost-variant \
  boost-lockfree boost-process boost-filesystem boost-uuid \
  glew openssl libzip zlib bzip2
```

PhysFS comes from Homebrew in the verified build. OpenAL / ogg / vorbis are optional depending on your audio build flags.

Keep the vcpkg tree as a local cache. Do not publish `downloads/`, `buildtrees/`, `packages/`, or `installed/` in a fork.

## 3. Build PUC Lua 5.1 (vendored)

```bash
cd deps/lua-5.1.5/src
make macosx
cd ../../..
```

## 4. Configure and compile

```bash
mkdir -p build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_TARGET_TRIPLET=arm64-osx \
  -DLUAJIT=OFF \
  -DLUA_INCLUDE_DIR="$PWD/../deps/lua-5.1.5/src" \
  -DLUA_LIBRARY="$PWD/../deps/lua-5.1.5/src/liblua.a" \
  -DPHYSFS_INCLUDE_DIR="$(brew --prefix)/include" \
  -DPHYSFS_LIBRARY="$(brew --prefix)/lib/libphysfs.a" \
  -DCMAKE_CXX_FLAGS="-Wno-c++11-narrowing"
cmake --build . -j"$(sysctl -n hw.ncpu)"
```

Output binary: `build/otclient` (Mach-O arm64).

## 5. Run

Copy or symlink the binary into an [otclientv8](https://github.com/thefalked/otclientv8-macos-arm) data tree as `otclient_mac`, or run from the source modules/data layout you use locally.

On modern macOS, ad-hoc codesign helps when Homebrew dylibs are involved:

```bash
codesign -s - --force ./otclient
xattr -cr ./otclient
./otclient
```

Provide your own Tibia `.dat` / `.spr` under `data/things/<version>/`. Those assets are not shipped here.

## What changed vs upstream OTCv8

- Cocoa window backend: `src/framework/platform/macwindow.mm`
- CMake links AppKit + OpenGL.framework on Apple (no X11 / XQuartz)
- Boost 1.87+ / Asio call-site updates
- PUC Lua 5.1 path with `bit` / `bit32` aliases for bot scripts
- GLEW tolerates missing GLX on Cocoa

Upstream OTCv8 mac CI still targets Intel (`x64-osx`) + XQuartz. This repo is the Apple Silicon track.
