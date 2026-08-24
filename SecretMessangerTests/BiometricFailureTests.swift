//
//  BiometricFailureTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 24.08.2026.
//

import XCTest
import LocalAuthentication
@testable import SecretMessanger

/// Экран блокировки — единственная дверь в приложение, и до 24.08.2026 он на любой отказ
/// отвечал «Попробуйте снова». Совет наугад: в трёх случаях из шести повторное нажатие не
/// помогает никогда, а лечится всё в Настройках телефона.
final class BiometricFailureTests: XCTestCase {

    private func error(_ code: LAError.Code) -> NSError {
        NSError(domain: LAErrorDomain, code: code.rawValue)
    }

    // MARK: - Молчание

    /// Отмена — не ошибка: человек сам закрыл диалог, и алерт поверх его решения только
    /// раздражает. Четыре кода означают одно и то же и все обязаны молчать.
    func testCancellationsSaySilent() {
        let silent: [LAError.Code] = [.userCancel, .appCancel, .systemCancel, .userFallback]

        silent.forEach { code in
            XCTAssertNil(BiometricFailure.describing(error(code)),
                         "Отмена (\(code.rawValue)) не должна показывать алерт")
        }
    }

    // MARK: - Случаи, где повтор бесполезен

    /// Разрешение отклонили при единственном системном запросе — кнопкой это не лечится,
    /// и человеку надо назвать место в Настройках.
    func testDeniedPermissionPointsAtSettings() {
        let failure = BiometricFailure.describing(error(.biometryNotAvailable))

        XCTAssertEqual(failure?.title, "Face ID недоступен")
        XCTAssertTrue(failure?.message.contains("Настройки") == true,
                      "Без адреса в Настройках сообщение бесполезно")
    }

    func testLockoutExplainsHowToRecover() {
        let failure = BiometricFailure.describing(error(.biometryLockout))

        XCTAssertEqual(failure?.title, "Face ID заблокирован")

        //MARK: Ищется основа, а не словарная форма: в сообщениях слово склоняется
        // («код-паролем», «код-паролю»), и проверка на «код-пароль» промахнулась бы мимо
        // совершенно правильного текста.
        XCTAssertTrue(failure?.message.contains("код-парол") == true,
                      "Надо сказать, чем разблокировать")
    }

    func testMissingPasscodeIsNamedOutright() {
        let failure = BiometricFailure.describing(error(.passcodeNotSet))

        XCTAssertEqual(failure?.title, "Нужен код-пароль")
    }

    func testNotEnrolledOffersThePasscodeWayIn() {
        let failure = BiometricFailure.describing(error(.biometryNotEnrolled))

        XCTAssertEqual(failure?.title, "Face ID не настроен")
        XCTAssertTrue(failure?.message.contains("код-парол") == true,
                      "Вход остаётся возможен — про него и надо сказать")
    }

    // MARK: - Случай, где повтор как раз помогает

    /// Единственный отказ, при котором «попробуйте ещё раз» — дельный совет.
    func testFailedMatchInvitesAnotherTry() {
        let failure = BiometricFailure.describing(error(.authenticationFailed))

        XCTAssertEqual(failure?.title, "Не узнали")
    }

    // MARK: - Чужое и пустое

    /// Ошибка не от биометрии вовсе — показываем общее, но показываем.
    func testForeignErrorStillSaysSomething() {
        let foreign = NSError(domain: "чужой.домен", code: 42)

        XCTAssertEqual(BiometricFailure.describing(foreign)?.title, "Не вышло")
    }

    /// `success == false` без ошибки — по документации так не бывает, но раньше на этом
    /// месте стоял `error!`, и такой отказ ронял приложение.
    func testMissingErrorDoesNotCrash() {
        XCTAssertEqual(BiometricFailure.describing(nil)?.title, "Не вышло")
    }
}
