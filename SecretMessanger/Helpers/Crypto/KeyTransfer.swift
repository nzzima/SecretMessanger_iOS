//
//  KeyTransfer.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 14.08.2026.
//

import Foundation
import CryptoKit
import CommonCrypto

//MARK: Перенос постоянного ключа на другое устройство — временная мера, а не
// архитектура. У пользователя один ключ на аккаунт (`users/{uid}.publicKey`), и вход со
// второго устройства перезаписал бы открытую половину своей: старая переписка не
// открылась бы там, новая перестала бы открываться здесь. Между iPhone'ами это лечит
// iCloud Keychain, между платформами — не лечит ничто, поэтому ключ переносится руками.
//
// Взрослое решение — много ключей на аккаунт, устройство как отдельная сущность, ключ
// диалога запечатан для каждого. Оно закладывается в следующий мессенджер; здесь
// переделка задела бы и правила, и обе стороны.
//
// Пароль растягивается PBKDF2, а не HKDF: HKDF быстрый по устройству, и перебор
// пользовательского пароля по нему стоил бы копейки.
/// Перенос постоянного ключа между устройствами: строка под паролем.
///
/// Формат — `SMK1.<соль>.<шифротекст>`, обе части в base64:
/// - соль: 16 случайных байт для PBKDF2-HMAC-SHA256, ``iterations`` проходов, вывод 32 байта;
/// - шифротекст: AES-GCM `combined` (`nonce ‖ данные ‖ тег`) от сырых 32 байт приватного
///   ключа, с **uid в качестве аутентифицируемых данных**.
///
/// uid подмешан намеренно: перенос, сделанный для одного аккаунта, не откроется в другом —
/// ошибка придёт сразу, а не превратится в нечитаемую переписку через неделю.
enum KeyTransfer {

    /// Что может пойти не так при переносе.
    enum Failure: LocalizedError {
        case noKey
        case malformed
        case wrongPasswordOrAccount

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "На этом устройстве нет ключа шифрования"
            case .malformed:
                return "Строка переноса испорчена или это вообще не она"
            case .wrongPasswordOrAccount:
                return "Неверный пароль — или строка от другого аккаунта"
            }
        }
    }

    /// Метка формата. Меняется, если поменяется способ упаковки.
    static let prefix = "SMK1"

    //MARK: Число подобрано так, чтобы на телефоне занимать доли секунды, но делать
    // перебор дорогим. Оно часть формата: читающая сторона обязана взять то же самое.
    /// Проходов PBKDF2. Часть формата — Android обязан использовать столько же.
    static let iterations: UInt32 = 310_000

    private static let saltBytes = 16
    private static let keyBytes = 32
    private static let separator: Character = "."

    // MARK: - Экспорт

    /// Запечатывает приватную половину постоянного ключа под паролем.
    ///
    /// - Parameters:
    ///   - key: постоянный ключ пользователя из ``KeyStore``.
    ///   - password: пароль, который человек назовёт на втором устройстве.
    ///   - uid: аккаунт, к которому привязан перенос.
    /// - Returns: строка `SMK1.<соль>.<шифротекст>` — её можно показать текстом или в QR.
    static func seal(_ key: Curve25519.KeyAgreement.PrivateKey,
                     password: String,
                     uid: String) throws -> String {
        var salt = Data(count: saltBytes)
        let generated = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltBytes, $0.baseAddress!) }

        guard generated == errSecSuccess else { throw Failure.malformed }

        let wrap = try derive(password: password, salt: salt)
        let box = try AES.GCM.seal(key.rawRepresentation, using: wrap, authenticating: Data(uid.utf8))

        guard let combined = box.combined else { throw Failure.malformed }

        return prefix
            + String(separator) + salt.base64EncodedString()
            + String(separator) + combined.base64EncodedString()
    }

    // MARK: - Импорт

    //MARK: Читающей стороны на iOS пока нет — между iPhone'ами ключ едет сам. Разбор
    // написан ради двух вещей: он проверяется тестами (иначе формат существовал бы
    // только в виде обещания) и служит образцом для Android, где импорт как раз нужен.
    /// Достаёт приватную половину из строки переноса.
    ///
    /// - Throws: ``Failure/malformed`` — строка не та; ``Failure/wrongPasswordOrAccount`` —
    ///   пароль не подошёл либо перенос сделан для другого аккаунта.
    static func open(_ payload: String, password: String, uid: String) throws -> Curve25519.KeyAgreement.PrivateKey {
        let parts = payload.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: separator)

        guard parts.count == 3,
              parts[0] == prefix,
              let salt = Data(base64Encoded: String(parts[1])),
              let boxData = Data(base64Encoded: String(parts[2])),
              salt.count == saltBytes else {
            throw Failure.malformed
        }

        let wrap = try derive(password: password, salt: salt)

        //MARK: Неверный пароль и чужой аккаунт неразличимы по устройству AES-GCM: и то и
        // другое — провал проверки тега. Так и сказано в ошибке, вместо того чтобы гадать.
        guard let raw = try? AES.GCM.open(try AES.GCM.SealedBox(combined: boxData),
                                          using: wrap,
                                          authenticating: Data(uid.utf8)),
              let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) else {
            throw Failure.wrongPasswordOrAccount
        }

        return key
    }

    // MARK: - Растяжение пароля

    private static func derive(password: String, salt: Data) throws -> SymmetricKey {
        var derived = Data(count: keyBytes)
        let passwordBytes = Array(password.utf8)

        let status = derived.withUnsafeMutableBytes { out in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    out.baseAddress!.assumingMemoryBound(to: UInt8.self), keyBytes)
            }
        }

        guard status == kCCSuccess else { throw Failure.malformed }

        return SymmetricKey(data: derived)
    }
}
