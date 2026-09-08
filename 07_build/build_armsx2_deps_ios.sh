#!/usr/bin/env bash
#
# build_armsx2_deps_ios.sh — PCSX2(ARMSX2) 가 요구하는 데스크톱 의존성을 iOS(arm64) 정적으로 빌드.
# PCSX2 SearchForStuff.cmake 의 find_package 체인(iOS SDK 미제공분):
#   PNG / JPEG / Zstd / LZ4 / WebP / SDL3 / Freetype / plutovg / plutosvg
# 공통 prefix($DEPS)에 설치 → PCSX2 cmake 에 -DCMAKE_PREFIX_PATH=$DEPS 로 전달.
# 상태: iOS 크로스빌드는 각 라이브러리마다 quirk 가능 → CI 로그로 반복 수정.
#
set -uo pipefail   # -e 는 dep 하나 실패해도 로그 남기려 개별 처리
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEPS="$HERE/prebuilt/armsx2/deps/prefix"
SRCD="$ROOT/_cache/armsx2_deps_src"
LOG="$ROOT/08_logs"; mkdir -p "$DEPS" "$SRCD" "$LOG"
export CMAKE_PREFIX_PATH="$DEPS"

cmib() {  # cmib <name> <srcSubdir-or-.> <extra cmake args...>
  local name="$1" sub="$2"; shift 2
  local src="$SRCD/$name"; [ "$sub" != "." ] && src="$SRCD/$name/$sub"
  echo "[deps] build $name"
  cmake -S "$src" -B "$SRCD/$name/_bios" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS" \
    -DCMAKE_PREFIX_PATH="$DEPS" -DBUILD_SHARED_LIBS=OFF "$@" 2>&1 | tee -a "$LOG/armsx2_deps.log"
  cmake --build "$SRCD/$name/_bios" --target install -j 2>&1 | tee -a "$LOG/armsx2_deps.log"
}
clone() { [ -d "$SRCD/$1" ] || git clone --depth=1 --branch "$3" "$2" "$SRCD/$1"; }

# 1) libpng
clone libpng https://github.com/pnggroup/libpng.git v1.6.44
cmib libpng . -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_FRAMEWORK=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF

# 2) libjpeg-turbo (JPEG)
clone jpeg https://github.com/libjpeg-turbo/libjpeg-turbo.git 3.0.4
cmib jpeg . -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF

# 3) zstd
clone zstd https://github.com/facebook/zstd.git v1.5.6
cmib zstd build/cmake -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF

# 4) lz4
clone lz4 https://github.com/lz4/lz4.git v1.10.0
cmib lz4 build/cmake -DLZ4_BUILD_CLI=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF

# 5) libwebp
clone webp https://github.com/webmproject/libwebp.git v1.4.0
cmib webp . -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF \
  -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_EXTRAS=OFF

# 6) SDL3
clone sdl3 https://github.com/libsdl-org/SDL.git release-3.2.6
cmib sdl3 . -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST_LIBRARY=OFF

# 7) freetype (COLRv0 필요 → harfbuzz/brotli 제외, PNG 허용)
clone freetype https://github.com/freetype/freetype.git VER-2-13-3
cmib freetype . -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON

# 8) plutovg
clone plutovg https://github.com/sammycage/plutovg.git v1.1.0
cmib plutovg . -DPLUTOVG_BUILD_EXAMPLES=OFF

# 9) plutosvg (plutovg + freetype 사용)
clone plutosvg https://github.com/sammycage/plutosvg.git v0.0.7
cmib plutosvg . -DPLUTOSVG_BUILD_EXAMPLES=OFF -DPLUTOSVG_ENABLE_FREETYPE=ON

echo "[deps] 완료. 설치 prefix: $DEPS"
ls -R "$DEPS/lib" 2>/dev/null | head -40 || true
