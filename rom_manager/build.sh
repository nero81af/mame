#!/usr/bin/env bash
# Builds MAME's chdman (MAME 0.289, BSD-3-Clause/GPLv2+) as a stripped Android PIE executable
# (static libc++, 16 KB page aligned) for arm64-v8a and x86_64 and installs it as
# src/RomManager/Android/app/src/main/jniLibs/<abi>/libchdman.so. MAME's own genie/make build is not used:
# rom_manager/CMakeLists.txt compiles chdman and the libraries it needs from this checkout (branch rom_manager
# of nero81af/mame: mame0289 with the Android patch, trimmed to the sources chdman needs).
#   ./build.sh          Android builds
#   ./build.sh --host   host build only (build/host), for testing on the PC
#   ./build.sh --windows  win-x64 build with MSVC (static CRT) into src/RomManager/Tools/win-x64/chdman.exe
# Needs: the Android NDK and SDK CMake (NDK=..., SDK_CMAKE=... to override).
set -euo pipefail

API=30
ABIS="arm64-v8a x86_64"

HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK_ROOT:-$HOME/AppData/Local/Android/Sdk}"
NDK="${NDK:-$SDK/ndk/29.0.14206865}"
SDK_CMAKE="${SDK_CMAKE:-$SDK/cmake/3.31.6/bin}"
SRC="$(dirname "$HERE")"
JNILIBS="$HERE/../../../src/RomManager/Android/app/src/main/jniLibs"

case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) HOST=windows-x86_64; EXE=.exe ;;
	Darwin)               HOST=darwin-x86_64;  EXE= ;;
	*)                    HOST=linux-x86_64;   EXE= ;;
esac
BIN="$NDK/toolchains/llvm/prebuilt/$HOST/bin"

if [ "${1:-}" = "--host" ]; then
	OUT="$HERE/build/host"
	cmake -S "$HERE" -B "$OUT" -DMAME_DIR="$SRC"
	cmake --build "$OUT" --config Release --parallel
	exit 0
fi

if [ "${1:-}" = "--windows" ]; then
	WIN_CMAKE=${WIN_CMAKE:-"C:/Program Files/CMake/bin/cmake.exe"}
	OUT="$HERE/build/windows"
	DEST="$HERE/../../../src/RomManager/Tools/win-x64/chdman.exe"
	"$WIN_CMAKE" -S "$HERE" -B "$OUT" -A x64 -DMAME_DIR="$SRC"
	"$WIN_CMAKE" --build "$OUT" --config Release --parallel
	mkdir -p "$(dirname "$DEST")"
	cp "$OUT/Release/chdman.exe" "$DEST"
	echo "windows: $DEST ($(wc -c < "$DEST") bytes)"
	exit 0
fi

[ -x "$BIN/clang$EXE" ] || { echo "NDK not found in $NDK (set NDK=...)" >&2; exit 1; }

for ABI in $ABIS; do
	OUT="$HERE/build/$ABI"
	rm -rf "$OUT"
	# 1. configure + build with the NDK toolchain (static libc++, 16 KB max page size)
	"$SDK_CMAKE/cmake$EXE" -S "$HERE" -B "$OUT" -G Ninja \
		-DCMAKE_MAKE_PROGRAM="$SDK_CMAKE/ninja$EXE" \
		-DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
		-DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" -DANDROID_STL=c++_static \
		-DCMAKE_BUILD_TYPE=Release \
		-DMAME_DIR="$SRC"
	"$SDK_CMAKE/cmake$EXE" --build "$OUT"

	# 2. strip, check (no libc++_shared, every LOAD segment 16 KB aligned) and install
	"$BIN/llvm-strip$EXE" --strip-all -o "$OUT/chdman.stripped" "$OUT/chdman"
	needed=$("$BIN/llvm-readelf$EXE" -d "$OUT/chdman.stripped" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | tr '\n' ' ')
	align=$("$BIN/llvm-readelf$EXE" -lW "$OUT/chdman.stripped" | awk '$1 == "LOAD" { print $NF }' | sort -u | xargs)
	if echo "$needed" | grep -q 'c++_shared'; then
		echo "error: $ABI build depends on libc++_shared.so" >&2
		exit 1
	fi
	if [ "$align" != "0x4000" ]; then
		echo "error: $ABI build has LOAD alignment $align (expected 0x4000)" >&2
		exit 1
	fi
	mkdir -p "$JNILIBS/$ABI"
	cp "$OUT/chdman.stripped" "$JNILIBS/$ABI/libchdman.so"
	echo "$ABI: $(wc -c < "$JNILIBS/$ABI/libchdman.so") bytes, LOAD align $align, NEEDED: $needed"
done
