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

    //MARK: Шапку диалога заводим до того, как подписываться на сообщения. Правила
    // берут состав участников из неё через `get()`, а `get()` по несуществующему
    // документу роняет проверку: в только что созданном чате слушатель получал бы
    // «Missing or insufficient permissions» и умирал насовсем.
    func ensureConversation(chat: Chat, completion: @escaping () -> Void) {
        ref
            .collection(.conversation)
            .document(chat.id)
            .setData([
                "users": chat.members,
                "logins": chat.logins
            ], merge: true) { err in
                if let err {
                    print("Диалог не создался: \(err.localizedDescription)")
                }

                completion()
            }
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

    func send(text: String, chat: Chat) {
        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        //MARK: Шапка обновляется ПЕРЕД записью сообщения, и это не вкусовщина: с
        // появлением групп участие в сообщениях проверяется правилами по документу
        // шапки (состав группы в id не закодируешь), поэтому к моменту записи
        // сообщения она должна быть актуальна. Раньше порядок был обратный.
        conversation.setData([
            "users": chat.members,
            "logins": chat.logins,
            "lastMessage": text,
            "date": date
        ], merge: true) { err in
            if let err {
                print("Диалог не обновился: \(err.localizedDescription)")
                return
            }

            conversation
                .collection(.messages)
                .document(UUID().uuidString)
                .setData([
                    "senderId": chat.selfId,
                    "message": text,
                    "date": date
                ]) { err in
                    if let err {
                        print("Сообщение не отправилось: \(err.localizedDescription)")
                    }
                }
        }
    }
}
