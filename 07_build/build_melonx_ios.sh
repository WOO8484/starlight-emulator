#!/usr/bin/env bash
#
# build_melonx_ios.sh — MeloNX(Ryujinx) 코어를 iOS(arm64) NativeAOT dylib 로 빌드 (Mac 전용)
# 근거: 01_sources/MeloNX/distribution/ios/{compile.sh,xc-compile.sh} 원본 레시피.
# 결과: Ryujinx.Headless.SDL2.dylib + 벤더 프레임워크들을 07_build/prebuilt/melonx/ 로 수집.
# 상태: Windows 미실행(NOT_TESTED). .NET 8 SDK + ios workload + NativeAOT 툴체인 필요.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/01_sources/MeloNX"
OUT="$HERE/prebuilt/melonx"
LOG="$ROOT/08_logs"; mkdir -p "$OUT" "$LOG"

COMMIT="55f84af15144e40d7fbe8984747855534d2a8ec1"   # AzureDominus/melonx@XC-ios-ht
BRANCH="XC-ios-ht"

# CI(01_sources 미포함) 대비: 소스가 없으면 기준 commit 으로 확보. 임의 최신화 금지.
if [ ! -d "$SRC/.git" ]; then
  echo "[MeloNX] 소스 클론(@$BRANCH)"
  git clone --branch "$BRANCH" https://github.com/AzureDominus/melonx.git "$SRC"
fi
echo "[MeloNX] commit 고정: $COMMIT"
git -C "$SRC" fetch --all --tags 2>/dev/null || true
git -C "$SRC" checkout "$COMMIT" 2>&1 | tail -2 || { echo "error: 기준 commit checkout 실패(임의 최신화 금지)"; exit 1; }
git -C "$SRC" submodule update --init --recursive 2>/dev/null || true

# .NET 위치 탐색(원본 get_dotnet.sh 와 동일 개념). 필요 시 `dotnet workload install ios` 선행.
DOTNET="$(command -v dotnet || true)"
[ -z "$DOTNET" ] && DOTNET="$($SRC/distribution/ios/get_dotnet.sh 2>/dev/null || true)"
if [ -z "$DOTNET" ]; then echo "error: .NET 8 SDK 필요(https://dotnet.microsoft.com). 'dotnet workload install ios' 도 필요."; exit 1; fi
echo "[MeloNX] dotnet: $DOTNET"

echo "[MeloNX] NativeAOT publish (ios-arm64, Release)"
cd "$SRC"
"$DOTNET" clean 2>&1 | tee "$LOG/melonx_build.log" || true
"$DOTNET" restore 2>&1 | tee -a "$LOG/melonx_build.log"
"$DOTNET" publish -c Release -r ios-arm64 \
  -p:ExtraDefineConstants=DISABLE_UPDATER \
  src/Ryujinx.Headless.SDL2 --self-contained true 2>&1 | tee -a "$LOG/melonx_build.log"

NATIVE="$SRC/src/Ryujinx.Headless.SDL2/bin/Release/net8.0/ios-arm64/native/Ryujinx.Headless.SDL2.dylib"
if [ ! -f "$NATIVE" ]; then echo "error: NativeAOT dylib 생성 실패: $NATIVE"; exit 1; fi

echo "[MeloNX] 산출물 수집 → $OUT"
cp -v "$NATIVE" "$OUT/"                                   # 모든 SN_*(main_ryujinx_sdl 등) C 심볼 포함
# 벤더 프레임워크/라이브러리(런타임 링크 대상)
DEP="$SRC/src/MeloNX/MeloNX/Dependencies"
cp -R "$DEP/XCFrameworks/." "$OUT/XCFrameworks/" 2>/dev/null || true          # SDL2 / libav* / libSPIRV / libteakra
cp -R "$DEP/Dynamic Libraries/." "$OUT/DynamicLibraries/" 2>/dev/null || true # RyujinxHelper / BreakpointJIT / (Hypervisor) / libMoltenVK / libav*
# icu 데이터(InvariantGlobalization=true 라 보통 불필요하지만 원본 빌드가 복사함)
cp -v "$SRC/src/Ryujinx.Headless.SDL2/bin/Release/net8.0/ios-arm64/native/icudt.dat" "$OUT/" 2>/dev/null || true

echo "[MeloNX] 완료. 링크: Ryujinx.Headless.SDL2.dylib + XCFrameworks/* + DynamicLibraries/*"
echo "  prod.keys/firmware 는 런타임 dataRoot/system, dataRoot/bis 에 배치(지시문 9·13항)."
