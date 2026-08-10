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
    private let crypto = ConversationCrypto.shared
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

    //MARK: Шапку диалога заводим до того, как подписываться на сообщения. Правила
    // берут состав участников из неё через `get()`, а `get()` по несуществующему
    // документу роняет проверку: в только что созданном чате слушатель получал бы
    // «Missing or insufficient permissions» и умирал насовсем.
    //
    // Здесь же рождается ключ диалога — до первого сообщения, иначе шифровать было бы
    // нечем.
    func ensureConversation(chat: Chat, completion: @escaping () -> Void) {
        let document = ref.collection(.conversation).document(chat.id)

        document.getDocument { [weak self] snap, _ in
            guard let self else { return }

            if let snap, snap.exists {
                //MARK: Состав существующего диалога отсюда не пишется, и это главное
                // изменение с появлением «Участников». У открытого экрана на руках
                // может лежать устаревший состав — из списка чатов, например, — и
                // слепой merge вернул бы вычеркнутого участника обратно. Правила
                // такую запись отклонят целиком, и вместе с ней отвалится чат.
                let existing = Chat(id: chat.id, selfId: chat.selfId, data: snap.data() ?? [:]) ?? chat

                self.heal(chat: existing) { extra in
                    var payload: [String: Any] = ["logins": chat.logins]
                    payload.merge(extra) { _, new in new }

                    self.write(payload, to: document, completion: completion)
                }
            } else {
                //MARK: Ошибка чтения сюда же: офлайн `getDocument` отдаёт кэш, так
                // что «не прочиталось» на практике означает «документа нет».
                var payload: [String: Any] = [
                    "users": chat.members,
                    "logins": chat.logins,
                    "owner": chat.owner
                ]
                payload.merge(self.firstKey(for: chat)) { _, new in new }

                self.write(payload, to: document, completion: completion)
            }
        }
    }

    private func write(_ payload: [String: Any], to document: DocumentReference, completion: @escaping () -> Void) {
        document.setData(payload, merge: true) { err in
            if let err {
                print("Диалог не создался: \(err.localizedDescription)")
            }

            completion()
        }
    }

    //MARK: Первый ключ диалога, запечатанный для тех, чьи открытые ключи пришли
    // вместе с выбранными контактами, и для себя.
    private func firstKey(for chat: Chat) -> [String: Any] {
        var publicKeys = chat.knownPublicKeys

        if let mine = PublicKeyDirectory.own(uid: chat.selfId) {
            publicKeys[chat.selfId] = mine
        }

        guard !publicKeys.isEmpty else { return [:] }

        let entries = crypto.sealed(key: crypto.newKey(), version: 1, convoId: chat.id, for: publicKeys)

        guard !entries.isEmpty else { return [:] }

        return ["convoKeys": entries, "keyVersion": 1]
    }

    //MARK: Досыпает ключи тем участникам, у кого их нет: человек мог зарегистрироваться
    // до шифрования и опубликовать открытый ключ только теперь. Делает это только
    // создатель — у остальных запись состава и ключей отклонят правила, да и
    // расходиться двум одновременным раздачам ни к чему.
    private func heal(chat: Chat, completion: @escaping ([String: Any]) -> Void) {
        guard chat.isOwner else {
            completion([:])
            return
        }

        let missing = chat.members.filter {
            chat.convoKeys[crypto.entryKey(uid: $0, version: max(chat.keyVersion, 1))] == nil
        }

        guard !missing.isEmpty else {
            completion([:])
            return
        }

        PublicKeyDirectory.keys(for: missing) { [weak self] keys in
            guard let self, !keys.isEmpty else {
                completion([:])
                return
            }

            //MARK: Диалог без ключа вообще — это переписка, начатая до шифрования.
            // Заводим первую версию; старые сообщения так и останутся открытыми, их
            // задним числом не зашифруешь.
            if chat.keyVersion == 0 {
                var all = keys

                if let mine = PublicKeyDirectory.own(uid: chat.selfId) {
                    all[chat.selfId] = mine
                }

                let entries = self.crypto.sealed(key: self.crypto.newKey(), version: 1, convoId: chat.id, for: all)

                completion(entries.isEmpty ? [:] : ["convoKeys": entries, "keyVersion": 1])
            } else {
                //MARK: Опоздавшему отдаём все версии сразу — правила и так дают ему
                // прочитать всю историю, и без старых ключей он увидел бы вместо неё
                // стену нерасшифрованного.
                let entries = self.crypto.sealedAllVersions(chat: chat, for: keys)

                completion(entries.isEmpty ? [:] : ["convoKeys": entries])
            }
        }
    }

    //MARK: Шапку слушаем, а не читаем однократно: состав группы теперь меняется на
    // ходу, и добавленный участник должен появиться в заголовке и в подписях к
    // сообщениям без перезахода в чат. Через неё же приезжает новая версия ключа
    // после ротации.
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

        //MARK: `lastMessage` шифруется тем же ключом, что и само сообщение. Оставить
        // его открытым значило бы выложить последнюю реплику каждого диалога в базу
        // открытым текстом — от шифрования остался бы один вид.
        let payload = chat.isEncrypted ? crypto.encrypt(text, chat: chat) : text

        guard let payload else {
            print("Сообщение не зашифровано: нет ключа диалога")
            return
        }

        //MARK: Шапка обновляется ПЕРЕД записью сообщения, и это не вкусовщина: с
        // появлением групп участие в сообщениях проверяется правилами по документу
        // шапки, поэтому к моменту записи сообщения она должна быть актуальна.
        //
        // `users` в этой записи нет намеренно — состав правит только создатель через
        // «Участников». Заводит шапку `ensureConversation`, и до первой отправки она
        // всегда уже есть.
        var header: [String: Any] = [
            "logins": chat.logins,
            "lastMessage": payload,
            "date": date
        ]

        if chat.isEncrypted {
            header["lastEnc"] = 1
            header["lastV"] = chat.keyVersion
        }

        conversation.setData(header, merge: true) { err in
            if let err {
                print("Диалог не обновился: \(err.localizedDescription)")
                return
            }

            var message: [String: Any] = [
                "senderId": chat.selfId,
                "message": payload,
                "date": date
            ]

            if chat.isEncrypted {
                message["enc"] = 1
                message["v"] = chat.keyVersion
            }

            conversation
                .collection(.messages)
                .document(UUID().uuidString)
                .setData(message) { err in
                    if let err {
                        print("Сообщение не отправилось: \(err.localizedDescription)")
                    }
                }
        }
    }
}
