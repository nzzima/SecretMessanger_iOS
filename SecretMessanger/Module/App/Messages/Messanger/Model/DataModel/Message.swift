//
//  Message.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import MessageKit
import FirebaseFirestore

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind

    init(sender: SenderType, messageId: String, sentDate: Date, kind: MessageKind) {
        self.sender = sender
        self.messageId = messageId
        self.sentDate = sentDate
        self.kind = kind
    }

    //MARK: В документе лежит только senderId — имя подставляет презентер, он один
    // знает обоих собеседников. Здесь имя пустое намеренно.
    init(messageId: String, data: [String: Any]) {
        self.messageId = messageId
        self.sender = Sender(senderId: data["senderId"] as? String ?? "", displayName: "")
        self.kind = .text(data["message"] as? String ?? "")
        self.sentDate = (data["date"] as? Timestamp)?.dateValue() ?? Date()
    }
}
