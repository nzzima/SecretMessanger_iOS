//
//  KeyStore.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import Security
import CryptoKit

//MARK: Постоянный ключ пользователя: приватная половина живёт в Keychain и наружу не
// уходит никогда, открытая публикуется в `users/{uid}.publicKey`.
//
// `kSecAttrSynchronizable` включён намеренно — ключ едет в iCloud Keychain и попадает
// на другие устройства того же Apple ID сам. Без этого переезд на новый телефон
// означал бы навсегда нечитаемую переписку: расшифровать её больше нечем. Взамен мы
// доверяем iCloud Keychain, который сам сквозной и заперт кодом устройства, — но не
// доверяем Firestore, куда ключевой материал не попадает ни в каком виде.
//
// Доступность — `AfterFirstUnlock`, а не `WhenUnlocked`: синхронизируемые элементы не
// бывают `ThisDeviceOnly`, а читать сообщения нужно и когда экран заперт.
/// Постоянный ключ пользователя в Keychain.
///
/// Приватная половина не покидает устройство и iCloud Keychain; открытая публикуется в
/// профиле — этим занимается ``IdentityPublisher``.
enum KeyStore {

    private static let service = "nzzima.SecretMessanger.identity"

    //MARK: Ключ заведён на uid, а не один на устройство: на симуляторе (да и на
    // телефоне) под приложением сменяется несколько аккаунтов, и переписка каждого
    // должна остаться читаемой.
    /// Отдаёт постоянный ключ пользователя, а если его ещё нет — заводит и сохраняет.
    ///
    /// - Parameter uid: ключ заведён на аккаунт, а не на устройство: под приложением
    ///   сменяется несколько аккаунтов, и переписка каждого должна остаться читаемой.
    /// - Returns: `nil`, только если Keychain отказал в записи.
    static func identityKey(for uid: String) -> Curve25519.KeyAgreement.PrivateKey? {
        if let existing = load(uid: uid) {
            return existing
        }

        let created = Curve25519.KeyAgreement.PrivateKey()

        guard save(created, uid: uid) else {
            print("Ключ не сохранился в Keychain")
            return nil
        }

        return created
    }

    private static func query(uid: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: uid,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }

    private static func load(uid: String) -> Curve25519.KeyAgreement.PrivateKey? {
        var query = query(uid: uid)
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }

        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private static func save(_ key: Curve25519.KeyAgreement.PrivateKey, uid: String) -> Bool {
        var attributes = query(uid: uid)
        attributes[kSecValueData as String] = key.rawRepresentation
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemDelete(query(uid: uid) as CFDictionary)

        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
