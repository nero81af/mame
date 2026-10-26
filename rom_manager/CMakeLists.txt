# chdman (MAME's CHD manager) built straight from a MAME source tree, without MAME's
# genie/make build. Built by build.sh. File lists and defines follow
# MAME's scripts/src/{tools,lib,3rdparty}.lua and scripts/src/osd/{sdl,windows}.lua.
#   Android: the "sdl" OSD core (posix files, no SDL), static libc++, 16 KB pages.
#   Windows: the "windows" OSD core (MSVC), for testing on the PC.
cmake_minimum_required(VERSION 3.20)
project(chdman C CXX)

set(MAME_DIR "" CACHE PATH "MAME source tree")
set(MAME_VERSION "0.289" CACHE STRING "MAME version reported by chdman")
set(MAME_REVISION "mame0289" CACHE STRING "VCS revision reported by chdman")

if(NOT EXISTS "${MAME_DIR}/src/tools/chdman.cpp")
	message(FATAL_ERROR "MAME_DIR must point to a MAME source tree")
endif()

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

function(mame_sources out dir)
	list(TRANSFORM ARGN PREPEND "${MAME_DIR}/${dir}/")
	set(${out} ${ARGN} PARENT_SCOPE)
endfunction()

# defines every MAME project gets (genie.lua)
add_compile_definitions(LSB_FIRST FLAC__NO_DLL $<$<NOT:$<CONFIG:Debug>>:NDEBUG>)
if(WIN32)
	add_compile_definitions(CRLF=3 XML_STATIC WIN32 _WIN32 _CRT_NONSTDC_NO_DEPRECATE
		_CRT_SECURE_NO_DEPRECATE _CRT_STDIO_LEGACY_WIDE_SPECIFIERS)
	if(MSVC)
		add_compile_options(/bigobj /utf-8 /Zc:preprocessor /W0)
	endif()
else()
	add_compile_definitions(CRLF=2)
	add_compile_options(-w)
endif()

# 3rdparty --------------------------------------------------------------------

mame_sources(ZLIB_SRC 3rdparty/zlib
	adler32.c compress.c crc32.c deflate.c inffast.c inflate.c infback.c inftrees.c
	trees.c uncompr.c zutil.c)
add_library(mame_zlib STATIC ${ZLIB_SRC})
target_compile_definitions(mame_zlib PRIVATE ZLIB_CONST)

mame_sources(ZSTD_SRC 3rdparty/zstd/lib
	common/debug.c common/entropy_common.c common/error_private.c common/fse_decompress.c
	common/pool.c common/threading.c common/xxhash.c common/zstd_common.c
	compress/fse_compress.c compress/hist.c compress/huf_compress.c compress/zstd_compress.c
	compress/zstd_compress_literals.c compress/zstd_compress_sequences.c
	compress/zstd_compress_superblock.c compress/zstd_double_fast.c compress/zstd_fast.c
	compress/zstd_lazy.c compress/zstd_ldm.c compress/zstdmt_compress.c compress/zstd_opt.c
	decompress/huf_decompress.c decompress/zstd_ddict.c decompress/zstd_decompress_block.c
	decompress/zstd_decompress.c)
add_library(mame_zstd STATIC ${ZSTD_SRC})
target_compile_definitions(mame_zstd PRIVATE XXH_NAMESPACE=ZSTD_ DEBUGLEVEL=0 ZSTD_DISABLE_ASM)

mame_sources(LZMA_SRC 3rdparty/lzma/C
	7zAlloc.c 7zArcIn.c 7zBuf.c 7zBuf2.c 7zCrc.c 7zCrcOpt.c 7zDec.c 7zFile.c 7zStream.c
	Aes.c AesOpt.c Alloc.c Bcj2.c Bra.c Bra86.c BraIA64.c CpuArch.c Delta.c LzFind.c
	LzFindOpt.c Lzma2Dec.c LzmaDec.c LzmaEnc.c Ppmd7.c Ppmd7Dec.c Sha256.c Sha256Opt.c Sort.c)
add_library(mame_7z STATIC ${LZMA_SRC})
target_compile_definitions(mame_7z PRIVATE Z7_PPMD_SUPPORT Z7_ST)

