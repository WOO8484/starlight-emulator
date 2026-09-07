# 103 통합 에뮬 — Starlight Emulator (Phase 1)

PSP(PPSSPP) · PS2(ARMSX2) · Switch(MeloNX) 세 엔진을 **단일 iOS 앱 내부의 독립 모듈**로
실행·종료·재실행하는 구조를 만드는 프로젝트. **새 에뮬레이터를 만들지 않고** 검증된 원본
엔진을 얇은 Adapter + EmulatorManager 로 연결한다(지시문 23항).

## ⚠ 환경 상태
이 저장소는 **Windows 에서 작성**되었다(Xcode/macOS/실기기 없음). 따라서 소스 통합 · Adapter/Host
구현 · 빌드 설정 · 테스트 절차까지 준비되어 있고, **실제 빌드·실기기 검증은 macOS+Xcode+
iPhone 16 Pro Max 에서** 수행해야 한다. 관련 항목은 모두 `NOT_TESTED`(→ `00_docs/PHASE1_RESULT.md`).

## 구조
```
00_docs/      계획·인터페이스·빌드노트·업데이트가이드·결과 보고
01_sources/   upstream 엔진 원본 (PPSSPP / ARMSX2 / MeloNX) — gitignore, submodule 권장
02_host/      StarlightEmulator (최소 통합 테스트 Host, SwiftUI)
03_adapters/  common(EmulatorModule/Manager/Types/Paths) + ppsspp/armsx2/melonx
04_patches/   불가피한 upstream 변경만 (현재 0개)
05_testdata/  PSP/PS2/Switch 테스트 게임 (gitignore)
06_tests/     전환 체크리스트 + XCUITest 자동화
07_build/     XcodeGen project.yml + build_ios.sh
08_logs/      로그
09_output/    IPA/워크스페이스 산출물
_cache/       캐시/임시 (gitignore)
```

## 다음 단계 (Mac)
1. `00_docs/UPDATE_GUIDE.md` 대로 `01_sources` 를 submodule 로 고정
2. 각 엔진을 정적 라이브러리/프레임워크로 빌드 → `07_build/project.yml` 의 `*_LINKED` 활성
3. `cd 07_build && xcodegen generate` → Xcode 로 열기
4. iPhone 16 Pro Max 서명·JIT(AltStore/SideStore/JitStreamer/StikJIT 또는 TrollStore) 준비
5. `06_tests/CORE_SWITCH_CHECKLIST.md` 로 실기기 검증 → `PHASE1_RESULT.md` 갱신

## 핵심 원칙 (지시문 22·23항)
- 엔진 재구현 금지 · 거대 공통 코어 금지 · 최종 GUI 금지(2단계)
- 가짜 렌더링/버튼-만-동작을 실제 실행 성공으로 기록 금지
- 실패해도 외부 앱 호출로 몰래 대체 금지(기술적 근거 있을 때만 후보)
- 작업 루트(`X:\103 통합에뮬`) 밖을 작업공간으로 사용 금지
