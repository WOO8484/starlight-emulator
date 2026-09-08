# Starlight Emulator (103 통합 에뮬) — Phase 1

PSP·PS2·Switch 세 에뮬레이터 엔진을 **하나의 iOS 앱 내부의 독립 모듈**로 실행·종료·재실행하는
통합 프로젝트. **새 에뮬레이터를 만들지 않고**, 검증된 원본 엔진을 얇은 Adapter + EmulatorManager 로
연결한다.

```
PSP    → PPSSPP
PS2    → ARMSX2 (PCSX2 fork)
Switch → MeloNX (Ryujinx fork)
```

## ⚠️ 포함되지 않는 것 (중요)
이 저장소에는 **저작권/개인 자료가 포함되지 않습니다.**
- ❌ PS2 BIOS · Switch prod.keys/title.keys · firmware
- ❌ 게임 이미지(ISO/CSO/NSP/XCI 등) · 세이브 데이터
- ❌ Apple 인증서/프로비저닝/토큰 등 비밀

포함되는 것: **통합 Host · Adapter · patch · 빌드 스크립트 · CI 워크플로 · 문서**뿐.
BIOS/keys/firmware/게임은 **사용자가 본인 실기기에서만** 합법적으로 확보·사용합니다.

## 현재 상태 (정직 표기)
- ✅ 통합 구조(Adapter/Manager/Host), 엔진별 링크 준비, 렌더 브리지, 빌드 스크립트, CI 파이프라인 **준비 완료**
- ⏳ **iOS 실빌드 / IPA / 실기기 실행 = 미검증(NOT_TESTED)** — GitHub Actions 첫 실행으로 검증 예정
- 상세: [`00_docs/PHASE1_RESULT.md`](00_docs/PHASE1_RESULT.md)

미검증 기능을 완료된 것으로 표기하지 않습니다.

## 빌드 방식 — Mac 없이 (GitHub Actions)
로컬 개발은 Windows, 실제 iOS 컴파일은 **GitHub Actions macOS 러너**가 수행합니다.
```
Windows 에서 개발/수정 → git push → Actions "iOS Build" 실행
→ 빌드 로그 + unsigned IPA artifact 회수 → iPhone 재서명(SideStore/AltStore)·설치
```
자세한 방법: [`00_docs/CI_BUILD_GUIDE.md`](00_docs/CI_BUILD_GUIDE.md)

## 외부 upstream (기준 commit — 임의 최신화 안 함)
| 엔진 | 저장소 | commit |
|---|---|---|
| PPSSPP | hrydgard/ppsspp | `98e70c8c` |
| ARMSX2 | ARMSX2/ARMSX2 | `de57f431` |
| MeloNX | AzureDominus/melonx @`XC-ios-ht` | `55f84af1` |

원본은 저장소에 복제하지 않고 CI 가 위 commit 으로 clone 합니다. 우리 변경은 `04_patches/` 에만
격리(PPSSPP CMake append 1건, ARMSX2 Main.cpp guard 1건, MeloNX 0건).

## 구조
```
00_docs/      계획·인터페이스·빌드노트·충돌분석·업데이트·CI 가이드·결과
01_sources/   upstream (gitignore; CI/submodule 로 확보)
02_host/      StarlightEmulator (최소 통합 테스트 Host, SwiftUI)
03_adapters/  common + ppsspp/armsx2/melonx
04_patches/   불가피한 최소 변경(빌드 경계 한정)
06_tests/     코어 전환 체크리스트 + XCUITest
07_build/     XcodeGen project.yml + 빌드 스크립트
.github/workflows/  ios-build.yml (수동 실행)
```

## 지원 대상
- iPhone 16 Pro Max (Phase 1 고정). 범용 기기/iPad 대응 없음.

## 라이선스
- 이 저장소 코드: **GPL-3.0-or-later** ([`LICENSE`](LICENSE))
  (PCSX2 GPLv3·PPSSPP GPLv2+ 결합 결과물이 GPLv3 이므로)
- 각 엔진/서드파티 라이선스: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

## 핵심 원칙
엔진 재구현 금지 · 거대 공통 코어 금지 · 최종 GUI(2단계) · 가짜 렌더/버튼-성공 기록 금지 ·
실제 오류 근거 전 구조 선변경 금지 · 작업 루트 밖 사용 금지.
