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

    //MARK: Выход по своей воле. Отдельно от `update`, потому что и правило отдельное:
    // это единственная запись состава, где пишущий себя вычёркивает. Ключи здесь не
    // трогаются намеренно — ротация при добровольном выходе не нужна, ушедший и так
    // читал всё, что видел, а перевыдать ключ оставшимся он права не имеет.
    func leave(chat: Chat, completion: @escaping (Error?) -> Void) {
        //MARK: Отметка ставится до записи, а не после успеха: отказ прилетит
        // слушателям переписки раньше, чем сюда вернётся подтверждение, и вышедший
        // получил бы вдогонку «вас удалили из группы». Не прошло — снимаем: человек
        // остался в составе.
        ChatExit.mark(chat.id)

        ref
            .collection(.conversation)
            .document(chat.id)
            .setData([
                "users": chat.members.filter { $0 != chat.selfId }
            ], merge: true) { err in
                if err != nil {
                    ChatExit.forget(chat.id)
                }

                completion(err)
            }
    }

    //MARK: Массив пишется целиком, а не `arrayUnion`: правила сравнивают состав до
    // и после, и явный список — единственный способ точно знать, что именно они
    // увидят. Состав при этом свежий — он приходит слушателем выше.
    func update(chat: Chat,
                members: [String],
                logins: [String: String],
                keys: [String: Any] = [:],
                completion: @escaping (Error?) -> Void) {
        var payload: [String: Any] = [
            "users": members,
            "logins": logins
        ]
        payload.merge(keys) { _, new in new }

        ref
            .collection(.conversation)
            .document(chat.id)
            .setData(payload, merge: true) { err in
                completion(err)
            }
    }
}
