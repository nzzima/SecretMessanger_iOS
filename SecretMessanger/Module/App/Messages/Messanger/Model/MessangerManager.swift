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
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

    //MARK: Шапку диалога заводим до того, как подписываться на сообщения. Правила
    // берут состав участников из неё через `get()`, а `get()` по несуществующему
    // документу роняет проверку: в только что созданном чате слушатель получал бы
    // «Missing or insufficient permissions» и умирал насовсем.
    func ensureConversation(chat: Chat, completion: @escaping () -> Void) {
        let document = ref.collection(.conversation).document(chat.id)

        document.getDocument { snap, _ in
            let payload: [String: Any]

            if let snap, snap.exists {
                //MARK: Состав существующего диалога отсюда не пишется, и это главное
                // изменение с появлением «Участников». У открытого экрана на руках
                // может лежать устаревший состав — из списка чатов, например, — и
                // слепой merge вернул бы вычеркнутого участника обратно. Правила
                // такую запись отклонят целиком, и вместе с ней отвалится чат.
                payload = ["logins": chat.logins]
            } else {
                //MARK: Ошибка чтения сюда же: офлайн `getDocument` отдаёт кэш, так
                // что «не прочиталось» на практике означает «документа нет».
                payload = ["users": chat.members, "logins": chat.logins, "owner": chat.owner]
            }

            document.setData(payload, merge: true) { err in
                if let err {
                    print("Диалог не создался: \(err.localizedDescription)")
                }

                completion()
            }
        }
    }

    //MARK: Шапку слушаем, а не читаем однократно: состав группы теперь меняется на
    // ходу, и добавленный участник должен появиться в заголовке и в подписях к
    // сообщениям без перезахода в чат.
    func observeConversation(chat: Chat, completion: @escaping (Chat) -> Void) {
        conversationListener?.remove()

        conversationListener = ref
            .collection(.conversation)
            .document(chat.id)
            .addSnapshotListener { snap, err in
                if let err {
                    print("Шапка диалога не читается: \(err.localizedDescription)")
                    return
                }

                guard let data = snap?.data(),
                      let updated = Chat(id: chat.id, selfId: chat.selfId, data: data) else { return }

                completion(updated)
            }
    }

    func observeMessages(convoId: String, completion: @escaping ([Message]) -> Void) {
        messagesListener?.remove()

        messagesListener = ref
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
        messagesListener?.remove()
        messagesListener = nil

        conversationListener?.remove()
        conversationListener = nil
    }

    func send(text: String, chat: Chat) {
        let date = Date()
        let conversation = ref.collection(.conversation).document(chat.id)

        //MARK: Шапка обновляется ПЕРЕД записью сообщения, и это не вкусовщина: с
        // появлением групп участие в сообщениях проверяется правилами по документу
        // шапки (состав группы в id не закодируешь), поэтому к моменту записи
        // сообщения она должна быть актуальна.
        //
        // `users` в этой записи нет намеренно — состав правит только создатель через
        // «Участников». Заводит шапку `ensureConversation`, и до первой отправки она
        // всегда уже есть.
        conversation.setData([
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
