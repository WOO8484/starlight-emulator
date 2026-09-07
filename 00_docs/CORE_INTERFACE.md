# CORE_INTERFACE.md — 공통 Adapter 규격 (지시문 5·6항)

> 원칙(지시문 5항): 처음부터 거대한 공통 API 를 만들지 않는다. 1단계에 필요한 최소만 정의한다.
> 아래 미공통화 목록(설정 UI/세이브스테이트/치트/메타/커버/플레이타임/즐겨찾기/최종 UI)은 2단계로.

## 1. 호출 계층 (지시문 6항)

```
IntegrationHost (ContentView / HostViewModel)
      ↓  (오직 이 경로만)
EmulatorManager
      ↓
EmulatorModule  (프로토콜)
      ↓
각 Adapter (PPSSPPAdapter / ARMSX2Adapter / MeloNXAdapter)
      ↓
각 Core 브리지 (PPSSPPCore.mm / ARMSX2Core.mm / MeloNXCore.swift)
      ↓
각 Engine (NativeApp / VMManager / SN_* C ABI)
```

UI 에서 `NativeInit()`, `VMManager::Initialize()`, `SN_main_ryujinx_sdl()` 를 **직접 호출 금지**.

## 2. EmulatorModule (최소 인터페이스)

`03_adapters/common/EmulatorModule.swift`

| 멤버 | 의미 |
|---|---|
| `id: String` | 안정 식별자 ("ppsspp"/"armsx2"/"melonx") |
| `system: EmulatorSystem` | 담당 콘솔 (psp/ps2/switchNX) |
| `state: EmulatorState` | 현재 상태(동기 조회) |
| `delegate` | 상태/오류/Host복귀 통지 |
| `initialize(context:)` | 실행 준비(경로 생성, 코어 정적 init). 멱등. 부팅 안 함 |
| `canHandle(_:)` | 확장자/헤더 기반 처리 가능 판정 |
| `launch(_:)` | 게임 부팅(블로킹 엔진은 내부 전용 스레드) |
| `pause()` / `resume()` | 일시정지/재개 |
| `stop()` | 정지 + GPU/오디오/JIT 해제, relaunch 가능 상태로 |
| `isRunning()` | 실행 여부 |
| `shutdown()` | 정적 리소스까지 해제(프로세스 종료 전) |

선택 확장(필요 시): `EmulatorSettingsProviding`(get/setSettings), `EmulatorSavePathProviding`(getSavePath).

### 상태 머신 (`EmulatorState`)
```
idle → initialized → launching → running ⇄ paused
                                   ↓
                              stopping → stopped → (relaunch) launching …
   (오류 발생 시 어느 지점에서든) → failed
```

## 3. EmulatorContext (initialize 주입값)

`03_adapters/common/EmulatorTypes.swift`

- `metalLayer: CAMetalLayer` — 공유 렌더 surface(코어가 대여, stop 시 반환)
- `dataRoot: URL` — **시스템별 격리** 데이터 루트(Application Support/StarlightEmulator/<engine>)
- `resourceRoot: URL` — 번들 내 upstream 리소스
- `sharedGameLibrary: URL?` — 사용자 지정 공용 게임 폴더(지시문 13항 단서)
- `jitAvailable: Bool` — JITManager 판정 결과

## 4. EmulatorManager 역할 (지시문 6항)

`03_adapters/common/EmulatorManager.swift`

- 모듈 등록/조회 (`register`, `module(for:)`, `selectModule(for:)`)
- 실행할 모듈 선택 → **기존 코어 정상 종료 후** 새 코어 launch (핵심: 코어 전환 안전성)
- 서로 다른 코어로 전환 시 이전 코어 `shutdown()` 으로 리소스 잔류 방지
- 현재 코어/상태/마지막 오류 관리 → `EmulatorManagerObserver` 로 UI 통지
- `stopCurrent()` → 정지 후 Host 복귀
- `shutdownAll()` → 앱 종료/메모리 경고 시 전체 정리

## 5. 데이터 격리 (지시문 13항)

`03_adapters/common/StarlightPaths.swift` 가 단일 소스.
```
Application Support/StarlightEmulator/
├─ PPSSPP/   config, save, cache, screenshots
├─ ARMSX2/   config, memcards, savestates, cache, bios, shader_cache
└─ MeloNX/   system(keys), bis(firmware), games, sdcard, shader_cache, logs
```
공용 게임 라이브러리(선택)는 `Documents/GameLibrary/` 로 별도 관리.

## 6. 스레드 모델

- Swift 계층/Manager/Delegate 콜백: **메인 액터**.
- PPSSPP: 코어 내부 EmuThread + 메인 DisplayLink(NativeFrame).
- ARMSX2: **전용 CPU 스레드**(VMManager::Execute 루프). stop 은 스레드 종료까지 대기.
- MeloNX: **전용 스레드**(블로킹 SN_main_ryujinx_sdl). stop 은 SN_stop_emulation 후 반환 대기.

## 7. 미공통화(2단계) — 지시문 5항
설정 UI · 세이브스테이트 공통 규격 · 치트 · 메타정보 · 커버 · 플레이타임 · 즐겨찾기 · 최종 UI.
