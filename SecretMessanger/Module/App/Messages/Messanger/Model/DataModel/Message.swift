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

    //MARK: Фото устроено так же и по той же причине: снимок лежит в подколлекции
    // `images`, а в сообщении остаются только его размеры. Без них ячейка не знала бы,
    // какой высоты пузырь рисовать, и переписка прыгала бы по мере загрузки картинок.
    var isPhoto: Bool
    var pixels: CGSize

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
        let type = data["type"] as? String ?? ""

        self.isVoice = type == "audio"
        self.duration = Float(data["duration"] as? Double ?? 0)

        self.isPhoto = type == "image"
        self.pixels = CGSize(width: data["width"] as? Double ?? 0,
                             height: data["height"] as? Double ?? 0)

        self.kind = Message.kind(text: self.body,
                                 messageId: messageId,
                                 isVoice: self.isVoice,
                                 duration: self.duration,
                                 isPhoto: self.isPhoto,
                                 pixels: self.pixels)
    }

    //MARK: Копия для показа: имя отправителя и уже расшифрованный текст. У голосового и
    // фото расшифровывать в этот момент нечего — байты приезжают отдельно, по нажатию
    // или по появлению ячейки на экране.
    //
    // Копия делается **со всего сообщения**, а не собирается заново из четырёх полей.
    // Раньше собиралась — и `isVoice`, `isPhoto`, `keyVersion` в показанной копии
    // оказывались сброшенными в значения по умолчанию. Ячейка при этом выглядела верно
    // (вид приходил отдельным параметром), а всякий, кто спрашивал у показанного
    // сообщения, фото ли это, получал «нет»: так молча отвалилось открытие снимка на
    // весь экран.
    func displayed(sender: SenderType, text: String) -> Message {
        var copy = self

        copy.sender = sender
        copy.kind = Message.kind(text: text,
                                 messageId: messageId,
                                 isVoice: isVoice,
                                 duration: duration,
                                 isPhoto: isPhoto,
                                 pixels: pixels)

        return copy
    }

    //MARK: Вид ячейки собирается в одном месте, а не в каждом инициализаторе: видов
    // теперь три, и разъехаться им ничего не мешало бы.
    private static func kind(text: String,
                             messageId: String,
                             isVoice: Bool,
                             duration: Float,
                             isPhoto: Bool,
                             pixels: CGSize) -> MessageKind {
        if isVoice {
            return .audio(Voice(messageId: messageId, duration: duration))
        }

        if isPhoto {
            return .photo(Photo(messageId: messageId, pixels: pixels))
        }

        return .text(text)
    }
}
