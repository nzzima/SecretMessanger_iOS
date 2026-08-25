//
//  MessageListManager.swift
//  SecretMessanger
//
//  Created by Nikita Krylov on 04.08.2026.
//

import Foundation
import FirebaseFirestore

/// Список диалогов для вкладки «Чаты».
class MessageListManager {

    private let ref = Firestore.firestore()
    private var listener: ListenerRegistration?

    /// Слушает все диалоги, где мы состоим, и отдаёт их свежими сверху.
    ///
    /// - Note: пустые диалоги отсеиваются самим ``Conversation`` — шапка заводится при
    ///   открытии чата, до первого сообщения показывать в списке нечего.
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

    /// Снимает слушатель.
    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    //MARK: Страница за один заход. Батч Firestore держит 500 операций, а на сообщение
    // их уходит до двух: само сообщение и его вложение. Двести — с запасом внутри
    // потолка и одним чтением на круг.
    private static let pageSize = 200

    //MARK: Порядок здесь единственно возможный: сначала содержимое, шапка последней.
    // Правила подколлекций читают состав участников из шапки через `get()`, а `get()`
    // по несуществующему документу роняет проверку целиком — сотри шапку первой, и
    // сообщения, звук и снимки останутся в базе навсегда: их больше не прочитает и не
    // удалит никто, включая владельца проекта.
    //
    // Оборвалось на полпути — шапка на месте, диалог остался в списке, удаление
    // повторяется и доделывает начатое. Половина переписки к тому моменту стёрта, и это
    // всё равно лучше недостижимого мусора.
    /// Стирает диалог целиком: сообщения, вложения и шапку — у всех участников.
    ///
    /// Рекурсивного удаления у клиента Firestore нет: оно есть у Admin SDK и консоли, а
    /// тем нужен сервер. Поэтому подколлекции вычищаются отсюда, страницами.
    func delete(chat: Chat, completion: @escaping (Error?) -> Void) {
        erasePage(convoId: chat.id) { [weak self] err in
            guard let self else { return }

            if let err {
                completion(err)
                return
            }

            self.ref
                .collection(.conversation)
                .document(chat.id)
                .delete { err in
                    //MARK: Ключи забываем только после успеха — не удалилось, значит
                    // диалог жив, и читать его дальше было бы нечем.
                    if err == nil {
                        ConversationCrypto.shared.forget(convoId: chat.id)
                    }

                    completion(err)
                }
        }
    }

    //MARK: Вложения не перечисляются запросом, а выводятся из сообщений, и это не
    // экономия на строчках. Id документа в `audio` и `images` равен id сообщения, а сам
    // документ — это байты записи или снимка: перечислить подколлекцию значило бы
    // скачать все мегабайты диалога ради одних только имён. Сообщение называет своё
    // вложение полем `type` и весит строку.
    //
    // Плата — осиротевшее вложение, если байты записались, а сообщение следом за ними
    // нет. По сообщениям такое не найдётся; это редкий и тихий мусор, и он дешевле
    // гарантированной выкачки всего.
    private func erasePage(convoId: String, completion: @escaping (Error?) -> Void) {
        let convo = ref.collection(.conversation).document(convoId)

        convo
            .collection(.messages)
            .limit(to: Self.pageSize)
            .getDocuments { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    completion(err)
                    return
                }

                guard let docs = snap?.documents, !docs.isEmpty else {
                    completion(nil)
                    return
                }

                let batch = self.ref.batch()

                docs.forEach { doc in
                    batch.deleteDocument(doc.reference)

                    switch doc.data()["type"] as? String {
                    case "audio":
                        batch.deleteDocument(convo.collection(.audio).document(doc.documentID))
                    case "image":
                        batch.deleteDocument(convo.collection(.images).document(doc.documentID))
                    default:
                        break
                    }
                }

                batch.commit { err in
                    if let err {
                        completion(err)
                        return
                    }

                    //MARK: Следующая страница — это снова первые `pageSize`: стёртых
                    // в запросе уже нет. Пустой ответ и есть условие остановки.
                    self.erasePage(convoId: convoId, completion: completion)
                }
            }
    }
}
