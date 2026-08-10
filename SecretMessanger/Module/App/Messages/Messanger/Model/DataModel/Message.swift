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

    //MARK: То, что лежит в документе как есть. Расшифровывает презентер — он один
    // знает диалог, а с ним и ключ; модель к Keychain не ходит.
    var body: String
    var isEncrypted: Bool
    var keyVersion: Int

    //MARK: Голосовое отличается от текстового одним полем `type` в документе. Байты
    // лежат не здесь, а в подколлекции `audio` — в сообщении только длительность,
    // которой хватает, чтобы нарисовать ячейку до всякой загрузки.
    var isVoice: Bool
    var duration: Float

    init(sender: SenderType, messageId: String, sentDate: Date, kind: MessageKind) {
        self.sender = sender
        self.messageId = messageId
        self.sentDate = sentDate
        self.kind = kind
        self.body = ""
        self.isEncrypted = false
        self.keyVersion = 0
        self.isVoice = false
        self.duration = 0
    }

    //MARK: В документе лежит только senderId — имя подставляет презентер, он один
    // знает состав диалога. Здесь имя пустое намеренно.
    init(messageId: String, data: [String: Any]) {
        self.messageId = messageId
        self.sender = Sender(senderId: data["senderId"] as? String ?? "", displayName: "")
        self.sentDate = (data["date"] as? Timestamp)?.dateValue() ?? Date()

        //MARK: Флаг `enc` разделяет переписку до шифрования и после. Сообщения без
        // него читаются как раньше — сносить историю ради перехода не пришлось.
        self.body = data["message"] as? String ?? ""
        self.isEncrypted = (data["enc"] as? Int ?? 0) == 1
        self.keyVersion = data["v"] as? Int ?? 0
        self.isVoice = (data["type"] as? String ?? "") == "audio"
        self.duration = Float(data["duration"] as? Double ?? 0)
        self.kind = self.isVoice
            ? .audio(Voice(messageId: messageId, duration: self.duration))
            : .text(self.body)
    }

    //MARK: Копия для показа: имя отправителя и уже расшифрованный текст. У голосового
    // расшифровывать в этот момент нечего — звук приезжает по нажатию.
    func displayed(sender: SenderType, text: String) -> Message {
        Message(sender: sender,
                messageId: messageId,
                sentDate: sentDate,
                kind: isVoice ? .audio(Voice(messageId: messageId, duration: duration)) : .text(text))
    }
}
