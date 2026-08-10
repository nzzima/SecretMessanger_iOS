//
//  Conversation.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

//MARK: Строка списка «Чаты»: сам чат плюс то, что показывается в превью.
struct Conversation {
    let chat: Chat
    let lastMessage: String
    let date: Date

    var title: String { chat.title }
    var isGroup: Bool { chat.isGroup }

    //MARK: Инициализатор падающий сразу по двум причинам. Диалог, в котором нас нет,
    // показать нечем. А диалог без единого сообщения существует штатно: шапка
    // заводится при открытии чата, чтобы правила могли проверить состав участников —
    // но в списке ему делать нечего, пока никто ничего не написал.
    init?(id: String, selfId: String, data: [String: Any]) {
        guard let chat = Chat(id: id, selfId: selfId, data: data) else { return nil }

        let stored = data["lastMessage"] as? String ?? ""
        guard !stored.isEmpty else { return nil }

        self.chat = chat

        //MARK: Превью в списке — тот же шифротекст, что и сообщение, и расшифровывается
        // тем же ключом. Если бы шапка хранила его открытым, последняя реплика каждого
        // диалога лежала бы в базе читаемой, и шифровать сообщения было бы незачем.
        if (data["lastEnc"] as? Int ?? 0) == 1 {
            let version = data["lastV"] as? Int ?? chat.keyVersion

            self.lastMessage = ConversationCrypto.shared.decrypt(stored, chat: chat, version: version)
                ?? "🔒 Сообщение не расшифровано"
        } else {
            self.lastMessage = stored
        }

        self.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
    }
}
