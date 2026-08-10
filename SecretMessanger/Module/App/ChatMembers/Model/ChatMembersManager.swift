//
//  ChatMembersManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import FirebaseFirestore

class ChatMembersManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    //MARK: Экран слушает ту же шапку, что и сам чат. Свой слушатель, а не передача
    // состава из презентера переписки: список участников должен обновляться и у
    // тех, кто в этот момент просто смотрит его, — а меняет состав кто-то другой.
    func observe(chat: Chat, completion: @escaping (Chat) -> Void) {
        listener?.remove()

        listener = ref
            .collection(.conversation)
            .document(chat.id)
            .addSnapshotListener { snap, err in
                if let err {
                    print("Состав не читается: \(err.localizedDescription)")
                    return
                }

                guard let data = snap?.data(),
                      let updated = Chat(id: chat.id, selfId: chat.selfId, data: data) else { return }

                completion(updated)
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    //MARK: Массив пишется целиком, а не `arrayUnion`: правила сравнивают состав до
    // и после, и явный список — единственный способ точно знать, что именно они
    // увидят. Состав при этом свежий — он приходит слушателем выше.
    func update(chat: Chat, members: [String], logins: [String: String], completion: @escaping (Error?) -> Void) {
        ref
            .collection(.conversation)
            .document(chat.id)
            .setData([
                "users": members,
                "logins": logins
            ], merge: true) { err in
                completion(err)
            }
    }
}
