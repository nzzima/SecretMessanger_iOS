//
//  BiometricFailure.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 24.08.2026.
//

import Foundation
import LocalAuthentication

//MARK: Разбор причины отказа, а не одно «Попробуйте снова» на все случаи. Совет, который
// не помогает, хуже молчания: человек жмёт кнопку в пятый раз ровно потому, что ему так и
// сказали, — а дело в запрещённом разрешении или в незаданном код-пароле, и ни то ни
// другое кнопкой не лечится. Утром 24.08.2026 на этом экране уже сидел тупик без выхода,
// и увидеть его мешало в том числе бессодержательное сообщение: причина уходила в консоль,
// человеку доставался совет наугад.
//
// Вынесено из экрана отдельным типом, потому что это чистое отображение «код ошибки →
// текст», и его можно проверить тестами. Внутри `UIViewController` оно проверялось бы
// только глазами.
/// Во что превращается отказ биометрии на экране блокировки.
struct BiometricFailure: Equatable {
    let title: String
    let message: String

    //MARK: `nil` — показывать нечего. Отмена не ошибка: человек сам закрыл диалог, и
    // алерт поверх его решения только раздражает.
    /// Что показать человеку, или `nil`, если показывать не нужно.
    static func describing(_ error: Error?) -> BiometricFailure? {
        guard let code = code(of: error) else {
            return BiometricFailure(title: "Не вышло", message: "Попробуйте ещё раз")
        }

        switch code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return nil

        case .authenticationFailed:
            return BiometricFailure(
                title: "Не узнали",
                message: "Приложите лицо ещё раз или введите код-пароль устройства")

        //MARK: Единственный случай, когда войти действительно нечем: на телефоне не
        // задан код-пароль, а значит нет и биометрии — она на нём и держится.
        case .passcodeNotSet:
            return BiometricFailure(
                title: "Нужен код-пароль",
                message: "На телефоне не задан код-пароль. Задайте его в Настройках — без него запереть переписку нечем")

        case .biometryNotEnrolled:
            return BiometricFailure(
                title: "Face ID не настроен",
                message: "Настройте Face ID в Настройках или войдите по код-паролю устройства")

        //MARK: Сюда же попадает отказ в разрешении. Система спрашивает про Face ID один
        // раз за установку, и «Не разрешать» выключает биометрию для приложения
        // насовсем — вернуть её можно только в Настройках, и человеку надо сказать где.
        case .biometryNotAvailable:
            return BiometricFailure(
                title: "Face ID недоступен",
                message: "Возможно, приложению запретили им пользоваться: Настройки → Face ID и код-пароль → Другие приложения")

        case .biometryLockout:
            return BiometricFailure(
                title: "Face ID заблокирован",
                message: "Слишком много попыток. Разблокируйте телефон код-паролем — после этого Face ID снова заработает")

        default:
            return BiometricFailure(
                title: "Не вышло",
                message: error?.localizedDescription ?? "Попробуйте ещё раз")
        }
    }

    //MARK: Через `NSError`, а не приведением к `LAError`: сюда приходят обе ветки экрана —
    // и `Error?` из колбэка проверки, и `NSError?` из `canEvaluatePolicy`, — а домен и код
    // у них общие.
    private static func code(of error: Error?) -> LAError.Code? {
        guard let error = error as NSError?, error.domain == LAErrorDomain else { return nil }

        return LAError.Code(rawValue: error.code)
    }
}
