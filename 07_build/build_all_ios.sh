#!/usr/bin/env bash
#
# build_all_ios.sh — 전체 파이프라인 (Mac 전용)
#   PPSSPP → ARMSX2 → MeloNX → Host 생성 → Host 빌드
# 상태: Windows 미실행(NOT_TESTED). Mac 에서 이 한 스크립트만 실행하면 되도록 구성.
#
# 옵션 환경변수:
#   SKIP_PPSSPP=1 / SKIP_ARMSX2=1 / SKIP_MELONX=1  → 해당 엔진 빌드 생략
#   NO_BUILD=1  → 라이브러리/프로젝트 생성까지만, xcodebuild 생략
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LOG="$ROOT/08_logs"; mkdir -p "$LOG"

echo "==================== [1/5] PPSSPP ===================="
[ "${SKIP_PPSSPP:-0}" = "1" ] && echo "  생략" || bash "$HERE/build_ppsspp_ios.sh"

echo "==================== [2/5] ARMSX2 ===================="
[ "${SKIP_ARMSX2:-0}" = "1" ] && echo "  생략" || bash "$HERE/build_armsx2_ios.sh"

echo "==================== [3/5] MeloNX ===================="
[ "${SKIP_MELONX:-0}" = "1" ] && echo "  생략" || bash "$HERE/build_melonx_ios.sh"

echo "==================== [4/5] Host 프로젝트 생성 ===================="
bash "$HERE/generate_host.sh"

echo "==================== [5/5] Host 빌드 ===================="
if [ "${NO_BUILD:-0}" = "1" ]; then
  echo "  NO_BUILD=1 → xcodebuild 생략. Xcode 에서 열어 서명/실기기 실행하세요."
else
  bash "$HERE/build_ios.sh"
fi

echo "==================== 완료 ===================="
echo "다음: iPhone 16 Pro Max 서명 + JIT 활성 + 06_tests/CORE_SWITCH_CHECKLIST.md 실기기 검증"
