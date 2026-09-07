# PHASE1_PLAN.md — 1단계 계획

## 목표 (지시문 1항)
새 에뮬레이터를 만들지 않고, 검증된 3개 엔진(PPSSPP/ARMSX2/MeloNX)을 **단일 iOS 앱
(StarlightEmulator) 내부의 독립 모듈**로 연결하여 PSP/PS2/Switch 게임을 실행·종료·재실행하고
Host 화면으로 복귀할 수 있는 **구조**를 완성한다. GUI 완성은 2단계.

## 최종 구조 (지시문 1항)
```
StarlightEmulator.app
├─ IntegrationHost (02_host)         기능 검증용 최소 화면
├─ EmulatorManager (03_adapters/common)
├─ Adapters (03_adapters/{ppsspp,armsx2,melonx})
└─ Engines (01_sources/{PPSSPP,ARMSX2,MeloNX})  ← 원본 최대한 그대로
```

## 설계 원칙 (지시문 2·23항)
1. 엔진 비개입: 원본 공개 API 우선 → Adapter 변환 → 최소 Bridge/Shim → 불가피 시 최소 patch(04_patches 에 기록).
2. 우리 코드는 얇은 Adapter + EmulatorManager 만 담당.
3. 업데이트 용이성: upstream 교체 + 최소 patch + 재빌드 로 갱신 가능(UPDATE_GUIDE 참조).

## 환경 제약 (지시문 16·21항) — 중요
- 현재 작업 환경 = **Windows** (cmake/clang/xcodebuild/실기기 없음).
- 따라서 이 저장소는 **소스 통합 · Adapter/Host 구현 · 빌드 설정 · 테스트 절차**까지 준비한다.
- **빌드/실기기 실행/런타임 검증(JIT·렌더·오디오·입력)은 macOS+Xcode+iPhone 16 Pro Max 에서** 수행해야 하며,
  그 전까지 해당 항목은 모두 `NOT_TESTED` 로 기록한다(성공 기록 금지 — 지시문 22항).

## 진행 순서 (지시문 20항, 자율 진행)
환경/폴더 확인 → 공통 Adapter 정의 → PPSSPP 연결 → ARMSX2 연결 → MeloNX 연결 →
EmulatorManager → 최소 Host → 빌드 설정 → (Mac)실기기 테스트 → 교차 코어 테스트 →
업데이트 구조 테스트 → 문서화 → 완료 보고.

## 대상 기기 (지시문 16항)
iPhone 16 Pro Max 고정. 범용 iPhone/iPad/구형 최적화 없음. TARGETED_DEVICE_FAMILY=1.

## 산출물 (지시문 17항)
`00_docs`(CORE_INTERFACE/BUILD_NOTES/UPDATE_GUIDE/PHASE1_RESULT/PHASE1_PLAN) ·
`03_adapters`(common+3) · `07_build`(XcodeGen project.yml → .xcodeproj/워크스페이스) ·
가능 시 `09_output/StarlightEmulator_Phase1.ipa`.
