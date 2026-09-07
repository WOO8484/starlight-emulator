#!/usr/bin/env bash
#
# generate_host.sh — XcodeGen 으로 Starlight Host 프로젝트 생성 (Mac 전용)
# 엔진 라이브러리가 07_build/prebuilt/{ppsspp,armsx2,melonx} 에 준비되어 있으면
# project.yml 의 *_LINKED / dependencies 를 자동 활성화한다.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

command -v xcodegen >/dev/null || { echo "error: xcodegen 필요 (brew install xcodegen)"; exit 1; }

# prebuilt 존재 여부에 따라 활성 매크로 표시(참고용). 실제 활성은 project.yml 에서 관리.
for e in ppsspp armsx2 melonx; do
  if ls "$HERE/prebuilt/$e/"*.a >/dev/null 2>&1 || ls "$HERE/prebuilt/$e/"*.dylib >/dev/null 2>&1; then
    echo "[generate_host] $e prebuilt 감지됨 → project.yml 의 해당 *_LINKED 블록을 활성화하세요."
  else
    echo "[generate_host] $e prebuilt 없음 → 스캐폴드(미링크)로 생성."
  fi
done

cd "$HERE"
xcodegen generate
echo "[generate_host] StarlightEmulator.xcodeproj 생성 완료."
