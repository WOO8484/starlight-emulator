#!/usr/bin/env bash
#
# build_ios.sh — Mac 전용 빌드 스크립트 (Windows 에서는 실행 불가)
# 지시문 16항: Xcode/macOS 가 있는 환경에서 실행. Windows 환경 결과는 NOT_TESTED.
#
# 전제:
#   brew install xcodegen
#   (엔진 링크 시) 각 엔진 정적 라이브러리/xcframework 준비 + project.yml 의 *_LINKED 활성
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/09_output"
LOG="$ROOT/08_logs"
mkdir -p "$OUT" "$LOG"

echo "[1/3] XcodeGen 프로젝트 생성"
cd "$HERE"
xcodegen generate 2>&1 | tee "$LOG/xcodegen.log"

echo "[2/3] 빌드 (Debug, generic iOS device)"
# 실기기 서명 설정은 Xcode 프로젝트 또는 아래 인자에 맞춰 조정한다.
xcodebuild \
  -project "$HERE/StarlightEmulator.xcodeproj" \
  -scheme StarlightEmulator \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$ROOT/07_build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee "$LOG/xcodebuild.log"

echo "[3/3] (선택) IPA 패키징"
APP="$ROOT/07_build/DerivedData/Build/Products/Debug-iphoneos/StarlightEmulator.app"
if [ -d "$APP" ]; then
  rm -rf "$OUT/Payload" "$OUT/StarlightEmulator_Phase1.ipa"
  mkdir -p "$OUT/Payload"
  cp -R "$APP" "$OUT/Payload/"
  ( cd "$OUT" && zip -qr "StarlightEmulator_Phase1.ipa" Payload && rm -rf Payload )
  echo "생성됨: $OUT/StarlightEmulator_Phase1.ipa"
else
  echo "앱 산출물 없음(서명/링크 확인). IPA 미생성."
fi
echo "완료."
