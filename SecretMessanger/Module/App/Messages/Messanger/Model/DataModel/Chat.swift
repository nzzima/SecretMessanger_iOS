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
struct Chat {
    let id: String
    let members: [String]
    let logins: [String: String]
    let selfId: String

    var isGroup: Bool {
        members.count > 2
    }

    //MARK: Название — логины всех, кроме себя. Для диалога на двоих это просто логин
    // собеседника, так что отдельного правила для группы не требуется.
    var title: String {
        members
            .filter { $0 != selfId }
            .compactMap { logins[$0] }
            .joined(separator: ", ")
    }

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

    //MARK: Новый чат из выбранных контактов.
    init(selfId: String, selfLogin: String, contacts: [ChatUser]) {
        var logins = [selfId: selfLogin]
        contacts.forEach { logins[$0.id] = $0.login }

        let members = [selfId] + contacts.map { $0.id }

        self.id = Chat.conversationId(members: members)
        self.members = members
        self.logins = logins
        self.selfId = selfId
    }

    //MARK: Существующий чат из документа Firestore.
    init?(id: String, selfId: String, data: [String: Any]) {
        guard let members = data["users"] as? [String], members.contains(selfId) else { return nil }

        self.id = id
        self.members = members
        self.logins = data["logins"] as? [String: String] ?? [:]
        self.selfId = selfId
    }
}
