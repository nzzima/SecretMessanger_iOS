//
//  ReturnLockTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 24.08.2026.
//

import XCTest
@testable import SecretMessanger

/// Запирать ли приложение на возврате. Правило простое, но ошибиться в нём можно в обе
/// стороны, и обе плохи: не запереть — оставить переписку открытой на чужом столе,
/// запирать всегда — заставить человека выключить блокировку целиком.
final class ReturnLockTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func leaving(_ secondsAgo: TimeInterval) -> Date {
        now.addingTimeInterval(-secondsAgo)
    }

    // MARK: - Порог

    /// Отвлёкся: сходил в браузер за ссылкой, посмотрел код из СМС. Переспрашивать здесь —
    /// верный способ добиться того, чтобы блокировку отключили насовсем.
    func testShortTripDoesNotLock() {
        XCTAssertFalse(ReturnLock.shouldLock(state: .appWindow, leftAt: leaving(10), now: now))
    }

    func testLongAbsenceLocks() {
        XCTAssertTrue(ReturnLock.shouldLock(state: .appWindow,
                                            leftAt: leaving(ReturnLock.grace + 1),
                                            now: now))
    }

    /// Ровно порог — ещё не повод: граница принадлежит «отвлёкся».
    func testExactlyAtTheThresholdDoesNotLock() {
        XCTAssertFalse(ReturnLock.shouldLock(state: .appWindow,
                                             leftAt: leaving(ReturnLock.grace),
                                             now: now))
    }

    // MARK: - Где были

    /// На экране блокировки запирать нечего — там уже заперто.
    func testAlreadyLockedStaysAsIs() {
        XCTAssertFalse(ReturnLock.shouldLock(state: .biometricWindow,
                                             leftAt: leaving(3600),
                                             now: now))
    }

    /// А вот это важнее: переход на экран блокировки с формы входа или регистрации стёр бы
    /// наполовину введённые почту и пароль. Человек ушёл посмотреть письмо с подтверждением
    /// — ровно тот случай, когда отсутствие затягивается.
    func testTypingCredentialsIsNotInterrupted() {
        [WindowManager.authorizationWindow, .registrationWindow].forEach { state in
            XCTAssertFalse(ReturnLock.shouldLock(state: state, leftAt: leaving(3600), now: now),
                           "Окно \(state.rawValue) не должно сбрасываться")
        }
    }

    // MARK: - Вырожденное и странное

    /// Не уходили вовсе — нечего и запирать.
    func testNeverLeftNeverLocks() {
        XCTAssertFalse(ReturnLock.shouldLock(state: .appWindow, leftAt: nil, now: now))
    }

    /// Часы перевели назад, пока нас не было. Сколько мы отсутствовали на самом деле —
    /// неизвестно, и «минус десять минут» точно не значит «отвлёкся на секунду».
    func testClockMovedBackwardsLocks() {
        XCTAssertTrue(ReturnLock.shouldLock(state: .appWindow,
                                            leftAt: now.addingTimeInterval(600),
                                            now: now))
    }
}