mame_sources(FLAC_SRC 3rdparty/flac/src/libFLAC
	bitmath.c bitreader.c bitwriter.c cpu.c crc.c fixed.c fixed_intrin_avx2.c
	fixed_intrin_sse2.c fixed_intrin_sse42.c fixed_intrin_ssse3.c float.c format.c lpc.c
	lpc_intrin_avx2.c lpc_intrin_fma.c lpc_intrin_neon.c lpc_intrin_sse2.c lpc_intrin_sse41.c
	md5.c memory.c stream_decoder.c stream_encoder.c stream_encoder_framing.c
	stream_encoder_intrin_avx2.c stream_encoder_intrin_sse2.c stream_encoder_intrin_ssse3.c
	window.c)
if(WIN32)
	list(APPEND FLAC_SRC "${MAME_DIR}/3rdparty/flac/src/share/win_utf8_io/win_utf8_io.c")
endif()
add_library(mame_flac STATIC ${FLAC_SRC})
target_include_directories(mame_flac PRIVATE
	"${MAME_DIR}/3rdparty/flac/src/libFLAC/include" "${MAME_DIR}/3rdparty/flac/include")
target_compile_definitions(mame_flac PRIVATE
	HAVE_CONFIG_H ENABLE_64_BIT_WORDS=1 OGG_FOUND=0 FLAC__HAS_OGG=0 HAVE_LROUND=1
	HAVE_INTTYPES_H HAVE_STDBOOL_H HAVE_STDINT_H HAVE_STDIO_H HAVE_STDLIB_H HAVE_STRING_H
	_FILE_OFFSET_BITS=64 _LARGEFILE_SOURCE
	CPU_IS_BIG_ENDIAN=0 CPU_IS_LITTLE_ENDIAN=1 WORDS_BIGENDIAN=0
	$<$<NOT:$<C_COMPILER_ID:MSVC>>:HAVE_BSWAP16> $<$<NOT:$<C_COMPILER_ID:MSVC>>:HAVE_BSWAP32>
	$<$<BOOL:${ANDROID}>:FLAC__SYS_LINUX>)

mame_sources(EXPAT_SRC 3rdparty/expat/lib xmlparse.c xmlrole.c xmltok.c)
add_library(mame_expat STATIC ${EXPAT_SRC})
target_compile_definitions(mame_expat PRIVATE
	HAVE_CXX11 HAVE_MEMMOVE HAVE_STDINT_H HAVE_STDIO_H HAVE_STDLIB_H HAVE_STRING_H
	PACKAGE="expat" PACKAGE_VERSION="2.7.1" STDC_HEADERS VERSION="2.7.1"
	XML_CONTEXT_BYTES=1024 XML_DTD XML_GE=1 XML_NS BYTEORDER=1234)
if(NOT WIN32)
	target_compile_definitions(mame_expat PRIVATE
		HAVE_DLFCN_H HAVE_FCNTL_H HAVE_MMAP HAVE_SYS_STAT_H HAVE_SYS_TYPES_H HAVE_UNISTD_H
		XML_DEV_URANDOM)
endif()

add_library(mame_utf8proc STATIC "${MAME_DIR}/3rdparty/utf8proc/utf8proc.c")
target_compile_definitions(mame_utf8proc PUBLIC UTF8PROC_STATIC)

# OSD core (ocore_sdl on Android, ocore_windows on Windows), without the emulator-only
# modules/osdmodule.cpp ----------------------------------------------------------

set(OCORE_SRC
	"${MAME_DIR}/src/osd/osdcore.cpp"
	"${MAME_DIR}/src/osd/strconv.cpp"
	"${MAME_DIR}/src/osd/osdsync.cpp")
if(WIN32)
	mame_sources(OCORE_OS_SRC src/osd
		windows/winutf8.cpp windows/winutil.cpp modules/file/windir.cpp
		modules/file/winfile.cpp modules/file/winptty.cpp modules/file/winsocket.cpp
		modules/lib/osdlib_win32.cpp)
else()
	mame_sources(OCORE_OS_SRC src/osd
		modules/file/posixdir.cpp modules/file/posixfile.cpp modules/file/posixptty.cpp
		modules/file/posixsocket.cpp modules/lib/osdlib_unix.cpp)
