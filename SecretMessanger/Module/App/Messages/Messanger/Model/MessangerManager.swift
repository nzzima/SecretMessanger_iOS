//
//  MessangerManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

class MessangerManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    //MARK: Id диалога собирается из пары uid, отсортированных по алфавиту. Оба
    // собеседника независимо приходят к одному и тому же id, поэтому чат, открытый
    // из контактов, всегда попадает в существующий диалог, а не заводит новый.
    static func conversationId(_ first: String, _ second: String) -> String {
        [first, second].sorted().joined(separator: "_")
    }

    func observeMessages(convoId: String, completion: @escaping ([Message]) -> Void) {
        listener?.remove()

        listener = ref
            .collection(.conversation)
            .document(convoId)
            .collection(.messages)
            .order(by: "date")
            .limit(toLast: 50)
            .addSnapshotListener { snap, err in
                if let err {
                    print("Сообщения не загрузились: \(err.localizedDescription)")
                    return
                }

                guard let docs = snap?.documents else { return }

                completion(docs.map { Message(messageId: $0.documentID, data: $0.data()) })
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func send(text: String, convoId: String, from selfSender: Sender, to otherSender: Sender) {
        let date = Date()

        ref.collection(.conversation)
            .document(convoId)
            .collection(.messages)
            .document(UUID().uuidString)
            .setData([
                "senderId": selfSender.senderId,
                "message": text,
                "date": date
            ])

        //MARK: Своё имя пишем всегда, чужое — только если знаем. Чат, открытый из
        // списка диалогов, имени собеседника ещё может не знать, и безусловная запись
        // затёрла бы уже сохранённое значение пустой строкой. `merge: true` сливает
        // вложенную карту по ключам, поэтому чужая запись при этом уцелеет.
        var logins = [selfSender.senderId: selfSender.displayName]

        if !otherSender.displayName.isEmpty {
            logins[otherSender.senderId] = otherSender.displayName
        }

        //MARK: Шапка диалога. По ней экран «Чаты» соберёт список запросом
        // whereField("users", arrayContains: uid) — отдельная копия на каждого
        // собеседника не нужна. Имена лежат здесь же, иначе списку пришлось бы
        // дочитывать профиль собеседника на каждую строку.
        ref.collection(.conversation)
            .document(convoId)
            .setData([
                "users": [selfSender.senderId, otherSender.senderId],
                "logins": logins,
                "lastMessage": text,
                "date": date
            ], merge: true)
    }
}
