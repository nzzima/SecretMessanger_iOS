//
//  MessageListManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

class MessageListManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    func observeConversations(selfId: String, completion: @escaping ([Conversation]) -> Void) {
        listener?.remove()

        listener = ref
            .collection(.conversation)
            .whereField("users", arrayContains: selfId)
            .addSnapshotListener { snap, err in
                if let err {
                    print("Диалоги не загрузились: \(err.localizedDescription)")
                    return
                }

                guard let docs = snap?.documents else { return }

                //MARK: Сортировка на клиенте намеренно: пара arrayContains + order(by:)
                // требует составного индекса в Firestore, которого нет. На десятках
                // диалогов разницы никакой; когда индекс заведут — сортировка
                // переезжает в запрос одной строкой.
                let conversations = docs
                    .compactMap { Conversation(id: $0.documentID, selfId: selfId, data: $0.data()) }
                    .sorted { $0.date > $1.date }

                completion(conversations)
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}
