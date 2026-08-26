//
//  ChatMembersManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 10.08.2026.
//

import Foundation
import FirebaseFirestore

/// Состав группы: слушать, выйти, изменить.
class ChatMembersManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    //MARK: Экран слушает ту же шапку, что и сам чат. Свой слушатель, а не передача
    // состава из презентера переписки: список участников должен обновляться и у
    // тех, кто в этот момент просто смотрит его, — а меняет состав кто-то другой.
    /// Слушает шапку диалога: состав меняет создатель, а видеть это должны все.
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

    /// Снимает слушатель — иначе экран остался бы жив после закрытия.
    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    //MARK: Выход по своей воле. Отдельно от `update`, потому что и правило отдельное:
    // это единственная запись состава, где пишущий себя вычёркивает. Ключи здесь не
    // трогаются намеренно — ротация при добровольном выходе не нужна, ушедший и так
    // читал всё, что видел, а перевыдать ключ оставшимся он права не имеет.
    /// Выход по своей воле: вычёркивает себя из состава.
    ///
    /// Создателю закрыт — правила требуют, чтобы он остался: группа без хозяина
    /// осталась бы с замороженным составом навсегда.
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

    //MARK: Схема отметки собрана отдельно от записи — как и остальные документы
    // переписки: это договор с правилами Firestore (они сверяют `senderId`) и со всеми,
    // кто ленту разбирает. Сторожат его тесты.
    /// Документ отметки «ключ обновлён» — сообщение без содержимого.
    ///
    /// Ни текста, ни `enc`: шифровать в нём нечего, а поле `type` и есть всё сообщение.
    func keyNotice(chat: Chat, date: Date) -> [String: Any] {
        [
            "senderId": chat.selfId,
            "date": date,
            "type": "keyRotated"
        ]
    }

    //MARK: Пишется **после** успешной смены состава, а не вместе с ней. Отметка о
    // ротации, легшая в ленту при отклонённой правилами записи состава, соврала бы о
    // том, чего не было, — а неудача здесь вполне возможна: состав меняет только
    // создатель, и правила это проверяют.
    //
    //MARK: Молча в консоль. Отметка — это рассказ о событии, а не само событие: ключ
    // уже сменён, переписка уже запечатана заново, и тревожить человека неудачей
    // рассказа незачем.
    /// Дописывает в ленту отметку о смене ключа.
    func noteKeyRotation(chat: Chat) {
        ref
            .collection(.conversation)
            .document(chat.id)
            .collection(.messages)
            .addDocument(data: keyNotice(chat: chat, date: Date())) { err in
                if let err {
                    print("Отметка о ротации не записалась: \(err.localizedDescription)")
                }
            }
    }

    //MARK: Массив пишется целиком, а не `arrayUnion`: правила сравнивают состав до
    // и после, и явный список — единственный способ точно знать, что именно они
    // увидят. Состав при этом свежий — он приходит слушателем выше.
    /// Переписывает состав группы. Правила пропускают это только создателю.
    ///
    /// - Parameters:
    ///   - members: новый состав целиком.
    ///   - logins: карта имён — чтобы список не дочитывал профили на каждую строку.
    ///   - keys: записи `convoKeys` и `keyVersion`, если ключ ротируется или выдаётся
    ///     добавленному участнику.
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
