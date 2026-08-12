//
//  CryptoBox.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import CryptoKit

/// Что может пойти не так при шифровании.
enum CryptoError: LocalizedError {
    case malformedPayload
    case noIdentityKey

    var errorDescription: String? {
        switch self {
        case .malformedPayload:
            return "Не удалось разобрать зашифрованные данные"
        case .noIdentityKey:
            return "На этом устройстве нет ключа шифрования"
        }
    }
}

//MARK: Два примитива и ничего сверх того.
//
// Симметричный — AES-GCM ключом диалога, им шифруются сами сообщения.
// Асимметричный — им ключ диалога запечатывается для каждого участника отдельно.
//
// Запечатывание работает на эфемерной паре: на каждый запечатанный ключ создаётся
// одноразовая пара Curve25519, общий секрет считается с ней, а открытая половина
// кладётся рядом с шифротекстом. Получателю не нужно знать, **кто** запечатал, — он
// считает тот же секрет своим постоянным ключом и эфемерным открытым. Иначе пришлось
// бы хранить рядом ещё и uid отправителя и держать эту связь верной при каждой
// перевыдаче ключей.
/// Шифрование: два примитива и ничего сверх того.
///
/// - Симметричный (AES-GCM ключом диалога) — им закрываются сами сообщения:
///   ``seal(_:with:)-(String,_)`` для текста и ``seal(_:with:)-(Data,_)`` для вложений.
/// - Асимметричный (Curve25519) — им ключ диалога запечатывается каждому участнику
///   отдельно: ``seal(_:for:context:)``.
enum CryptoBox {

    /// Разделяет эфемерный открытый ключ и шифротекст в запечатанной записи.
    private static let separator: Character = "."

    // MARK: - Симметричное: сообщения

    /// Шифрует текст ключом диалога.
    /// - Returns: base64 — в таком виде он и ложится в поле документа.
    static func seal(_ text: String, with key: SymmetricKey) throws -> String {
        let box = try AES.GCM.seal(Data(text.utf8), using: key)

        guard let combined = box.combined else { throw CryptoError.malformedPayload }

        return combined.base64EncodedString()
    }

    /// Расшифровывает текст, зашифрованный ``seal(_:with:)-(String,_)``.
    /// - Throws: ``CryptoError/malformedPayload`` или ошибку CryptoKit, если ключ не тот.
    static func open(_ payload: String, with key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: payload) else { throw CryptoError.malformedPayload }

        let box = try AES.GCM.SealedBox(combined: data)
        let opened = try AES.GCM.open(box, using: key)

        guard let text = String(data: opened, encoding: .utf8) else { throw CryptoError.malformedPayload }

        return text
    }

    //MARK: Голосовое сообщение шифруется тем же ключом диалога, что и текст, только
    // остаётся байтами: в Firestore есть тип `bytes`, и гонять запись через base64
    // значило бы раздуть её на треть — а мы упираемся в лимит документа в 1 МиБ.
    /// Шифрует вложение — голосовое или снимок — тем же ключом диалога.
    /// - Returns: байты, а не base64: см. пояснение выше.
    static func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(data, using: key)

        guard let combined = box.combined else { throw CryptoError.malformedPayload }

        return combined
    }

    /// Расшифровывает вложение.
    static func open(_ data: Data, with key: SymmetricKey) throws -> Data {
        try AES.GCM.open(try AES.GCM.SealedBox(combined: data), using: key)
    }

    // MARK: - Асимметричное: ключ диалога для участника

    /// Запечатывает ключ диалога для одного участника.
    ///
    /// - Parameters:
    ///   - key: симметричный ключ диалога — то, что прячем.
    ///   - recipient: открытая половина постоянного ключа получателя.
    ///   - context: id диалога и номер версии. Подмешивается в вывод HKDF, поэтому
    ///     переставить запечатанный ключ в другой диалог не выйдет.
    /// - Returns: `<эфемерный открытый ключ>.<шифротекст>`, обе части в base64.
    static func seal(_ key: SymmetricKey,
                     for recipient: Curve25519.KeyAgreement.PublicKey,
                     context: String) throws -> String {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)

        let wrap = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: info(ephemeral: ephemeral.publicKey, recipient: recipient, context: context),
            outputByteCount: 32)

        let box = try AES.GCM.seal(key.raw, using: wrap)

        guard let combined = box.combined else { throw CryptoError.malformedPayload }

        return ephemeral.publicKey.rawRepresentation.base64EncodedString()
            + String(separator)
            + combined.base64EncodedString()
    }

    /// Достаёт ключ диалога из записи, запечатанной для нас.
    ///
    /// - Parameters:
    ///   - identity: свой постоянный приватный ключ из ``KeyStore``.
    ///   - context: тот же, что при запечатывании, иначе HKDF даст другой ключ.
    static func open(_ payload: String,
                     with identity: Curve25519.KeyAgreement.PrivateKey,
                     context: String) throws -> SymmetricKey {
        let parts = payload.split(separator: separator, maxSplits: 1)

        guard parts.count == 2,
              let ephemeralData = Data(base64Encoded: String(parts[0])),
              let boxData = Data(base64Encoded: String(parts[1])) else {
            throw CryptoError.malformedPayload
        }

        let ephemeral = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
        let shared = try identity.sharedSecretFromKeyAgreement(with: ephemeral)

        let wrap = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: info(ephemeral: ephemeral, recipient: identity.publicKey, context: context),
            outputByteCount: 32)

        let box = try AES.GCM.SealedBox(combined: boxData)

        return SymmetricKey(data: try AES.GCM.open(box, using: wrap))
    }

    //MARK: В вывод HKDF подмешиваются обе открытые половины и контекст (id диалога и
    // номер версии ключа). Без этого один и тот же запечатанный ключ можно было бы
    // переставить в другой диалог, и он бы там открылся.
    private static func info(ephemeral: Curve25519.KeyAgreement.PublicKey,
                             recipient: Curve25519.KeyAgreement.PublicKey,
                             context: String) -> Data {
        ephemeral.rawRepresentation + recipient.rawRepresentation + Data(context.utf8)
    }
}

extension SymmetricKey {

    /// Сырые байты ключа — чтобы запечатать его как обычные данные.
    var raw: Data {
        withUnsafeBytes { Data($0) }
    }
}
