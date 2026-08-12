//
//  CryptoBoxTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 12.08.2026.
//

import XCTest
import CryptoKit
@testable import SecretMessanger

/// Шифрование: круговые проверки и — важнее — что чужим ключом ничего не открывается.
///
/// Firebase здесь не участвует: `CryptoBox` работает с ключами, которые тест создаёт сам.
final class CryptoBoxTests: XCTestCase {

    private let key = SymmetricKey(size: .bits256)

    // MARK: - Симметричное: сообщения

    func testTextSurvivesRoundTrip() throws {
        let text = "Привет, это сообщение с эмодзи 🎤 и запятыми, точками."

        let sealed = try CryptoBox.seal(text, with: key)
        let opened = try CryptoBox.open(sealed, with: key)

        XCTAssertEqual(opened, text)
    }

    /// Шифротекст не должен содержать исходную строку ни в каком виде — иначе всё
    /// остальное бессмысленно.
    func testSealedTextDoesNotContainPlaintext() throws {
        let text = "Красная площадь"

        let sealed = try CryptoBox.seal(text, with: key)

        XCTAssertFalse(sealed.contains(text))
        XCTAssertNotNil(Data(base64Encoded: sealed), "в базу уходит base64")
    }

    /// Одинаковый текст под одним ключом даёт разный шифротекст: AES-GCM берёт новый
    /// nonce на каждое запечатывание. Иначе повторы были бы видны прямо в базе.
    func testSameTextSealsDifferentlyEachTime() throws {
        let text = "Ок"

        let first = try CryptoBox.seal(text, with: key)
        let second = try CryptoBox.seal(text, with: key)

        XCTAssertNotEqual(first, second)
    }

    func testWrongKeyDoesNotOpenText() throws {
        let sealed = try CryptoBox.seal("секрет", with: key)

        XCTAssertThrowsError(try CryptoBox.open(sealed, with: SymmetricKey(size: .bits256)))
    }

    func testGarbagePayloadThrowsInsteadOfCrashing() {
        XCTAssertThrowsError(try CryptoBox.open("это не base64!!", with: key))
    }

    // MARK: - Симметричное: вложения

    func testDataSurvivesRoundTrip() throws {
        let raw = Data((0..<4096).map { UInt8($0 % 256) })

        let sealed = try CryptoBox.seal(raw, with: key)
        let opened = try CryptoBox.open(sealed, with: key)

        XCTAssertEqual(opened, raw)
        XCTAssertNotEqual(sealed, raw)
    }

    // MARK: - Асимметричное: ключ диалога для участника

    func testConversationKeyReachesItsRecipient() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let convoKey = SymmetricKey(size: .bits256)
        let context = "convo-1/v1"

        let sealed = try CryptoBox.seal(convoKey, for: recipient.publicKey, context: context)
        let opened = try CryptoBox.open(sealed, with: recipient, context: context)

        XCTAssertEqual(opened.raw, convoKey.raw)
    }

    /// Запечатанная запись состоит из эфемерного открытого ключа и шифротекста через
    /// точку. Получателю не нужно знать, кто запечатал, — только это.
    func testSealedKeyCarriesEphemeralPublicKey() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()

        let sealed = try CryptoBox.seal(SymmetricKey(size: .bits256),
                                        for: recipient.publicKey,
                                        context: "convo-1/v1")

        let parts = sealed.split(separator: ".")

        XCTAssertEqual(parts.count, 2)
        XCTAssertNotNil(Data(base64Encoded: String(parts[0])))
        XCTAssertNotNil(Data(base64Encoded: String(parts[1])))
    }

    func testAnotherPersonCannotOpenSealedKey() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let stranger = Curve25519.KeyAgreement.PrivateKey()

        let sealed = try CryptoBox.seal(SymmetricKey(size: .bits256),
                                        for: recipient.publicKey,
                                        context: "convo-1/v1")

        XCTAssertThrowsError(try CryptoBox.open(sealed, with: stranger, context: "convo-1/v1"))
    }

    /// Главное свойство контекста: запечатанный ключ нельзя переставить в другой диалог.
    /// Контекст подмешан в вывод HKDF, поэтому чужой id даёт другой ключ распаковки.
    func testSealedKeyCannotBeMovedToAnotherConversation() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()

        let sealed = try CryptoBox.seal(SymmetricKey(size: .bits256),
                                        for: recipient.publicKey,
                                        context: "convo-1/v1")

        XCTAssertThrowsError(try CryptoBox.open(sealed, with: recipient, context: "convo-2/v1"))
    }

    /// То же самое с версией: запись v1 не откроется как v2. На этом держится ротация
    /// ключа при удалении участника.
    func testSealedKeyIsBoundToItsVersion() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()

        let sealed = try CryptoBox.seal(SymmetricKey(size: .bits256),
                                        for: recipient.publicKey,
                                        context: "convo-1/v1")

        XCTAssertThrowsError(try CryptoBox.open(sealed, with: recipient, context: "convo-1/v2"))
    }
}
