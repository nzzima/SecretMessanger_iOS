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
/// Единственная беда, о которой экрану стоит знать: ключа диалога у нас нет.
enum ConversationCryptoError: LocalizedError {
    case noKey

    var errorDescription: String? {
        switch self {
        case .noKey:
            return "Ключ этого диалога вам ещё не выдан"
        }
    }
}

/// Ключи диалогов: достать свой, раздать участникам, зашифровать и расшифровать
/// сообщение.
///
/// Схему хранения и смысл версий см. в пояснении выше.
final class ConversationCrypto {

    static let shared = ConversationCrypto()

    /// Открытые ключи диалогов, по одному на диалог и версию. Открывать их заново на
    /// каждое сообщение незачем — это асимметричная операция, а сообщений в чате полсотни.
    private var cache: [String: SymmetricKey] = [:]

    private init() {}

    /// Новый ключ диалога — при создании чата и при каждой ротации.
    func newKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    //MARK: Контекст подмешивается в вывод HKDF: он привязывает запечатанный ключ к
    // конкретному диалогу и конкретной версии, так что переставить его в другой
    // диалог не выйдет.
    private func context(convoId: String, version: Int) -> String {
        "\(convoId)/v\(version)"
    }

    /// Ключ записи в карте `convoKeys`: чей ключ и какой версии.
    func entryKey(uid: String, version: Int) -> String {
        "\(uid)_\(version)"
    }

    // MARK: - Чтение ключа

    /// Достаёт ключ диалога нужной версии — из кэша или распечатывая свою запись.
    ///
    /// - Returns: `nil`, если записи для нас нет (ключ ещё не выдали) или она
    ///   запечатана для другой пары ключей — например, после переезда на устройство
    ///   без iCloud Keychain. Второй случай невосстановим.
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

    /// Ключ текущей версии — им шифруется всё, что отправляется сейчас.
    func currentKey(for chat: Chat) -> SymmetricKey? {
        key(for: chat, version: chat.keyVersion)
    }

    //MARK: Ключи стёртого диалога держать дальше не просто незачем, а вредно. Id
    // диалога на двоих детерминированный — пара uid по алфавиту, — поэтому переписка,
    // заведённая заново после удаления, получит **тот же** id и новый ключ нулевой
    // версии. Кэш на этот id отдал бы старый ключ, и свежие сообщения не
    // расшифровались бы до перезапуска приложения.
    /// Забывает ключи диалога — вызывается, когда он стёрт.
    func forget(convoId: String) {
        let prefix = "\(convoId)/"

        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    // MARK: - Раздача ключа участникам

    //MARK: Запечатывает ключ для всех, чей открытый ключ известен. Участник без
    // `publicKey` (не заходил после появления шифрования) молча пропускается — его
    // запись допишется, когда создатель откроет диалог следующий раз.
    /// Запечатывает ключ для каждого, чей открытый ключ известен.
    ///
    /// - Parameter publicKeys: uid → открытый ключ в base64.
    /// - Returns: готовые записи для карты `convoKeys` в шапке диалога.
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
    /// То же, но всеми версиями сразу — для участника, добавленного в живую группу.
    func sealedAllVersions(chat: Chat, for publicKeys: [String: String]) -> [String: String] {
        var entries: [String: String] = [:]

        for version in 1...max(chat.keyVersion, 1) {
            guard let key = key(for: chat, version: version) else { continue }

            entries.merge(sealed(key: key, version: version, convoId: chat.id, for: publicKeys)) { _, new in new }
        }

        return entries
    }

    // MARK: - Сообщения

    /// Шифрует текст текущим ключом диалога. `nil` — ключа нет, отправлять нечего.
    func encrypt(_ text: String, chat: Chat) -> String? {
        guard let key = currentKey(for: chat) else { return nil }

        return try? CryptoBox.seal(text, with: key)
    }

    /// Расшифровывает сообщение той версией ключа, которой оно было закрыто.
    ///
    /// - Parameter version: берётся у самого сообщения, а не у диалога: после ротации
    ///   старые сообщения открываются только старым ключом.
    /// - Returns: `nil` — показать «🔒 Сообщение не расшифровано».
    func decrypt(_ payload: String, chat: Chat, version: Int) -> String? {
        guard let key = key(for: chat, version: version) else { return nil }

        return try? CryptoBox.open(payload, with: key)
    }
}
