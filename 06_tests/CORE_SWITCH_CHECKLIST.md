# 코어 전환 체크리스트 (지시문 12·15항)

실기기(iPhone 16 Pro Max)에서 각 항목을 직접 확인하고 `PASS / FAIL / NOT_TESTED` 로 기록한다.
추측/예상으로 PASS 기록 금지(지시문 15항).

## 사전 조건
- [ ] 세 엔진 `*_LINKED=1` 로 링크된 빌드
- [ ] `Documents/TestData/PPSSPP/` 에 PSP 게임(.iso/.cso)
- [ ] `Documents/TestData/ARMSX2/` 에 PS2 게임(.iso) + `Application Support/StarlightEmulator/ARMSX2/bios/` 에 PS2 BIOS
- [ ] `Documents/TestData/MeloNX/` 에 Switch 게임(.nsp/.xci) + `.../MeloNX/system/prod.keys` + firmware
- [ ] JIT 활성(JIT: READY) — AltStore/SideStore/JitStreamer/StikJIT 또는 TrollStore

## 단일 코어 (각 시스템)
| 항목 | PSP | PS2 | Switch |
|---|---|---|---|
| launch | ☐ | ☐ | ☐ |
| pause | ☐ | ☐ | ☐ |
| resume | ☐ | ☐ | ☐ |
| stop | ☐ | ☐ | ☐ |
| relaunch | ☐ | ☐ | ☐ |
| 정상 렌더링 | ☐ | ☐ | ☐ |
| 정상 오디오 | ☐ | ☐ | ☐ |
| 입력 동작 | ☐ | ☐ | ☐ |
| stop 후 Host 복귀 | ☐ | ☐ | ☐ |

## 전환 시퀀스 (지시문 12항)
순서: PPSSPP → STOP → ARMSX2 → STOP → MeloNX → STOP → PPSSPP → STOP → MeloNX → STOP → ARMSX2

각 전환 지점마다 확인:
- [ ] crash 없음
- [ ] hang 없음
- [ ] 메모리 누수 없음 (Instruments/Allocations)
- [ ] GPU resource 잔류 없음
- [ ] Metal surface 충돌 없음
- [ ] 오디오 세션 충돌 없음
- [ ] 컨트롤러 재연결 정상
- [ ] JIT 재초기화 정상
- [ ] 설정 경로 충돌 없음 (각 엔진 데이터 격리 유지)
- [ ] 세이브 경로 충돌 없음
- [ ] 이전 게임 화면 잔상 없음
- [ ] 코어 종료 후 Host 복귀

## 교차 테스트 (지시문 15항)
- [ ] PSP → PS2
- [ ] PS2 → Switch
- [ ] Switch → PSP
- [ ] PSP → Switch
- [ ] Switch → PS2
- [ ] PS2 → PSP

## 자동화
`06_tests/StarlightEmulatorUITests/CoreSwitchUITests.swift` (XCUITest) 로 전환 시퀀스를 자동 반복.
Xcode: Product ▸ Test, 또는 `xcodebuild test -scheme StarlightEmulator -destination 'platform=iOS,name=<기기>'`.