endif()
add_library(mame_ocore STATIC ${OCORE_SRC} ${OCORE_OS_SRC})
target_include_directories(mame_ocore PRIVATE
	"${MAME_DIR}/3rdparty" "${MAME_DIR}/src/osd" "${MAME_DIR}/src/osd/modules/file"
	"${MAME_DIR}/src/lib" "${MAME_DIR}/src/lib/util")
if(WIN32)
	target_include_directories(mame_ocore PRIVATE "${MAME_DIR}/src/osd/windows")
	target_compile_definitions(mame_ocore PRIVATE
		OSD_WINDOWS UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX WINVER=0x0A00 _WIN32_WINNT=0x0A00)
	target_link_libraries(mame_ocore PUBLIC
		user32 winmm advapi32 shlwapi wsock32 ws2_32 psapi iphlpapi shell32 userenv)
else()
	# sdl_cfg.lua without SDL itself; OSD_ANDROID_STDIO comes from the rom_manager Android patch commit
	target_include_directories(mame_ocore PRIVATE "${MAME_DIR}/src/osd/sdl")
	target_compile_definitions(mame_ocore PRIVATE
		OSD_SDL SDLMAME_UNIX SDLMAME_SDL2=1 SDLMAME_NO_X11 USE_XINPUT=0 OSD_ANDROID_STDIO)
	target_compile_options(mame_ocore PRIVATE
		-include "${MAME_DIR}/src/osd/sdl/sdlprefix.h")
	target_link_libraries(mame_ocore PUBLIC dl m)
endif()

# utils (lib.lua, minus aes256cbc.cpp and nanosvg.cpp which only the emulator needs) ---

mame_sources(UTILS_SRC src/lib/util
	avhuff.cpp aviio.cpp bitmap.cpp cdrom.cpp chd.cpp chdcodec.cpp corealloc.cpp
	corefile.cpp corestr.cpp coreutil.cpp delegate.cpp disasmintf.cpp dvdrom.cpp
	dynamicclass.cpp flac.cpp harddisk.cpp hash.cpp hashing.cpp huffman.cpp ioprocs.cpp
	ioprocsfilter.cpp jedparse.cpp language.cpp md5.cpp mfpresolve.cpp msdib.cpp
	opresolv.cpp options.cpp palette.cpp path.cpp path_to_regex.cpp plaparse.cpp png.cpp
	simh_tape_file.cpp strformat.cpp timeconv.cpp unicode.cpp unzip.cpp un7z.cpp
	vbiparse.cpp vecstream.cpp wavwrite.cpp xmlfile.cpp zippath.cpp)
add_library(mame_utils STATIC ${UTILS_SRC})
target_include_directories(mame_utils PUBLIC
	"${MAME_DIR}/src/osd" "${MAME_DIR}/src/lib/util" "${MAME_DIR}/3rdparty"
	"${MAME_DIR}/3rdparty/expat/lib" "${MAME_DIR}/3rdparty/zlib" "${MAME_DIR}/3rdparty/zstd/lib"
	"${MAME_DIR}/3rdparty/flac/include" "${MAME_DIR}/3rdparty/utf8proc")
target_link_libraries(mame_utils PUBLIC
	mame_expat mame_7z mame_ocore mame_zlib mame_zstd mame_flac mame_utf8proc)

# chdman ----------------------------------------------------------------------

set(VERSION_CPP "${CMAKE_CURRENT_BINARY_DIR}/version.cpp")
file(CONFIGURE OUTPUT "${VERSION_CPP}" CONTENT [[
#define BARE_BUILD_VERSION "@MAME_VERSION@"
#define BARE_VCS_REVISION "@MAME_REVISION@"
extern const char bare_build_version[];
extern const char bare_vcs_revision[];
extern const char build_version[];
const char bare_build_version[] = BARE_BUILD_VERSION;
const char bare_vcs_revision[] = BARE_VCS_REVISION;
const char build_version[] = BARE_BUILD_VERSION " (" BARE_VCS_REVISION ")";
]] @ONLY)

add_executable(chdman "${MAME_DIR}/src/tools/chdman.cpp" "${VERSION_CPP}")
target_link_libraries(chdman PRIVATE mame_utils)
if(ANDROID)
	target_link_options(chdman PRIVATE
		-Wl,-z,max-page-size=16384 -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--gc-sections)
endif()
