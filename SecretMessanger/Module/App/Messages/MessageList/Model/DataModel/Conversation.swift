//
//  Conversation.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

struct Conversation {
    var id: String
    var otherId: String
    var otherLogin: String
    var lastMessage: String
    var date: Date

    //MARK: Инициализатор падающий: диалог без второго участника показать нечем,
    // такой документ просто выпадает из списка вместо пустой строки в таблице.
    init?(id: String, selfId: String, data: [String: Any]) {
        let users = data["users"] as? [String] ?? []

        guard let otherId = users.first(where: { $0 != selfId }) else { return nil }

        let logins = data["logins"] as? [String: String] ?? [:]

        self.id = id
        self.otherId = otherId
        self.otherLogin = logins[otherId] ?? ""
        self.lastMessage = data["lastMessage"] as? String ?? ""
        self.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
    }
}
