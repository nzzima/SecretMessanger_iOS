//
//  ConversationCrypto.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import CryptoKit

//MARK: Ключ диалога — симметричный, один на всех участников, и лежит он в шапке
// диалога **запечатанным отдельно для каждого**:
//
//     convoKeys: { "<uid>_<версия>": "<эфемерный ключ>.<шифротекст>" }
//     keyVersion: <текущая версия>
//
// Поле названо `convoKeys`, а не `keys`, не из вкусовщины: в правилах Firestore
// `keys()` — метод карты, и поле с таким именем читалось бы неоднозначно.
//
// Версии нужны ради ротации: когда участника удаляют, заводится новый ключ, а старые
// остаются в шапке, чтобы уже написанное осталось читаемым. Каждое сообщение помнит,
// какой версией зашифровано.
final class ConversationCrypto {

    static let shared = ConversationCrypto()

    private var cache: [String: SymmetricKey] = [:]

    private init() {}

    func newKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    //MARK: Контекст подмешивается в вывод HKDF: он привязывает запечатанный ключ к
    // конкретному диалогу и конкретной версии, так что переставить его в другой
    // диалог не выйдет.
    private func context(convoId: String, version: Int) -> String {
        "\(convoId)/v\(version)"
    }

    func entryKey(uid: String, version: Int) -> String {
        "\(uid)_\(version)"
    }

    // MARK: - Чтение ключа

    func key(for chat: Chat, version: Int) -> SymmetricKey? {
        let cacheKey = "\(chat.id)/\(version)/\(chat.selfId)"

        if let cached = cache[cacheKey] { return cached }

        guard let payload = chat.convoKeys[entryKey(uid: chat.selfId, version: version)],
              let identity = KeyStore.identityKey(for: chat.selfId) else { return nil }

        do {
            let key = try CryptoBox.open(payload,
                                         with: identity,
                                         context: context(convoId: chat.id, version: version))
            cache[cacheKey] = key
            return key
        } catch {
            //MARK: Сюда попадаем, если ключ запечатан для другой пары ключей — например,
            // после переезда на устройство без iCloud Keychain. Переписка в этом случае
            // не восстановима, и делать вид, что это временная ошибка, не надо.
            print("Ключ диалога не открывается: \(error.localizedDescription)")
            return nil
        }
    }

    func currentKey(for chat: Chat) -> SymmetricKey? {
        key(for: chat, version: chat.keyVersion)
    }

    // MARK: - Раздача ключа участникам

    //MARK: Запечатывает ключ для всех, чей открытый ключ известен. Участник без
    // `publicKey` (не заходил после появления шифрования) молча пропускается — его
    // запись допишется, когда создатель откроет диалог следующий раз.
    func sealed(key: SymmetricKey,
                version: Int,
                convoId: String,
                for publicKeys: [String: String]) -> [String: String] {
        var entries: [String: String] = [:]

        for (uid, encoded) in publicKeys {
            guard let data = Data(base64Encoded: encoded),
                  let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: data) else { continue }

            guard let payload = try? CryptoBox.seal(key,
                                                    for: publicKey,
                                                    context: context(convoId: convoId, version: version)) else { continue }

            entries[entryKey(uid: uid, version: version)] = payload
        }

        return entries
    }

    //MARK: Все версии сразу — для участника, которого добавили в существующую группу.
    // Правила и так дают ему прочитать всю историю, и без старых ключей он увидел бы
    // вместо неё стену нерасшифрованного: экран выглядел бы сломанным, а секрета всё
    // равно бы не прибавилось.
    func sealedAllVersions(chat: Chat, for publicKeys: [String: String]) -> [String: String] {
        var entries: [String: String] = [:]

        for version in 1...max(chat.keyVersion, 1) {
            guard let key = key(for: chat, version: version) else { continue }

            entries.merge(sealed(key: key, version: version, convoId: chat.id, for: publicKeys)) { _, new in new }
        }

        return entries
    }

    // MARK: - Сообщения

    func encrypt(_ text: String, chat: Chat) -> String? {
        guard let key = currentKey(for: chat) else { return nil }

        return try? CryptoBox.seal(text, with: key)
    }

    func decrypt(_ payload: String, chat: Chat, version: Int) -> String? {
        guard let key = key(for: chat, version: version) else { return nil }

        return try? CryptoBox.open(payload, with: key)
    }
}
