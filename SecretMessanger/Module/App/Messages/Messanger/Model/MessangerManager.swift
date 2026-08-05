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

    func send(text: String, convoId: String, from selfId: String, to otherId: String) {
        let date = Date()

        ref.collection(.conversation)
            .document(convoId)
            .collection(.messages)
            .document(UUID().uuidString)
            .setData([
                "senderId": selfId,
                "message": text,
                "date": date
            ])

        //MARK: Шапка диалога. По ней экран «Чаты» соберёт список запросом
        // whereField("users", arrayContains: uid) — отдельная копия на каждого
        // собеседника не нужна.
        ref.collection(.conversation)
            .document(convoId)
            .setData([
                "users": [selfId, otherId],
                "lastMessage": text,
                "date": date
            ], merge: true)
    }
}
