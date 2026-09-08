#!/usr/bin/env bash
#
# build_armsx2_ios.sh — ARMSX2(PCSX2 fork) 코어를 iOS(arm64) 정적 라이브러리로 빌드 (Mac 전용)
# 결과: libPCSX2.a, libcommon.a (+ GS-*/3rdparty .a) 를 07_build/prebuilt/armsx2/ 로 수집.
# 상태: Windows 미실행(NOT_TESTED). PCSX2 의 iOS CMake 지원은 실기 환경에서 검증 필요.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/01_sources/ARMSX2"
OUT="$HERE/prebuilt/armsx2"
LOG="$ROOT/08_logs"; mkdir -p "$OUT" "$LOG"

COMMIT="de57f431c41218a17b0eecae2aabaf5d3b01c16f"   # BUILD_NOTES 기준(교체 시 갱신)

if [ ! -d "$SRC/.git" ]; then
  echo "[ARMSX2] 소스 클론"
  git clone https://github.com/ARMSX2/ARMSX2.git "$SRC"
fi
echo "[ARMSX2] commit 고정 + 서브모듈"
git -C "$SRC" fetch --all --tags
git -C "$SRC" checkout "$COMMIT"
git -C "$SRC" submodule update --init --recursive

echo "[ARMSX2] 프론트엔드 임베드 patch 적용(멱등, 실패 시 수동 안내)"
# pcsx2-sdl/Main.cpp 의 int main() 과 렌더 윈도우 Host:: 그룹을 #ifndef ARMSX2_EMBED 로 감싼다.
# → 나머지 Host:: 는 재사용, 렌더 그룹은 ARMSX2Host.mm 가 제공.
# Main.cpp 자체는 Host 타깃(project.yml)에서 -DARMSX2_EMBED 로 컴파일된다.
PATCH="$ROOT/04_patches/armsx2/0001-embed-frontend.patch"
if git -C "$SRC" apply --reverse --check "$PATCH" 2>/dev/null; then
  echo "  이미 적용됨"
elif git -C "$SRC" apply --check "$PATCH" 2>/dev/null; then
  git -C "$SRC" apply "$PATCH"; echo "  적용 완료"
else
  echo "  ⚠ 자동 적용 실패(컨텍스트 불일치). patch 헤더 지침대로 수동 삽입 후 재생성 필요(NOT_TESTED)."
fi

echo "[ARMSX2] iOS 의존성 빌드(PNG/JPEG/Zstd/LZ4/WebP/SDL3/Freetype/plutovg/plutosvg)"
bash "$HERE/build_armsx2_deps_ios.sh"
DEPS="$HERE/prebuilt/armsx2/deps/prefix"

echo "[ARMSX2] CMake 구성(iOS arm64, Ninja 생성기)"
BUILD="$SRC/build-ios-starlight"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$DEPS" \
  -DCMAKE_FIND_ROOT_PATH="$DEPS" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
  -DPACKAGE_MODE=OFF -DDISABLE_ADVANCE_SIMD=ON \
  -DUSE_VULKAN=ON 2>&1 | tee "$LOG/armsx2_cmake.log"

echo "[ARMSX2] 코어 라이브러리 빌드 (PCSX2 + common)"
# Main.cpp 는 Host 타깃에서 -DARMSX2_EMBED 로 컴파일(정의는 patch 참고).
cmake --build "$BUILD" --target PCSX2 -j 2>&1 | tee "$LOG/armsx2_build.log"
cmake --build "$BUILD" --target common -j 2>&1 | tee -a "$LOG/armsx2_build.log"

echo "[ARMSX2] 산출물 수집 → $OUT"
find "$BUILD" -name '*.a' -exec cp -v {} "$OUT/" \;
# BIOS 는 저작권 자산이므로 포함하지 않음(사용자가 실기기 dataRoot/bios 에 배치).
echo "[ARMSX2] 완료. 링크: $OUT/*.a. BIOS 는 런타임 dataRoot/bios 에 배치(지시문 8·13항)."
