//
//  Chat.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 07.08.2026.
//

import Foundation

//MARK: Всё, что нужно, чтобы открыть переписку — с любым числом участников.
// Ни названия, ни признака группы в базе нет: и то и другое выводится из состава,
// поэтому расходиться с действительностью им негде.
/// Переписка: с кем она и чем шифруется.
///
/// Собирается либо из выбранных контактов (новый чат), либо из документа-шапки
/// `conversation/{id}` — тот инициализатор падающий: диалог, в котором нас нет,
/// показать нечем.
struct Chat {
    let id: String
    let members: [String]
    let logins: [String: String]
    let owner: String
    let selfId: String

    //MARK: Ключ диалога, запечатанный для каждого участника отдельно, и номер его
    // текущей версии — см. ConversationCrypto. Сам ключ отсюда не достать: чтобы
    // открыть свою запись, нужен постоянный ключ из Keychain.
    let convoKeys: [String: String]
    let keyVersion: Int

    //MARK: Открытые ключи участников. Заполнены только на пути «создаём новый чат»,
    // где они пришли вместе с выбранными контактами: создателю нужно тут же
    // запечатать для них ключ диалога. У чата, прочитанного из Firestore, здесь
    // пусто — открытые ключи живут в `users`, а не в шапке диалога.
    let knownPublicKeys: [String: String]

    var isEncrypted: Bool {
        !convoKeys.isEmpty
    }

    var isGroup: Bool {
        members.count > 2
    }

    //MARK: Создатель — единственный, кто меняет состав. У диалогов, заведённых до
    // появления поля, его нет, и состав в них не поменяет никто: назначать себя
    // создателем задним числом правила не дают, и это осознанно.
    var isOwner: Bool {
        !owner.isEmpty && owner == selfId
    }

    //MARK: Название — логины всех, кроме себя. Для диалога на двоих это просто логин
    // собеседника, так что отдельного правила для группы не требуется.
    var title: String {
        members
            .filter { $0 != selfId }
            .compactMap { logins[$0] }
            .joined(separator: ", ")
    }

    /// Имя участника из кэша в шапке; пустая строка, если мы его ещё не знаем.
    func login(for userId: String) -> String {
        logins[userId] ?? ""
    }
}

extension Chat {

    //MARK: Id диалога на двоих детерминированный — пара uid по алфавиту. Оба
    // собеседника независимо приходят к одному и тому же id, поэтому чат, открытый
    // из контактов, попадает в существующий, а не заводит второй. Для группы состав
    // в id не закодируешь (да и меняться он может), поэтому id случайный, а
    // источником истины о составе служит массив `users` в документе.
    static func conversationId(members: [String]) -> String {
        members.count == 2 ? members.sorted().joined(separator: "_") : UUID().uuidString
    }

    //MARK: Новый чат из выбранных контактов. Создатель — тот, кто выбирал.
    init(selfId: String, selfLogin: String, contacts: [ChatUser]) {
        var logins = [selfId: selfLogin]
        var publicKeys: [String: String] = [:]

        contacts.forEach {
            logins[$0.id] = $0.login

            if !$0.publicKey.isEmpty {
                publicKeys[$0.id] = $0.publicKey
            }
        }

        let members = [selfId] + contacts.map { $0.id }

        self.id = Chat.conversationId(members: members)
        self.members = members
        self.logins = logins
        self.owner = selfId
        self.selfId = selfId
        self.convoKeys = [:]
        self.keyVersion = 0
        self.knownPublicKeys = publicKeys
    }

    //MARK: Существующий чат из документа Firestore.
    init?(id: String, selfId: String, data: [String: Any]) {
        guard let members = data["users"] as? [String], members.contains(selfId) else { return nil }

        self.id = id
        self.members = members
        self.logins = data["logins"] as? [String: String] ?? [:]
        self.owner = data["owner"] as? String ?? ""
        self.selfId = selfId
        self.convoKeys = data["convoKeys"] as? [String: String] ?? [:]
        self.keyVersion = data["keyVersion"] as? Int ?? 0
        self.knownPublicKeys = [:]
    }
}
