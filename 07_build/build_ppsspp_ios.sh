#!/usr/bin/env bash
#
# build_ppsspp_ios.sh — PPSSPP 를 iOS(arm64) 정적 라이브러리로 빌드 (Mac 전용)
# 결과: libPPSSPPCore.a (+ 필요한 3rd-party .a) 와 libMoltenVK.dylib 를 07_build/prebuilt/ppsspp/ 로 수집.
# 상태: Windows 에서 미실행(NOT_TESTED). Mac 에서 실행하여 검증할 것.
#
# 전제: Xcode + CMake. PPSSPP 소스는 01_sources/PPSSPP (submodule 권장, 서브모듈 포함).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/01_sources/PPSSPP"
OUT="$HERE/prebuilt/ppsspp"
LOG="$ROOT/08_logs"; mkdir -p "$OUT" "$LOG"

COMMIT="98e70c8ca3435d532a059add0b4fb90a4a091248"   # BUILD_NOTES 기준(교체 시 갱신)

if [ ! -d "$SRC/.git" ]; then
  echo "[PPSSPP] 소스 클론"
  git clone https://github.com/hrydgard/ppsspp.git "$SRC"
fi
echo "[PPSSPP] commit 고정 + 서브모듈"
git -C "$SRC" fetch --all --tags
git -C "$SRC" checkout "$COMMIT"
git -C "$SRC" submodule update --init --recursive

echo "[PPSSPP] 정적 라이브러리 타깃 추가(원본 라인 수정 없이 append, 멱등)"
# 원본 CMakeLists.txt 끝에 PPSSPPCore STATIC 타깃 정의를 append 한다(가장 얕은 변경).
if ! grep -q "Starlight: PPSSPPCore static library target added" "$SRC/CMakeLists.txt"; then
  { echo ""; cat "$ROOT/04_patches/ppsspp/append_static_lib.cmake"; } >> "$SRC/CMakeLists.txt"
  echo "  append 완료"
else
  echo "  이미 append 됨"
fi

echo "[PPSSPP] CMake 구성(iOS arm64, Ninja 생성기)"
# Ninja 를 쓰는 이유: Xcode 생성기는 GitVersion 커스텀 커맨드가 만드는 git-version.cpp 의
# 생성 순서를 보장하지 못해 'Build input file cannot be found: git-version.cpp' 로 실패한다.
# Ninja 는 생성 파일 의존성을 정확히 정렬한다.
BUILD="$SRC/build-ios-starlight"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$SRC/cmake/Toolchains/ios.cmake" \
  -DIOS=ON -DIOS_PLATFORM=OS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DUSING_QT_UI=OFF 2>&1 | tee "$LOG/ppsspp_cmake.log"

echo "[PPSSPP] 정적 라이브러리 빌드"
cmake --build "$BUILD" --target PPSSPPCore -j 2>&1 | tee "$LOG/ppsspp_build.log"

echo "[PPSSPP] 산출물 수집 → $OUT"
find "$BUILD" -name '*.a' -exec cp -v {} "$OUT/" \;
# MoltenVK (PPSSPP 동봉본)
cp -v "$SRC/ext/vulkan/iOS/Frameworks/libMoltenVK.dylib" "$OUT/" 2>/dev/null || \
  echo "  경고: libMoltenVK.dylib 위치 확인 필요"
# 게임 자산(번들 resourceRoot 로 복사할 대상)
mkdir -p "$OUT/assets"
cp -R "$SRC/assets/." "$OUT/assets/" 2>/dev/null || true

echo "[PPSSPP] 완료. 링크 대상: $OUT/*.a + libMoltenVK.dylib, 자산: $OUT/assets"
echo "  → project.yml 의 PPSSPP dependencies/HEADER_SEARCH_PATHS 와 연결됨(주석 해제)."
