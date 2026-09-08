#!/usr/bin/env bash
#
# embed_and_package.sh — 빌드된 Host .app 에 엔진 런타임(dylib/프레임워크)과 자산을 임베드하고
# unsigned IPA 로 재패키징 (Mac/CI 전용). 실기기 재서명(SideStore/AltStore)이 프레임워크까지 서명한다.
#
# 임베드 대상:
#   MeloNX: Ryujinx.Headless.SDL2.dylib + XCFrameworks(ios-arm64 슬라이스) + DynamicLibraries
#           (Hypervisor.framework 은 TrollStore 전용이라 기본 제외)
#   PPSSPP: libMoltenVK.dylib + assets(flash0/fonts/lang/shaders…)
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/09_output"; LOG="$ROOT/08_logs"; mkdir -p "$OUT" "$LOG"
PB="$HERE/prebuilt"

APP=$(find "$HERE/DerivedData" -name 'StarlightEmulator.app' -type d 2>/dev/null | head -1)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "embed: StarlightEmulator.app 없음 → Host 빌드 로그 확인" | tee -a "$LOG/embed.log"; exit 0
fi
FW="$APP/Frameworks"; mkdir -p "$FW"
echo "[embed] app: $APP" | tee "$LOG/embed.log"

# ---- MeloNX 런타임 ----
MB="$PB/melonx"
if [ -f "$MB/Ryujinx.Headless.SDL2.dylib" ]; then
  cp -v "$MB/Ryujinx.Headless.SDL2.dylib" "$FW/" 2>&1 | tee -a "$LOG/embed.log"
  # DynamicLibraries: 프레임워크/ dylib (Hypervisor 제외)
  if [ -d "$MB/DynamicLibraries" ]; then
    for f in "$MB/DynamicLibraries/"*.framework; do
      [ -d "$f" ] || continue
      case "$(basename "$f")" in Hypervisor.framework) continue;; esac
      cp -R "$f" "$FW/" 2>&1 | tee -a "$LOG/embed.log"
    done
    cp -v "$MB/DynamicLibraries/"*.dylib "$FW/" 2>/dev/null | tee -a "$LOG/embed.log" || true
  fi
  # XCFrameworks: ios-arm64 (device, non-simulator) 슬라이스의 .framework 만 임베드
  if [ -d "$MB/XCFrameworks" ]; then
    for xc in "$MB/XCFrameworks/"*.xcframework; do
      [ -d "$xc" ] || continue
      for d in "$xc"/*/; do
        case "$d" in *simulator*) continue;; esac
        [ "$(basename "$d")" != "ios-arm64" ] && continue
        for fwk in "$d"*.framework; do
          [ -d "$fwk" ] && cp -R "$fwk" "$FW/" 2>&1 | tee -a "$LOG/embed.log"
        done
      done
    done
  fi
fi

# ---- PPSSPP 런타임 ----
if [ -f "$PB/ppsspp/libMoltenVK.dylib" ] && [ ! -f "$FW/libMoltenVK.dylib" ]; then
  cp -v "$PB/ppsspp/libMoltenVK.dylib" "$FW/" 2>&1 | tee -a "$LOG/embed.log"
fi
# PPSSPP 자산(런타임 필요: flash0 폰트/lang/shaders). 번들 내 EngineResources/PPSSPP 로 배치.
if [ -d "$PB/ppsspp/assets" ]; then
  mkdir -p "$APP/EngineResources/PPSSPP"
  cp -R "$PB/ppsspp/assets/." "$APP/EngineResources/PPSSPP/" 2>/dev/null || true
  echo "[embed] PPSSPP assets → EngineResources/PPSSPP" | tee -a "$LOG/embed.log"
fi

# ---- 진단: 실행 파일/코어 dylib 의 의존성(@rpath) ----
{
  echo "=== otool -L (Host 실행파일) ==="; otool -L "$APP/StarlightEmulator" 2>/dev/null | head -40
  echo "=== otool -L (MeloNX dylib) ==="; otool -L "$FW/Ryujinx.Headless.SDL2.dylib" 2>/dev/null | head -60
  echo "=== 임베드된 Frameworks 목록 ==="; ls -1 "$FW" 2>/dev/null
} | tee "$LOG/embed_otool.log"

# ---- IPA 재패키징 ----
rm -rf "$OUT/Payload" "$OUT/StarlightEmulator_Phase1_unsigned.ipa"
mkdir -p "$OUT/Payload"; cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -qry StarlightEmulator_Phase1_unsigned.ipa Payload && rm -rf Payload )
shasum -a 256 "$OUT/StarlightEmulator_Phase1_unsigned.ipa" | tee "$OUT/StarlightEmulator_Phase1_unsigned.ipa.sha256"
echo "[embed] IPA: $OUT/StarlightEmulator_Phase1_unsigned.ipa ($(du -h "$OUT/StarlightEmulator_Phase1_unsigned.ipa" | cut -f1))" | tee -a "$LOG/embed.log"
