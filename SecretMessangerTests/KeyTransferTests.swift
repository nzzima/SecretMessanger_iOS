//
//  KeyTransferTests.swift
//  SecretMessangerTests
//
//  Created by Nikita Krylov on 14.08.2026.
//

import XCTest
import CryptoKit
@testable import SecretMessanger

/// Перенос ключа: круговая проверка и — важнее — что чужой пароль и чужой аккаунт
/// получают отказ, а не тихо неверный ключ.
///
/// Ни Keychain, ни Firebase здесь не участвуют: ключ тест создаёт сам.
final class KeyTransferTests: XCTestCase {

    private let key = Curve25519.KeyAgreement.PrivateKey()
    private let password = "перенос-на-андроид"
    private let uid = "KonyrENOrTVuDKDI858pvAQNeNA3"

    func testKeySurvivesRoundTrip() throws {
        let payload = try KeyTransfer.seal(key, password: password, uid: uid)
        let opened = try KeyTransfer.open(payload, password: password, uid: uid)

        XCTAssertEqual(opened.rawRepresentation, key.rawRepresentation)
    }

    /// Главное свойство: приватная половина не должна проступать в переносе.
    func testPayloadDoesNotContainRawKey() throws {
        let payload = try KeyTransfer.seal(key, password: password, uid: uid)

        XCTAssertFalse(payload.contains(key.rawRepresentation.base64EncodedString()))
    }

    func testWrongPasswordIsRejected() throws {
        let payload = try KeyTransfer.seal(key, password: password, uid: uid)

        XCTAssertThrowsError(try KeyTransfer.open(payload, password: "не тот", uid: uid)) {
            XCTAssertEqual($0 as? KeyTransfer.Failure, .wrongPasswordOrAccount)
        }
    }

    /// uid подмешан в аутентифицируемые данные именно ради этого случая: перенос,
    /// сделанный для одного аккаунта, во втором обязан провалиться сразу.
    func testPayloadFromAnotherAccountIsRejected() throws {
        let payload = try KeyTransfer.seal(key, password: password, uid: uid)

        XCTAssertThrowsError(try KeyTransfer.open(payload, password: password, uid: "чужой-uid")) {
            XCTAssertEqual($0 as? KeyTransfer.Failure, .wrongPasswordOrAccount)
        }
    }

    func testGarbageIsRejected() {
        for junk in ["", "SMK1", "SMK1.один.два.три", "SMK2.aaa.bbb", "просто текст"] {
            XCTAssertThrowsError(try KeyTransfer.open(junk, password: password, uid: uid),
                                 "«\(junk)» не должно разбираться")
        }
    }

    /// Соль случайная, поэтому два переноса одного ключа под одним паролем не совпадают —
    /// иначе по одинаковым строкам было бы видно, что ключ не менялся.
    func testTwoExportsDiffer() throws {
        let first = try KeyTransfer.seal(key, password: password, uid: uid)
        let second = try KeyTransfer.seal(key, password: password, uid: uid)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try KeyTransfer.open(first, password: password, uid: uid).rawRepresentation,
                       try KeyTransfer.open(second, password: password, uid: uid).rawRepresentation)
    }

    /// Формат — договор с Android-стороной: три части, метка версии, соль в 16 байт.
    func testFormatIsTheDocumentedOne() throws {
        let parts = try KeyTransfer.seal(key, password: password, uid: uid).split(separator: ".")

        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(String(parts[0]), KeyTransfer.prefix)
        XCTAssertEqual(Data(base64Encoded: String(parts[1]))?.count, 16, "соль")
        XCTAssertEqual(Data(base64Encoded: String(parts[2]))?.count, 12 + 32 + 16, "nonce + ключ + тег")
    }
}
