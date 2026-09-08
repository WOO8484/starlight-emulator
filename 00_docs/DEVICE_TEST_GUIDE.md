# DEVICE_TEST_GUIDE.md — iPhone 16 Pro Max 실기기 테스트 (PSP + Switch)

> 대상: PPSSPP(PSP) + MeloNX(Switch) 2엔진이 실링크·임베드된 unsigned IPA.
> ARMSX2(PS2)는 별도 진행 중(미포함). 이 문서의 런타임 항목은 **NOT_TESTED**(개발 환경에 실기기 없음) —
> 사용자가 실기기에서 검증하고 결과를 PHASE1_RESULT 에 기록한다.
> ⚠ BIOS/keys/firmware/게임은 저장소에 없다. 본인 실기기에서 합법적으로 확보·배치한다.

## 1. IPA 받기
GitHub Actions 실행 페이지 → 하단 **Artifacts → `app-ipa`** 다운로드(zip) → 압축 해제 →
`StarlightEmulator_Phase1_unsigned.ipa` (~100MB, PSP+Switch 임베드).
- 직접 설치용 링크(SideStore가 URL로 설치)가 필요하면 GitHub Release 로 올릴 수 있다(요청 시).

## 2. 설치 / 서명 (unsigned → 실기기)
개발자 Mac 없이 설치하는 경로:
- **SideStore / AltStore**: 앱에서 unsigned IPA 를 import → 본인 Apple ID 로 재서명·설치(7일).
  임베드된 프레임워크(SDL2/FFmpeg/MoltenVK/Ryujinx dylib)도 함께 서명된다.
- **TrollStore**(가능 기기): 영구 설치 + 강력한 entitlement(하이퍼바이저 등). MeloNX 최고 성능 경로.

## 3. JIT 활성 (PS2/Switch 필수, PSP 선택)
- PPSSPP(PSP): JIT 없이 인터프리터로도 실행됨(JIT 있으면 빠름).
- MeloNX(Switch): **JIT 필수**. 아래 중 하나로 활성 후 코어 실행:
  - SideStore 의 **Enable JIT**, 또는 **JitStreamer-EB / StikDebug(StikJIT)**, 또는 TrollStore/하이퍼바이저.
- 앱 상단 `JIT: READY/NOT READY` 로 상태 확인.

## 4. 테스트 데이터 배치 (Files 앱 → 내 iPhone → StarlightEmulator)
데이터 경로는 **Documents** 하위(파일 공유 가능):
```
Documents/
├─ TestData/PPSSPP/<게임>.iso|.cso           # PSP 게임
├─ TestData/MeloNX/<게임>.nsp|.xci           # Switch 게임
└─ StarlightEmulator/
   └─ MeloNX/
      ├─ system/prod.keys   (+ title.keys)   # Switch 키(필수)
      └─ bis/                                 # 설치된 firmware (앱 내 설치 또는 배치)
```
- PSP 테스트 버튼: `TestData/PPSSPP/` 의 첫 게임을 실행.
- Switch 테스트 버튼: `TestData/MeloNX/` 의 첫 게임을 실행(키/펌웨어 없으면 오류 라벨 표시).

## 5. 테스트 절차 (앱)
1. 앱 실행 → `JIT`, `엔진 링크 상태`(PPSSPP:링크됨 / MeloNX:링크됨) 확인
2. **PSP 테스트** → 렌더/오디오/입력/일시정지/재개/중지/Host 복귀/재실행 확인
3. **Switch 테스트**(JIT READY 후) → 위 항목 확인
4. **교차 전환**: PSP → 중지 → Switch → 중지 → PSP (crash/hang/잔상/오디오/JIT 재초기화 확인)
5. 각 항목 `PASS/FAIL/NOT_TESTED` 기록 → `06_tests/CORE_SWITCH_CHECKLIST.md` / `PHASE1_RESULT.md`

## 6. 알려진 미검증/리스크 (실기기에서 확인)
- 임베드된 dylib/프레임워크의 런타임 dlopen 해소(@rpath) — 빌드/구조는 맞으나 런타임 미검증.
- MeloNX 의 SDL2/FFmpeg P/Invoke dlopen 이름 매칭, MoltenVK 로드.
- 복수 JIT/오디오 세션/Metal surface 의 코어 전환 시 동작(CONFLICT_ANALYSIS 참조).
- 첫 실행에서 문제가 나오면 로그/증상을 알려주면 수정 반복(push→CI→새 IPA).

## 7. 상태
- 빌드/링크/임베드/IPA 생성: **PASS (CI)**.
- 설치/실행/렌더/오디오/입력/JIT/전환: **NOT_TESTED** → 실기기 검증 필요.
