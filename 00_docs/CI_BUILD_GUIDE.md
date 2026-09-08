# CI_BUILD_GUIDE.md — Mac 없이 GitHub Actions 로 iOS 빌드

> 로컬은 Windows(`X:\103 통합에뮬`). 실제 iOS 컴파일은 GitHub Actions 의 macOS 러너가 수행한다.
> 이 문서를 쓴 시점에는 **아직 CI 가 실행되지 않았다 → 모든 빌드/IPA 항목 NOT_TESTED.**
> (이 개발 환경에는 gh CLI/원격이 없어 저장소 push 는 사용자가 수행해야 한다.)

## 0. 무엇이 준비되어 있나
- 워크플로: `.github/workflows/ios-build.yml` (수동 실행 `workflow_dispatch`)
- 빌드 스크립트: `07_build/build_{ppsspp,armsx2,melonx}_ios.sh` → 각 엔진을 **기준 commit 으로 clone** 후 빌드
- Host 생성/빌드: `generate_host.sh` + xcodebuild(서명 없음) → unsigned IPA
- 산출물/로그는 Actions **artifact** 로 회수(성공/실패 무관, `if: always()`)

## 1. GitHub 저장소 준비 (사용자, 최초 1회)
```bash
# X:\103 통합에뮬 에서 (Git Bash)
git status                      # 커밋 상태 확인
# GitHub 에서 빈 저장소 생성(웹) 후:
git remote add origin https://github.com/<계정>/<repo>.git
git push -u origin master
```
- 업로드되는 것: 소스/Adapter/빌드설정/워크플로/문서. **upstream 엔진 원본은 .gitignore** 되어 올라가지 않음
  → CI 가 스크립트로 정확한 commit 을 clone 함.
- **절대 올리지 않음(§3 보안)**: BIOS / prod.keys / firmware / 게임 ISO·NSP·XCI / 인증서 / 비밀번호.

## 2. 빌드 실행 (Run workflow)
1. GitHub 저장소 → **Actions** 탭 → 왼쪽 **iOS Build (Starlight Phase 1)** 선택
2. **Run workflow** 클릭 → 입력값:
   - `runner`: 기본 `macos-26` (없으면 `macos-15`/`macos-14` 로 변경)
   - `skip_ppsspp/armsx2/melonx`: 특정 엔진만 빌드하려면 나머지 skip
   - `build_host`: 엔진 후 Host 생성+빌드 여부(기본 true)
3. 실행 시작 → 진행 로그 실시간 확인

## 3. 결과/로그 회수
- 실행 페이지 하단 **Artifacts**:
  - `logs` → `08_logs/`(ci_environment / ppsspp_build / armsx2_build / melonx_build / engine_verify / host_build)
  - `build-intermediates` → 생성된 `.xcodeproj` + `07_build/prebuilt/*`
  - `app-ipa` → `StarlightEmulator_Phase1_unsigned.ipa` (+ `.sha256`) + `.app`
- 빌드 실패해도 로그 artifact 는 항상 생성된다.

## 4. 실패 로그 분석 → 수정 루프 (Windows)
```
Actions 로그/artifact 다운로드
→ X:\103 통합에뮬 에서 원인 분석(08_logs)
→ 최소 수정(07_build 스크립트 / project.yml / 03_adapters / 04_patches)
→ git commit && git push
→ Actions 에서 Run workflow 재실행
```
오류 우선순위(워크플로/스크립트에서 동일 적용): 컴파일 → 헤더/search path → arch → undefined → duplicate → bridge → SDL → MoltenVK → FFmpeg → entitlement → signing.
실제 duplicate symbol 이 확인되기 전에는 엔진 dylib 격리를 선제 적용하지 않는다(CONFLICT_ANALYSIS §1).

## 5. unsigned IPA 위치·의미
- 위치: `app-ipa` artifact 의 `StarlightEmulator_Phase1_unsigned.ipa`
- 의미: **Compile PASS / Link PASS / Unsigned IPA PASS**. **실기기 설치 PASS 아님.**

## 6. 서명·설치 (사용자, iPhone 16 Pro Max)
- 권장 경로 A(기본): unsigned IPA 를 **SideStore/AltStore** 로 재서명·설치. Apple 인증서를 GitHub 에 올릴 필요 없음.
- 경로 B(선택): Actions 에서 서명. 인증서는 **저장소가 아니라 GitHub Secrets** 로만:
  `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`.
- entitlements 기본: `02_host/StarlightEmulator/StarlightEmulator.entitlements`(표준 사이드로드). JIT 는 실기기에서 외부 JIT 활성기와 함께 검증.

## 7. 업데이트 빌드 (지시문 32·33항)
```
Windows 에서 코어/Adapter 갱신 (기준 commit 교체 시 07_build 스크립트 + BUILD_NOTES 갱신)
→ git push
→ Actions Run workflow
→ IPA artifact 다운로드
→ iPhone 재서명/설치
```
수동 Xcode GUI 수정이 필요 없도록 모든 설정은 `project.yml`/스크립트/`04_patches` 에만 둔다.

## 8. 상태
- 워크플로/스크립트/문서 준비 = 완료.
- **CI 실제 실행·IPA·실기기 = NOT_TESTED** (사용자 push + Run 필요). 결과는 PHASE1_RESULT.md 에 실제값으로만 갱신.
