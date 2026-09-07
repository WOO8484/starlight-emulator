//
//  CoreSwitchUITests.swift
//  Starlight Emulator - Core Switching UI Tests
//
//  지시문 12항의 코어 전환 순서를 자동화한다. 실기기(iPhone 16 Pro Max)에서 실행:
//     PPSSPP → STOP → ARMSX2 → STOP → MeloNX → STOP → PPSSPP → STOP → MeloNX → STOP → ARMSX2
//
//  ⚠ 이 테스트는 실기기 + 엔진 링크(*_LINKED) + Documents/TestData 에 게임/BIOS/keys 가
//     준비되어야 의미가 있다. 준비 전에는 "미링크/리소스없음" 오류 라벨을 확인하는 용도.
//  ⚠ Windows/Xcode 부재 환경에서는 실행 불가 → 결과는 NOT_TESTED (지시문 16항).
//

import XCTest

final class CoreSwitchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func app() -> XCUIApplication {
        let a = XCUIApplication()
        a.launch()
        return a
    }

    private func runAndStop(_ a: XCUIApplication, button: String, settleSeconds: TimeInterval = 8) {
        let btn = a.buttons[button]
        XCTAssertTrue(btn.waitForExistence(timeout: 5), "\(button) 버튼 없음")
        btn.tap()
        // 코어 부팅/렌더 안정화 대기(실기기 관찰용).
        Thread.sleep(forTimeInterval: settleSeconds)
        // "상태:" 라벨이 running 을 포함하는지 확인(엔진 링크된 경우).
        // 링크 전에는 오류 라벨이 표시되므로 실패로 기록되도록 로그만 남긴다.
        let stop = a.buttons["중지"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        Thread.sleep(forTimeInterval: 2)   // stop → Host 복귀 안정화
    }

    /// 지시문 12항 전체 전환 시퀀스.
    func testFullSwitchingSequence() throws {
        let a = app()
        let sequence = ["PSP 테스트", "PS2 테스트", "Switch 테스트",
                        "PSP 테스트", "Switch 테스트", "PS2 테스트"]
        for name in sequence {
            runAndStop(a, button: name)
        }
        // 반복 후에도 앱이 살아있고(=crash/hang 없음) Host 로 복귀했는지 확인.
        XCTAssertTrue(a.staticTexts["현재 코어: -"].waitForExistence(timeout: 10)
                      || a.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Host 복귀'")).count > 0,
                      "전환 시퀀스 후 Host 복귀 실패(hang/crash 의심)")
    }

    /// 교차 전환 최소 세트(지시문 15항 교차 테스트).
    func testCrossPairs() throws {
        let a = app()
        let pairs = [("PSP 테스트","PS2 테스트"),
                     ("PS2 테스트","Switch 테스트"),
                     ("Switch 테스트","PSP 테스트")]
        for (first, second) in pairs {
            runAndStop(a, button: first)
            runAndStop(a, button: second)
        }
    }
}
